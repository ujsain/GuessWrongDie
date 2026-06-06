--[[
	RoundAnimator
	Single responsibility: play the correct action animations
	for both players after a round resolves.
]]
local RS = game:GetService("ReplicatedStorage")

local ShootAction   = require(RS:WaitForChild("ActionModules"):WaitForChild("ShootAction"))
local ReloadAction  = require(RS:WaitForChild("ActionModules"):WaitForChild("ReloadAction"))
local DeflectAction = require(RS:WaitForChild("ActionModules"):WaitForChild("DeflectAction"))

local RoundAnimator = {}

-- Given a shooter and what the OTHER player did, pick the bullet's behaviour.
local function shootMode(otherChoice)
	if otherChoice == "Deflect" then return "deflected" end
	if otherChoice == "Shoot"   then return "collide"   end
	return "straight"
end

local function playAction(choice, character, chairSystem, side, onFireMoment, mode)
	if choice == "Shoot" then
		ShootAction.perform(character, chairSystem, side, onFireMoment, mode)
	elseif choice == "Reload" then
		ReloadAction.perform(character, chairSystem, side)
	elseif choice == "Deflect" then
		DeflectAction.perform(character, chairSystem, side)
	end
end

-- onFireMoment drives HP + red flash; it is guarded one-shot on the client,
-- so it is safe to hand to both shooters in the collide case.
function RoundAnimator.playRound(myChoice, oppChoice, myChar, oppChar, chairSystem, mySide, oppSide, onFireMoment)
	if myChar then
		task.spawn(playAction, myChoice, myChar, chairSystem, mySide,
			myChoice == "Shoot" and onFireMoment or nil,
			myChoice == "Shoot" and shootMode(oppChoice) or nil)
	end
	if oppChar then
		task.spawn(playAction, oppChoice, oppChar, chairSystem, oppSide,
			oppChoice == "Shoot" and onFireMoment or nil,
			oppChoice == "Shoot" and shootMode(myChoice) or nil)
	end
end

return RoundAnimator
