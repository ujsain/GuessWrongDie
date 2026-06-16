--[[
	RagdollClient (LocalScript)
	Watches ALL characters in the workspace (players AND bots) for the
	"Ragdolled" attribute and applies ChangeState(Physics) on the client
	so every player sees the ragdoll -- not just the owner.
]]

local Workspace = game:GetService("Workspace")

local watched = {}

local function watchHumanoid(humanoid)
	if watched[humanoid] then return end
	watched[humanoid] = true

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

-- Catch all humanoids already present
for _, inst in ipairs(Workspace:GetDescendants()) do
	if inst:IsA("Humanoid") then
		watchHumanoid(inst)
	end
end

-- Catch humanoids that appear later (player respawns, bot spawns)
Workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Humanoid") then
		watchHumanoid(inst)
	end
end)
