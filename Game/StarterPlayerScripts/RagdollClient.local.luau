--[[
	RagdollClient (LocalScript)
	Watches ALL characters for the "Ragdolled" attribute and
	applies ChangeState(Physics) on the client so every player
	sees the ragdoll — not just the owner.
]]

local Players = game:GetService("Players")

local function watchCharacter(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 5)
	end
	if not humanoid then return end

	-- If already ragdolled (late join / stream-in), apply immediately
	if humanoid:GetAttribute("Ragdolled") == true then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end

	humanoid:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		if humanoid:GetAttribute("Ragdolled") == true then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end
	end)
end

local function onPlayerAdded(plr)
	if plr.Character then
		task.spawn(watchCharacter, plr.Character)
	end
	plr.CharacterAdded:Connect(function(char)
		task.spawn(watchCharacter, char)
	end)
end

for _, plr in ipairs(Players:GetPlayers()) do
	onPlayerAdded(plr)
end
Players.PlayerAdded:Connect(onPlayerAdded)
