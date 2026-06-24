--[[
	TableFiller
	Decides who fills a table's seats: two humans start immediately; a lone human
	gets a bot after a grace timer (if bots are enabled), or on demand via
	Play-With-AI. The runMatch function is INJECTED at construction so this module
	never has to require MatchRunner (avoids a require cycle).
]]

local MatchConfig = require(script.Parent:WaitForChild("MatchConfig"))
local BotManager  = require(script.Parent:WaitForChild("Bot"):WaitForChild("BotManager"))

local TableFiller = {}
TableFiller.__index = TableFiller

-- runMatch(match) -> starts a match for the given match object.
function TableFiller.new(runMatch)
	return setmetatable({ _runMatch = runMatch }, TableFiller)
end

-- Humans-first fill: two humans start now; a lone human arms the bot grace timer.
function TableFiller:tryFill(match)
	if not match then return end
	if match.phase ~= "WAITING" then return end

	local L, R = match.left, match.right
	local lHuman = (L.player ~= nil)
	local rHuman = (R.player ~= nil)

	if lHuman and rHuman then
		task.spawn(self._runMatch, match)
		return
	end
	if not lHuman and not rHuman then return end  -- empty table

	-- exactly one human -> arm bot grace timer
	if not MatchConfig.BOTS_ENABLED then return end
	if match._botPending then return end
	match._botPending = true

	task.delay(MatchConfig.BOT_GRACE, function()
		match._botPending = false
		if match.phase ~= "WAITING" then return end

		local stillL = (L.player ~= nil)
		local stillR = (R.player ~= nil)
		if stillL and stillR then
			task.spawn(self._runMatch, match)  -- a 2nd human arrived
			return
		end
		if not stillL and not stillR then return end  -- human left

		local emptySide = stillL and R or L
		local emptySeat = stillL and match.rightSeat or match.leftSeat
		local emptyName = stillL and "Right" or "Left"
		if emptySide.player ~= nil then return end

		local botChar = BotManager.spawnBot(emptySeat, emptyName)
		if not botChar then return end
		emptySide.isBot = true
		emptySide.botChar = botChar
		task.spawn(self._runMatch, match)
	end)
end

-- Play-With-AI: drop a bot opposite a seated human on demand (bypasses grace).
function TableFiller:requestBot(match, humanSideName)
	if not match or match.phase ~= "WAITING" then return end
	if match._botPending then return end

	local humanSide = (humanSideName == "left") and match.left or match.right
	local emptySide = (humanSideName == "left") and match.right or match.left
	local emptySeat = (humanSideName == "left") and match.rightSeat or match.leftSeat
	local emptyName = (humanSideName == "left") and "Right" or "Left"

	if humanSide.player == nil then return end
	if emptySide.player ~= nil then return end
	if emptySide.isBot then return end

	match._botPending = true
	local botChar = BotManager.spawnBot(emptySeat, emptyName)
	match._botPending = false
	if not botChar then return end

	emptySide.isBot = true
	emptySide.botChar = botChar
	task.spawn(self._runMatch, match)
end

return TableFiller
