--[[
	MatchOutcome
	All the side-effects of a match's result in ONE place: leaderboard wins,
	analytics rows, and coin payouts. Keeps economy/analytics out of the match
	loop -- the combat flow just says "this side won" and MatchOutcome does the rest.
]]

local SSS     = game:GetService("ServerScriptService")
local MatchConfig        = require(script.Parent:WaitForChild("MatchConfig"))   -- sibling (match subsystem)
local CoinService        = require(SSS:WaitForChild("Data"):FindFirstChild("CoinService", true))
local MatchTracker       = require(SSS:WaitForChild("Analytics"):WaitForChild("MatchTracker"))
local LeaderboardService = require(SSS:WaitForChild("LeaderboardService"))

local MatchOutcome = {}

-- The human, non-bot player on a side (nil if bot / empty seat).
local function humanOf(side)
	if side and side.player and not side.isBot then return side.player end
	return nil
end

-- Pay a side's human the table reward (if any), after a short beat.
local function payReward(match, side)
	if not side or side.isBot or not side.player then return end
	local rv = match.rewardValueObject
	local reward = rv and rv.Value or 0
	if reward <= 0 then return end
	local plr = side.player
	task.delay(MatchConfig.COIN_REWARD_DELAY, function()
		if plr and plr.Parent then
			CoinService.Add(plr, reward, "Match Win")
		end
	end)
end

-- The match truly begins (both occupants confirmed present).
function MatchOutcome.matchStarted(match)
	local L, R = match.left, match.right
	local humans = {}
	if humanOf(L) then table.insert(humans, L.player) end
	if humanOf(R) then table.insert(humans, R.player) end
	if #humans > 0 then MatchTracker.MatchStarted(humans, match.tableId) end
end

-- Opponent left: the remaining human wins by forfeit.
function MatchOutcome.forfeit(match, remaining)
	LeaderboardService.AddWin(humanOf(remaining))
	if humanOf(remaining) then
		-- No duration: a rage-quit shouldn't skew the average. The leaver's Abort
		-- row is logged by MatchTracker on PlayerRemoving.
		MatchTracker.MatchEnded({ { player = remaining.player, outcome = "Win" } }, match.tableId)
	end
	payReward(match, remaining)
end

-- Normal finish. winnerSide is nil on a draw.
function MatchOutcome.gameOver(match, winnerSide, isDraw)
	local L, R = match.left, match.right
	LeaderboardService.AddWin(humanOf(winnerSide))

	local duration = match._startClock and (os.clock() - match._startClock) or nil
	local function outcomeFor(side)
		if isDraw then return "Draw" end
		if side == winnerSide then return "Win" end
		return "Loss"
	end

	local results = {}
	if humanOf(L) then
		table.insert(results, { player = L.player, outcome = outcomeFor(L), duration = duration,
			opponent = (R.isBot and "Bot") or (R.player and tostring(R.player.UserId)) or nil })
	end
	if humanOf(R) then
		table.insert(results, { player = R.player, outcome = outcomeFor(R), duration = duration,
			opponent = (L.isBot and "Bot") or (L.player and tostring(L.player.UserId)) or nil })
	end
	if #results > 0 then MatchTracker.MatchEnded(results, match.tableId) end

	payReward(match, winnerSide)
end

return MatchOutcome
