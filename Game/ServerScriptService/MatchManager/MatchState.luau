--[[
	MatchState
	Create and reset match state objects.
	Now each side also tracks isBot / botChar (identity is NOT
	wiped by round/match resets -- only health, bullets, choices).
]]
local MatchState = {}

-- MAX_HEALTH is owned by MatchConfig so there is ONE source of truth on the server.
local MatchConfig = require(script.Parent:WaitForChild("MatchConfig"))

local CONFIG = {
	START_HEALTH = MatchConfig.MAX_HEALTH,
}

function MatchState.newPlayerState()
	return {
		player    = nil,
		isBot     = false,
		botChar   = nil,
		health    = CONFIG.START_HEALTH,
		bullets   = 0,
		choice    = nil,
		confirmed = false,
	}
end

function MatchState.newMatch(tableId, leftSeat, rightSeat)
	return {
		tableId   = tableId,
		leftSeat  = leftSeat,
		rightSeat = rightSeat,
		left      = MatchState.newPlayerState(),
		right     = MatchState.newPlayerState(),
		phase     = "WAITING",
	}
end

function MatchState.resetForNewRound(match)
	match.left.choice     = nil
	match.left.confirmed  = false
	match.right.choice    = nil
	match.right.confirmed = false
end

function MatchState.resetForNewMatch(match)
	match.left.health    = CONFIG.START_HEALTH
	match.left.bullets   = 0
	match.right.health   = CONFIG.START_HEALTH
	match.right.bullets  = 0
	match.phase          = "WAITING"
	MatchState.resetForNewRound(match)
end

function MatchState.getConfig()
	return CONFIG
end

return MatchState
