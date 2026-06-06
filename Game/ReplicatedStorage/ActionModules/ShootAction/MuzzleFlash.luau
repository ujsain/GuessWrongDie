-- Cosmetic flash + light at the muzzle tip.
-- (The gunshot SOUND now lives in the dedicated sound layer: ShootAction
--  fires EventHub.ShootEvent at the fire moment, and SoundController plays it.)
local MuzzleFlash = {}

local MuzzleFlashTemplate = game:GetService("ReplicatedStorage"):WaitForChild("Particles"):WaitForChild("MuzzleFlashEffect")
local templateAtt = MuzzleFlashTemplate:WaitForChild("Attachment")

function MuzzleFlash.fire(muzzleTip, origin, axis)
	local att = templateAtt:Clone()
	att.Name = "MuzzleFlashFX"
	att.Parent = muzzleTip
	att.WorldCFrame = CFrame.lookAt(origin, origin + axis)

	for _, child in ipairs(att:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child.Enabled = true
		elseif child:IsA("PointLight") then
			child.Enabled = true
		end
	end

	task.delay(0.1, function()
		for _, child in ipairs(att:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			elseif child:IsA("PointLight") then
				child.Enabled = false
			end
		end
		task.delay(1.2, function()
			att:Destroy()
		end)
	end)
end

return MuzzleFlash
