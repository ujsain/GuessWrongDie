--[[
	SeatManager
	Single responsibility: listen to seat occupancy changes
	and call back when players sit/stand.
]]

local Players = game:GetService("Players")

local SeatManager = {}

function SeatManager.getPlayerFromSeat(seat)
	local occupant = seat.Occupant
	if not occupant then return nil end
	local character = occupant.Parent
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

function SeatManager.listen(leftSeat, rightSeat, onSit, onStand)
	local lastLeft = nil
	local lastRight = nil


	leftSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local player = SeatManager.getPlayerFromSeat(leftSeat)
		if player and player ~= lastLeft then
			lastLeft = player
			onSit("left", player)
		elseif not player and lastLeft then
			local was = lastLeft
			lastLeft = nil
			onStand("left", was)
		end
	end)

	rightSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local player = SeatManager.getPlayerFromSeat(rightSeat)
		if player and player ~= lastRight then
			lastRight = player
			onSit("right", player)
		elseif not player and lastRight then
			local was = lastRight
			lastRight = nil
			onStand("right", was)
		end
	end)
end

return SeatManager
