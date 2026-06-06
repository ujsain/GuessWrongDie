--[[
	DamageVisuals
	Single responsibility: visual feedback for damage.
	Flash red on hit, sync Humanoid HP to match health.
]]

local DamageVisuals = {}

-- Brief red flash on all visible parts
function DamageVisuals.flashRed(character)
	if not character then return end
	local originalColors = {}
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			originalColors[part] = part.Color
			part.Color = Color3.fromRGB(255, 50, 50)
		end
	end
	task.delay(0.3, function()
		for part, color in pairs(originalColors) do
			if part and part.Parent then
				part.Color = color
			end
		end
	end)
end

-- Set Humanoid HP to match the game's health ratio
function DamageVisuals.syncHealth(character, hp, maxHP)
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if hp <= 0 then
		hum.Health = 0
	else
		hum.Health = (hp / maxHP) * hum.MaxHealth
	end
end

return DamageVisuals
