local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local ShootAction = require(RS.ActionModules:WaitForChild("ShootAction"))
local ReloadAction = require(RS.ActionModules:WaitForChild("ReloadAction"))
local DeflectAction = require(RS.ActionModules:WaitForChild("DeflectAction"))

local currentChairSystem = nil
local mySide = nil
local busy = false

local function getChairSystem(seat)
	local parent = seat.Parent
	while parent and parent ~= workspace do
		if parent:FindFirstChild("TableId") then return parent end
		parent = parent.Parent
	end
	return nil
end

local function getSide(chairSystem)
	local leftSeat = chairSystem.LeftChair and chairSystem.LeftChair:FindFirstChild("Seat")
	if leftSeat and leftSeat.Occupant then
		local char = leftSeat.Occupant.Parent
		if char and Players:GetPlayerFromCharacter(char) == player then
			return "Left"
		end
	end
	return "Right"
end

local function onSeated(active, seat)
	if active and seat then
		local cs = getChairSystem(seat)
		if cs then
			currentChairSystem = cs
			mySide = getSide(cs)
		end
	else
		currentChairSystem = nil
		mySide = nil
	end
end

UIS.InputBegan:Connect(function(input, processed)
	if processed or not currentChairSystem or busy then return end
	local char = player.Character
	if not char then return end

	if input.KeyCode == Enum.KeyCode.One then
		busy = true
		ReloadAction.perform(char, currentChairSystem, mySide)
		busy = false

	elseif input.KeyCode == Enum.KeyCode.Two then
		busy = true
		ShootAction.perform(char, currentChairSystem, mySide)
		busy = false

	elseif input.KeyCode == Enum.KeyCode.Three then
		busy = true
		DeflectAction.perform(char, currentChairSystem, mySide)
		busy = false
	end
end)

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(onSeated)
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

