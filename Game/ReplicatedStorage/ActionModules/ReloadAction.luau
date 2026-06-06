local DuelEffectUtils = require(script.Parent:WaitForChild("DuelEffectUtils"))
local EventHub        = require(game:GetService("ReplicatedStorage"):WaitForChild("EventHub"))

local ReloadAction = {}
local RELOAD_ANIM_ID = "rbxassetid://102623437731139"

-- Fraction through the clip where the magazine "seats" (when the sound hits).
-- Tune this to line the click up with the visual. 0 = start, 1 = end.
local RELOAD_SOUND_MOMENT = 0.4

function ReloadAction.perform(character, chairSystem, side)
	local gunInfo = DuelEffectUtils.setupGun(character, chairSystem, side)

	-- The gun part we emit the sound from (falls back to the character).
	local pistol = chairSystem:FindFirstChild(side .. "Pistol")
	local gunPart = pistol and DuelEffectUtils.getPart(pistol, "Main")

	local track = DuelEffectUtils.playAnimation(character, RELOAD_ANIM_ID, "ReloadAction", function()
		DuelEffectUtils.teardownGun(gunInfo)
	end)

	local function playReloadSound()
		EventHub.ReloadEvent:Fire(character, side, gunPart)
	end

	-- Sync the click to a point in the anim (mirrors ShootAction's fire moment).
	if track then
		while track.Length == 0 and track.IsPlaying do
			task.wait()
		end
		if track.Length > 0 then
			task.delay((track.Length * RELOAD_SOUND_MOMENT) / track.Speed, playReloadSound)
		else
			playReloadSound()
		end
	else
		playReloadSound()
	end
end

return ReloadAction
