local Players = game:GetService("Players")
local RagdollUtil = require(script:WaitForChild("RagdollUtil"))

local function ragdoll(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	-- NOTE: ChangeState(Physics) is handled client-side (RagdollClient)
	-- because server ChangeState doesn't replicate to other players.
	RagdollUtil.applyConstraints(character)
end

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.BreakJointsOnDeath = false

	local healthScript = character:FindFirstChild("Health")
	if healthScript then healthScript:Destroy() end
	humanoid:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		if humanoid:GetAttribute("Ragdolled") == true then
			ragdoll(character)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	if player.Character then onCharacterAdded(player.Character) end
	player.CharacterAdded:Connect(onCharacterAdded)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then onCharacterAdded(player.Character) end
	player.CharacterAdded:Connect(onCharacterAdded)
end
