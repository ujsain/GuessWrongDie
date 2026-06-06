--[[
	ChairUtils
	Pure utility: seat/table lookups. No state, no side effects.
]]

local Players = game:GetService("Players")

local ChairUtils = {}

-- Walk up from a seat to find the ChairSystem folder
function ChairUtils.getChairSystem(seat)
	local parent = seat.Parent
	while parent and parent ~= workspace do
		if parent:FindFirstChild("TableId") then return parent end
		parent = parent.Parent
	end
	return nil
end

-- Find the ChairSystem in workspace by tableId
function ChairUtils.getCurrentChairSystem(tableId)
	if not tableId then return nil end
	for _, child in ipairs(workspace:GetDescendants()) do
		if child.Name == "TableId" and child:IsA("StringValue") and child.Value == tableId then
			return child.Parent
		end
	end
	return nil
end

-- Which side is this player sitting on?
function ChairUtils.getMySide(tableId, player)
	local chairSystem = ChairUtils.getCurrentChairSystem(tableId)
	if not chairSystem then return nil end
	local leftSeat = chairSystem.LeftChair and chairSystem.LeftChair:FindFirstChild("Seat")
	if leftSeat and leftSeat.Occupant then
		local char = leftSeat.Occupant.Parent
		if char and Players:GetPlayerFromCharacter(char) == player then
			return "Left"
		end
	end
	return "Right"
end

-- Get opponent character + side
function ChairUtils.getOpponentInfo(tableId, player)
	local chairSystem = ChairUtils.getCurrentChairSystem(tableId)
	if not chairSystem then return nil, nil end
	local mySide = ChairUtils.getMySide(tableId, player)
	local oppSide = (mySide == "Left") and "Right" or "Left"
	local oppSeatModel = chairSystem:FindFirstChild(oppSide .. "Chair")
	if not oppSeatModel then return nil, nil end
	local oppSeat = oppSeatModel:FindFirstChild("Seat")
	if not oppSeat or not oppSeat.Occupant then return nil, nil end
	local oppChar = oppSeat.Occupant.Parent
	return oppChar, oppSide
end

return ChairUtils
