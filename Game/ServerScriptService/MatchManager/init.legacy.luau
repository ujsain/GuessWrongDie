--[[
	MatchManager (Server Script)
	Bootstrap + wiring. Registers each tagged ChairSystem as a table, wires its
	seat events, and routes the client remotes. The heavy lifting lives in modules:
	  MatchRunner       - the match loop
	  TableFiller       - who fills the seats (humans first, bots on grace/demand)
	  MatchOutcome      - coins / analytics / leaderboard
	  CombatantControl  - avatar + bot lifecycle
	  MatchState / CombatResolver / MatchConfig - state, rules, tuning
]]

local Players           = game:GetService("Players")
local RS                = game:GetService("ReplicatedStorage")
local SSS               = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

-- match subsystem: children of this script (used only by MatchManager)
local MatchState       = require(script:WaitForChild("MatchState"))
local CombatantControl = require(script:WaitForChild("CombatantControl"))
local TableFiller      = require(script:WaitForChild("TableFiller"))
local MatchRunner      = require(script:WaitForChild("MatchRunner"))
local CombatResolver   = require(script:WaitForChild("CombatResolver"))
local SeatManager      = require(script:WaitForChild("SeatManager"))
-- gun-equip service lives with the gun economy in Data
local GunSelection     = require(SSS:WaitForChild("Data"):WaitForChild("GunSelection"))

local EventHub     = require(RS:WaitForChild("EventHub"))
local SubmitChoice = EventHub.SubmitChoice
local RequestBot   = EventHub.RequestBot

-- tableId -> match state object
local Matches = {}

-- Wire the runner <-> filler WITHOUT a require cycle: the runner only knows how
-- to ask "refill this table", the filler only knows how to "start a match".
local runner, filler
runner = MatchRunner.new({ onNeedRefill = function(match) filler:tryFill(match) end })
filler = TableFiller.new(function(match) runner:run(match) end)

local function findMatchByPlayer(player)
	for _, match in pairs(Matches) do
		if match.left.player == player then return match, "left" end
		if match.right.player == player then return match, "right" end
	end
	return nil
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
	if choice == "Deflect" and (side.deflectCD or 0) > 0 then return end  -- this player's deflect on cooldown

	side.choice = choice
	side.confirmed = true
end)

-------------------------------------------------------
-- PLAY-WITH-AI (player-triggered bot fill)
-------------------------------------------------------
RequestBot.OnServerEvent:Connect(function(player)
	local match, sideName = findMatchByPlayer(player)
	if match then filler:requestBot(match, sideName) end
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
			GunSelection.applyForPlayer(chairSystem, side, player)
			filler:tryFill(match)
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
			GunSelection.restoreDefault(chairSystem, side)
			CombatantControl.cleanupBots(match)
			match.phase = "WAITING"
		end
	)
end

-- ============================================================
-- AUTO TABLE IDs
-- Every tagged ChairSystem gets a UNIQUE TableId, assigned here at startup
-- BEFORE any table is registered. Folders with an existing non-empty, unique id
-- are left as-is (hand-set ids survive); blanks/duplicates get Table_1, Table_2...
-- ============================================================
local function assignTableIds()
	local seen = {}
	local counter = 0
	local function freshId()
		while true do
			counter += 1
			local id = "Table_" .. counter
			if not seen[id] then
				seen[id] = true
				return id
			end
		end
	end
	for _, cs in ipairs(CollectionService:GetTagged("ChairSystem")) do
		if cs:IsA("Folder") and cs:IsDescendantOf(workspace) then
			local tv = cs:FindFirstChild("TableId")
			if tv and not tv:IsA("StringValue") then tv:Destroy(); tv = nil end
			if not tv then
				tv = Instance.new("StringValue")
				tv.Name = "TableId"
				tv.Parent = cs
			end
			local v = tv.Value
			if v ~= "" and not seen[v] then
				seen[v] = true        -- keep existing unique id
			else
				tv.Value = freshId()  -- blank or duplicate -> assign a fresh one
			end
		end
	end
end
assignTableIds()

for _, child in ipairs(CollectionService:GetTagged("ChairSystem")) do
	if child:IsA("Folder") and child:IsDescendantOf(workspace) then
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
			CombatantControl.cleanupBots(match)
			match.phase = "WAITING"
		end
	end
end)
