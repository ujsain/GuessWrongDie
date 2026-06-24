--[[
	MatchTracker (ServerScriptService.Analytics.MatchTracker)

	Per-match analytics for the duel. One "Match" row per finished OR aborted
	match, written to MatchLogStore (its own DataStore -- NOT ProfileStore, so
	it never bloats or risks the save profile).

	(Adapted from the SkyDiving JumpTrackerService: same session-state +
	flush-every-N-rows + abort-on-leave + BindToClose skeleton; the jump/landing
	economy logic is replaced by the duel match lifecycle.)

	Driven by MatchManager:
	  MatchTracker.MatchStarted({p1, p2}, tableId)
	  MatchTracker.MatchEnded({ {player=p, outcome="Win"|"Loss"|"Draw",
	                             duration=number?, opponent=string?}, ... }, tableId)
	Aborts (leaving mid-match) are detected here on PlayerRemoving.

	Read one player:  require(game.ServerScriptService.Analytics.MatchLogStore).Print(userId)

	Maps to the asks:
	  1 matches played   -> count of Win/Loss/Draw rows
	  2 win/loss/abort   -> outcome field per row
	  3 kept playing 1-2-3 -> matchNo (resets each server session)
	  4 avg duration     -> duration field (omitted on forfeit/abort)
	  (5 joined-vs-completed lives in AnalyticsService funnels -- separate add-on)
]]

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local MatchLogStore = require(ServerScriptService.Analytics.MatchLogStore)

local FLUSH_EVERY_ROWS = 3     -- DataStore write every N closed rows

local MatchTracker = {}

-- sessions[player] = { matchNo = n, inMatch = bool, rows = n, tableId = string? }
local sessions: { [Player]: any } = {}

local function isHuman(p): boolean
	return typeof(p) == "Instance" and p:IsA("Player")
end

local function getSession(player: Player)
	local s = sessions[player]
	if not s then
		s = { matchNo = 0, inMatch = false, rows = 0 }
		sessions[player] = s
	end
	return s
end

local function bufferRow(player: Player, row)
	row.balance = player:GetAttribute("Coins") or 0   -- handy context, harmless if unused
	MatchLogStore.Append(player.UserId, row)
	local s = sessions[player]
	if s then
		s.rows += 1
		if s.rows >= FLUSH_EVERY_ROWS then
			s.rows = 0
			task.spawn(MatchLogStore.Flush, player.UserId)
		end
	end
end

--------------------------------------------------------------------------------
-- Public API (called from MatchManager)
--------------------------------------------------------------------------------

--- Mark humans as being in a live match. A disconnect now counts as an abort.
function MatchTracker.MatchStarted(players, tableId: string?)
	for _, p in ipairs(players) do
		if isHuman(p) then
			local s = getSession(p)
			s.inMatch = true
			s.tableId = tableId
		end
	end
end

--- results: array of { player=Player, outcome="Win"|"Loss"|"Draw",
---                     duration=number?, opponent=string? }
--- Omit duration for forfeit wins so the average stays clean.
function MatchTracker.MatchEnded(results, tableId: string?)
	for _, r in ipairs(results) do
		local player = r.player
		if not isHuman(player) then continue end
		local s = getSession(player)
		s.inMatch = false
		s.matchNo += 1
		bufferRow(player, {
			type     = "Match",
			t        = os.time(),
			matchNo  = s.matchNo,
			outcome  = r.outcome,
			duration = r.duration,
			tableId  = tableId or s.tableId,
			opponent = r.opponent,
		})
	end
end

local function recordAbort(player: Player)
	local s = sessions[player]
	if not (s and s.inMatch) then return end
	s.inMatch = false
	s.matchNo += 1
	bufferRow(player, {
		type     = "Match",
		t        = os.time(),
		matchNo  = s.matchNo,
		outcome  = "Abort",
		duration = nil,
		tableId  = s.tableId,
	})
end

--------------------------------------------------------------------------------
-- Wiring (called once from DataInit)
--------------------------------------------------------------------------------
function MatchTracker.Init()
	-- Own DataStore, so unlike profile writes this has no ordering race with
	-- DataManager's session teardown -- we can record + flush freely on leave.
	Players.PlayerRemoving:Connect(function(player)
		recordAbort(player)
		MatchLogStore.Flush(player.UserId)
		sessions[player] = nil
	end)

	game:BindToClose(function()
		for player, s in pairs(sessions) do
			if s.inMatch then recordAbort(player) end
		end
		MatchLogStore.FlushAll()
	end)

	print("[MatchTracker] Ready")
end

return MatchTracker