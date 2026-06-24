--[[
	MatchRunner
	The match state machine: countdown -> repeated choose/resolve rounds -> game
	over. Avatar control is delegated to CombatantControl and end-of-match
	side-effects (coins / analytics / leaderboard) to MatchOutcome, so this reads
	as the flow and nothing else. When a table should be re-filled it calls back
	via deps.onNeedRefill(match) -- it never requires TableFiller (no cycle).
]]

local RS  = game:GetService("ReplicatedStorage")
-- match-subsystem siblings (children of MatchManager)
local MatchState       = require(script.Parent:WaitForChild("MatchState"))
local CombatantControl = require(script.Parent:WaitForChild("CombatantControl"))
local MatchConfig      = require(script.Parent:WaitForChild("MatchConfig"))
local MatchOutcome     = require(script.Parent:WaitForChild("MatchOutcome"))
local CombatResolver   = require(script.Parent:WaitForChild("CombatResolver"))
local BotBrain         = require(script.Parent:WaitForChild("Bot"):WaitForChild("BotBrain"))

local EventHub         = require(RS:WaitForChild("EventHub"))
local StartCountdown   = EventHub.StartCountdown
local StartChoicePhase = EventHub.StartChoicePhase
local RoundResult      = EventHub.RoundResult
local GameOverRemote   = EventHub.GameOver

local fireHuman = CombatantControl.fireHuman

local MatchRunner = {}
MatchRunner.__index = MatchRunner

-- deps.onNeedRefill(match) -> ask the table to re-fill (start next match / bot).
function MatchRunner.new(deps)
	return setmetatable({ _onNeedRefill = deps.onNeedRefill }, MatchRunner)
end

-- Apply a resolved round to match state: HP, bullets, per-side deflect cooldown.
local function applyRound(L, R, result)
	L.health  = math.max(0, L.health - result.leftDamage)
	R.health  = math.max(0, R.health - result.rightDamage)
	L.bullets = math.max(0, L.bullets + result.leftBulletDelta)
	R.bullets = math.max(0, R.bullets + result.rightBulletDelta)

	-- Per-player deflect lock: arm ONLY the side that deflected; each side ticks
	-- down its own lock. Your opponent's deflect never locks you.
	for _, s in ipairs({ L, R }) do
		if s.choice == "Deflect" then
			s.deflectCD = MatchConfig.DEFLECT_COOLDOWN_ROUNDS
		elseif (s.deflectCD or 0) > 0 then
			s.deflectCD -= 1
		end
	end
end

function MatchRunner:_refill(match)
	match.phase = "WAITING"
	task.defer(self._onNeedRefill, match)
end

function MatchRunner:run(match)
	if not match then return end

	local L, R = match.left, match.right
	if not CombatantControl.charOf(L) or not CombatantControl.charOf(R) then return end

	local lTok, rTok = CombatantControl.token(L), CombatantControl.token(R)

	MatchState.resetForNewMatch(match)
	L.deflectCD = 0
	R.deflectCD = 0
	match.phase = "COUNTDOWN"

	CombatantControl.syncHealth(L, MatchConfig.MAX_HEALTH)
	CombatantControl.syncHealth(R, MatchConfig.MAX_HEALTH)
	CombatantControl.lock(L)
	CombatantControl.lock(R)

	task.wait(MatchConfig.SEAT_SETTLE_DELAY)
	fireHuman(StartCountdown, L, match.tableId, MatchConfig.COUNTDOWN)
	fireHuman(StartCountdown, R, match.tableId, MatchConfig.COUNTDOWN)
	task.wait(MatchConfig.COUNTDOWN)

	-- still the same two occupants?
	if CombatantControl.token(L) ~= lTok or CombatantControl.token(R) ~= rTok then
		CombatantControl.cleanupBots(match)
		self:_refill(match)
		return
	end

	match._startClock = os.clock()
	MatchOutcome.matchStarted(match)

	while true do
		match.phase = "CHOOSING"
		MatchState.resetForNewRound(match)

		fireHuman(StartChoicePhase, L, match.tableId, MatchConfig.CHOICE_TIME, L.deflectCD)
		fireHuman(StartChoicePhase, R, match.tableId, MatchConfig.CHOICE_TIME, R.deflectCD)

		-- bot(s) think, then lock in a choice
		for _, s in ipairs({ L, R }) do
			if s.isBot then
				task.spawn(function()
					task.wait(math.random(MatchConfig.BOT_THINK_MIN, MatchConfig.BOT_THINK_MAX))
					if match.phase == "CHOOSING" and not s.confirmed then
						s.choice = BotBrain.decide(s, (s.deflectCD or 0) > 0)
						s.confirmed = true
					end
				end)
			end
		end

		local elapsed = 0
		while elapsed < MatchConfig.CHOICE_TIME do
			if L.confirmed and R.confirmed then break end
			task.wait(0.1)
			elapsed += 0.1

			-- someone left mid-round
			if CombatantControl.token(L) ~= lTok or CombatantControl.token(R) ~= rTok then
				local remaining = (CombatantControl.token(L) == lTok) and L
				               or (CombatantControl.token(R) == rTok) and R
				               or nil
				if remaining and remaining.player then
					fireHuman(GameOverRemote, remaining, match.tableId, remaining.player.UserId, "opponent_left")
					MatchOutcome.forfeit(match, remaining)
					CombatantControl.unlock(remaining)
					CombatantControl.syncHealth(remaining, MatchConfig.MAX_HEALTH)
				end
				CombatantControl.cleanupBots(match)
				self:_refill(match)
				return
			end
		end

		-- defaults for anyone who didn't confirm
		if not L.confirmed then L.choice = MatchConfig.DEFAULT_CHOICE; L.confirmed = true end
		if not R.confirmed then R.choice = MatchConfig.DEFAULT_CHOICE; R.confirmed = true end

		-- resolve
		match.phase = "RESOLVING"
		local result = CombatResolver.resolve(L.choice, R.choice, L.bullets, R.bullets)
		applyRound(L, R, result)

		fireHuman(RoundResult, L, match.tableId, L.choice, R.choice, L.health, L.bullets, R.health, R.bullets)
		fireHuman(RoundResult, R, match.tableId, R.choice, L.choice, R.health, R.bullets, L.health, L.bullets)

		local anyDead = L.health <= 0 or R.health <= 0
		task.wait(anyDead and MatchConfig.DEATH_DELAY or MatchConfig.RESOLVE_DELAY)

		local ld = L.health <= 0
		local rd = R.health <= 0
		if ld or rd then
			match.phase = "GAMEOVER"

			local isDraw = ld and rd
			local winnerSide
			if isDraw then winnerSide = nil
			elseif rd then winnerSide = L   -- right dead -> left won
			else winnerSide = R end          -- left dead  -> right won

			if ld then CombatantControl.ragdoll(L) end
			if rd then CombatantControl.ragdoll(R) end

			local winnerId
			if isDraw then winnerId = nil
			elseif winnerSide == L then winnerId = L.player and L.player.UserId or 0
			else winnerId = R.player and R.player.UserId or 0 end

			fireHuman(GameOverRemote, L, match.tableId, winnerId, "finished")
			fireHuman(GameOverRemote, R, match.tableId, winnerId, "finished")

			MatchOutcome.gameOver(match, winnerSide, isDraw)

			-- heal + unlock survivors
			if not ld then CombatantControl.unlock(L); CombatantControl.syncHealth(L, MatchConfig.MAX_HEALTH) end
			if not rd then CombatantControl.unlock(R); CombatantControl.syncHealth(R, MatchConfig.MAX_HEALTH) end

			task.wait(MatchConfig.GAMEOVER_HOLD)

			-- respawn dead humans
			for _, s in ipairs({ L, R }) do
				local dead = (s == L and ld) or (s == R and rd)
				if dead and not s.isBot and s.player and s.player.Parent then
					local plr = s.player
					s.player = nil  -- clear stale registration so re-sitting can't auto-start a phantom match
					task.spawn(function() plr:LoadCharacter() end)
				end
			end

			CombatantControl.cleanupBots(match)
			MatchState.resetForNewMatch(match)
			self:_refill(match)
			return
		end
	end
end

return MatchRunner
