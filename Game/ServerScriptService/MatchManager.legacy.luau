--[[
	MatchManager (Server Script)
	Orchestrator. Delegates combat/state/seats to modules.
	BOT SUPPORT: if a human sits alone, after BOT_GRACE seconds a bot
	rig fills the opposite chair and the match runs vs BotBrain.
]]

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local SSS     = game:GetService("ServerScriptService")

local Modules        = SSS:WaitForChild("Modules")
local MatchState     = require(Modules:WaitForChild("MatchState"))
local CombatResolver = require(Modules:WaitForChild("CombatResolver"))
local SeatManager    = require(Modules:WaitForChild("SeatManager"))
local BotManager     = require(Modules:WaitForChild("BotManager"))
local BotBrain       = require(Modules:WaitForChild("BotBrain"))
local CoinService    = require(SSS.Data:WaitForChild("CoinService"))

local EventHub          = require(RS:WaitForChild("EventHub"))
local StartCountdown   = EventHub.StartCountdown
local StartChoicePhase = EventHub.StartChoicePhase
local SubmitChoice     = EventHub.SubmitChoice
local RoundResult      = EventHub.RoundResult
local GameOverRemote   = EventHub.GameOver

local MATCH_COUNTDOWN  = 5
local CHOICE_TIME      = 10
local RESOLVE_DELAY    = 3
local DEATH_DELAY      = 1.2
local DEFAULT_CHOICE   = "None"
local MAX_MATCH_HEALTH = 3
local BOT_GRACE        = 4   -- seconds alone before a bot fills the chair
local BOT_THINK_MIN    = 1
local BOT_THINK_MAX    = 3
local BOTS_ENABLED     = true   -- set to false to disable bot opponents (PvP still works)

local Matches = {}

-------------------------------------------------------
-- SIDE HELPERS (work for both humans and bots)
-------------------------------------------------------
local function sideChar(s)
	if s.isBot then return s.botChar end
	return s.player and s.player.Character
end

-- stable token to detect "this occupant left / changed"
local function sideToken(s)
	if s.isBot then return s.botChar end
	return s.player
end

local function syncHealthChar(char, matchHealth)
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local ratio = matchHealth / MAX_MATCH_HEALTH
	hum.Health = math.max(0, ratio * hum.MaxHealth)
end

local function lockChar(char)
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.JumpPower = 0; hum.WalkSpeed = 0 end
end

local function unlockChar(char)
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.JumpPower = 50; hum.WalkSpeed = 16 end
end

local function ragdollSide(s)
	local char = sideChar(s)
	if not char then return end
	if s.isBot then
		BotManager.killBot(char)
	else
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
			hum:SetAttribute("Ragdolled", true)
		end
	end
end

-- fire a remote only to human sides (bots have no client)
local function fireHuman(remote, s, ...)
	if s.player then remote:FireClient(s.player, ...) end
end

local function cleanupBots(match)
	for _, s in ipairs({match.left, match.right}) do
		if s.isBot then
			BotManager.despawnBot(s.botChar)
			s.isBot = false
			s.botChar = nil
		end
	end
end

-- forward declaration
local tryFillTable

-------------------------------------------------------
-- ROUND LOOP
-------------------------------------------------------
-- Report a finished match to the (optional) global Wins leaderboard.
-- Fully decoupled: if the board isn't in the place, this silently no-ops.
-- Bots are filtered out here so the board only ever sees real Players.
local function recordMatch(sideA, sideB, winnerSide)
	local ev = game:GetService("ServerStorage"):FindFirstChild("LeaderboardMatchEnded")
	if not ev then return end
	local function human(s)
		if s and s.player and not s.isBot then return s.player end
		return nil
	end
	local players = {}
	local a = human(sideA); if a then table.insert(players, a) end
	local b = human(sideB); if b then table.insert(players, b) end
	local winner = winnerSide and human(winnerSide) or nil
	ev:Fire(players, winner)
end


local function runMatch(tableId)
	local match = Matches[tableId]
	if not match then return end

	local L, R = match.left, match.right
	local lChar, rChar = sideChar(L), sideChar(R)
	if not lChar or not rChar then return end

	local lTok, rTok = sideToken(L), sideToken(R)

	MatchState.resetForNewMatch(match)
	match.phase = "COUNTDOWN"

	syncHealthChar(lChar, MAX_MATCH_HEALTH)
	syncHealthChar(rChar, MAX_MATCH_HEALTH)
	lockChar(lChar)
	lockChar(rChar)

	task.wait(0.5) -- let client Seated event process first
	fireHuman(StartCountdown, L, tableId, MATCH_COUNTDOWN)
	fireHuman(StartCountdown, R, tableId, MATCH_COUNTDOWN)
	task.wait(MATCH_COUNTDOWN)

	-- still the same two occupants?
	if sideToken(L) ~= lTok or sideToken(R) ~= rTok then
		cleanupBots(match)
		match.phase = "WAITING"
		task.defer(tryFillTable, tableId)
		return
	end

	while true do
		match.phase = "CHOOSING"
		MatchState.resetForNewRound(match)

		fireHuman(StartChoicePhase, L, tableId, CHOICE_TIME)
		fireHuman(StartChoicePhase, R, tableId, CHOICE_TIME)

		-- bot(s) think, then lock in a choice
		for _, s in ipairs({L, R}) do
			if s.isBot then
				task.spawn(function()
					task.wait(math.random(BOT_THINK_MIN, BOT_THINK_MAX))
					if match.phase == "CHOOSING" and not s.confirmed then
						s.choice = BotBrain.decide(s)
						s.confirmed = true
					end
				end)
			end
		end

		local elapsed = 0
		while elapsed < CHOICE_TIME do
			if L.confirmed and R.confirmed then break end
			task.wait(0.1)
			elapsed += 0.1

			-- someone left mid-round
			if sideToken(L) ~= lTok or sideToken(R) ~= rTok then
				local remaining = (sideToken(L) == lTok) and L
				               or (sideToken(R) == rTok) and R
				               or nil
				if remaining and remaining.player then
					GameOverRemote:FireClient(remaining.player, tableId, remaining.player.UserId, "opponent_left")

					recordMatch(remaining, nil, remaining) -- remaining player wins; opponent left
					unlockChar(sideChar(remaining))
					syncHealthChar(sideChar(remaining), MAX_MATCH_HEALTH)

					-- COIN REWARD: opponent left, remaining human wins the pot.
					if not remaining.isBot then
						local rv = match.rewardValueObject
						local reward = rv and rv.Value or 0
						if reward > 0 then
							local plr = remaining.player
							task.delay(0.45, function()
								if plr and plr.Parent then
									CoinService.Add(plr, reward, "Match Win")
								end
							end)
						end
					end
				end
				cleanupBots(match)
				match.phase = "WAITING"
				task.defer(tryFillTable, tableId)
				return
			end
		end

		-- defaults for anyone who didn't confirm
		if not L.confirmed then L.choice = DEFAULT_CHOICE; L.confirmed = true end
		if not R.confirmed then R.choice = DEFAULT_CHOICE; R.confirmed = true end

		-- resolve
		match.phase = "RESOLVING"
		local result = CombatResolver.resolve(L.choice, R.choice, L.bullets, R.bullets)

		L.health  = math.max(0, L.health - result.leftDamage)
		R.health  = math.max(0, R.health - result.rightDamage)
		L.bullets = math.max(0, L.bullets + result.leftBulletDelta)
		R.bullets = math.max(0, R.bullets + result.rightBulletDelta)

		fireHuman(RoundResult, L, tableId, L.choice, R.choice, L.health, L.bullets, R.health, -1)
		fireHuman(RoundResult, R, tableId, R.choice, L.choice, R.health, R.bullets, L.health, -1)

		local anyDead = L.health <= 0 or R.health <= 0
		task.wait(anyDead and DEATH_DELAY or RESOLVE_DELAY)

		local ld = L.health <= 0
		local rd = R.health <= 0
		if ld or rd then
			match.phase = "GAMEOVER"

			local winnerId
			if ld and rd then
				winnerId = nil -- draw
			elseif rd then
				winnerId = L.player and L.player.UserId or 0 -- left won
			else
				winnerId = R.player and R.player.UserId or 0 -- right won
			end

			if ld then ragdollSide(L) end
			if rd then ragdollSide(R) end

			fireHuman(GameOverRemote, L, tableId, winnerId, "finished")
			fireHuman(GameOverRemote, R, tableId, winnerId, "finished")

			-- COIN REWARD: pay the surviving human the table's reward.
			do
				local winnerSide = (rd and not ld) and L or (ld and not rd) and R or nil

				recordMatch(L, R, winnerSide) -- both played; winnerSide (if any) gets the win
				if winnerSide and winnerSide.player and not winnerSide.isBot then
					local rv = match.rewardValueObject
					local reward = rv and rv.Value or 0
					if reward > 0 then
						local plr = winnerSide.player
						task.delay(0.45, function()
							if plr and plr.Parent then
								CoinService.Add(plr, reward, "Match Win")
							end
						end)
					end
				end
			end

			-- heal + unlock survivors
			if not ld then unlockChar(lChar); syncHealthChar(lChar, MAX_MATCH_HEALTH) end
			if not rd then unlockChar(rChar); syncHealthChar(rChar, MAX_MATCH_HEALTH) end

			task.wait(3)

			-- respawn dead humans
			for _, s in ipairs({L, R}) do
				local dead = (s == L and ld) or (s == R and rd)
				if dead and not s.isBot and s.player and s.player.Parent then
					local plr = s.player
					task.spawn(function() plr:LoadCharacter() end)
				end
			end

			-- despawn ALL bots (next match spawns a fresh one)
			cleanupBots(match)

			MatchState.resetForNewMatch(match)
			match.phase = "WAITING"
			task.defer(tryFillTable, tableId)
			return
		end
	end
end

-------------------------------------------------------
-- TABLE FILL LOGIC (humans first, bot after grace)
-------------------------------------------------------
function tryFillTable(tableId)
	local match = Matches[tableId]
	if not match or match.phase ~= "WAITING" then return end

	local L, R = match.left, match.right
	local lHuman = (L.player ~= nil)
	local rHuman = (R.player ~= nil)

	-- two humans -> normal PvP
	if lHuman and rHuman then
		task.spawn(runMatch, tableId)
		return
	end

	-- empty table -> nothing to do
	if not lHuman and not rHuman then return end

	-- exactly one human -> arm bot grace timer
	if not BOTS_ENABLED then return end
	if match._botPending then return end
	match._botPending = true

	task.delay(BOT_GRACE, function()
		match._botPending = false
		if match.phase ~= "WAITING" then return end

		local stillL = (L.player ~= nil)
		local stillR = (R.player ~= nil)

		if stillL and stillR then
			task.spawn(runMatch, tableId) -- a 2nd human arrived
			return
		end
		if not stillL and not stillR then return end -- human left

		local emptySide = stillL and R or L
		local emptySeat = stillL and match.rightSeat or match.leftSeat
		local emptyName = stillL and "Right" or "Left"
		if emptySide.player ~= nil then return end

		local botChar = BotManager.spawnBot(emptySeat, emptyName)
		if not botChar then return end
		emptySide.isBot = true
		emptySide.botChar = botChar

		task.spawn(runMatch, tableId)
	end)
end

-------------------------------------------------------
-- CHOICE SUBMISSION
-------------------------------------------------------
SubmitChoice.OnServerEvent:Connect(function(player, tableId, choice)
	local match = Matches[tableId]
	if not match or match.phase ~= "CHOOSING" then return end

	local side = (match.left.player == player) and match.left
	          or (match.right.player == player) and match.right
	          or nil
	if not side or side.confirmed then return end
	if not CombatResolver.isValidChoice(choice, side.bullets) then return end

	side.choice = choice
	side.confirmed = true
end)

-------------------------------------------------------
-- TABLE SETUP
-------------------------------------------------------
local function setupTable(chairSystem)
	local tableIdVal = chairSystem:FindFirstChild("TableId")
	if not tableIdVal then return end

	local tableId = tableIdVal.Value
	local leftSeat  = chairSystem.LeftChair and chairSystem.LeftChair:FindFirstChild("Seat")
	local rightSeat = chairSystem.RightChair and chairSystem.RightChair:FindFirstChild("Seat")
	if not leftSeat or not rightSeat then return end

	Matches[tableId] = MatchState.newMatch(tableId, leftSeat, rightSeat)
	local match = Matches[tableId]
	match.rewardValueObject = chairSystem:FindFirstChild("RewardCoins")

	SeatManager.listen(leftSeat, rightSeat,
		function(side, player) -- onSit
			match[side].player = player
			tryFillTable(tableId)
		end,
		function(side, _player) -- onStand
			-- force back into seat if a match is live
			if match.phase ~= "WAITING" and match.phase ~= "GAMEOVER" then
				local seat = (side == "left") and leftSeat or rightSeat
				local char = _player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and char then
					task.defer(function() seat:Sit(hum) end)
					return
				end
			end
			match[side].player = nil
			cleanupBots(match)
			match.phase = "WAITING"
		end
	)
end

for _, child in ipairs(workspace:GetDescendants()) do
	if child.Name == "ChairSystem" and child:IsA("Folder") then
		setupTable(child)
	end
end

Players.PlayerRemoving:Connect(function(player)
	for _, match in pairs(Matches) do
		local left = match.left.player == player
		local right = match.right.player == player
		if left or right then
			if left then match.left.player = nil end
			if right then match.right.player = nil end
			cleanupBots(match)
			match.phase = "WAITING"
		end
	end
end)
