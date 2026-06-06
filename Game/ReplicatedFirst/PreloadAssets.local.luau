--[[
	PreloadAssets (ReplicatedFirst LocalScript)
	Runs before any other client scripts.
	Preloads UI images, animations, particles, sounds, and shields
	in the BACKGROUND so the game loads normally and assets are
	ready by the time a player sits at the duel table.
]]

local ContentProvider = game:GetService("ContentProvider")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Run the whole preload on a background thread so it
-- never blocks the player from entering the game.
task.spawn(function()
	local assetsToPreload = {}

	-- 1) All UI images inside StarterGui.InGame
	local inGameGui = StarterGui:WaitForChild("InGame", 10)
	if inGameGui then
		for _, desc in ipairs(inGameGui:GetDescendants()) do
			if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
				table.insert(assetsToPreload, desc)
			end
		end
	end

	-- 2) Particle effects (muzzle flash textures + sound)
	local particles = RS:WaitForChild("Particles", 5)
	if particles then
		for _, desc in ipairs(particles:GetDescendants()) do
			if desc:IsA("ParticleEmitter") or desc:IsA("Sound") then
				table.insert(assetsToPreload, desc)
			end
		end
	end

	-- 3) Shield model (textures/meshes)
	local shields = RS:WaitForChild("Shields", 5)
	if shields then
		for _, desc in ipairs(shields:GetDescendants()) do
			if desc:IsA("BasePart") or desc:IsA("MeshPart") or desc:IsA("Decal") or desc:IsA("Texture") then
				table.insert(assetsToPreload, desc)
			end
		end
	end

	-- 4) Animations used during duels
	local animationIds = {
		"rbxassetid://136695495090944",  -- Shoot
		"rbxassetid://102623437731139",  -- Reload
		"rbxassetid://117607954022155",  -- Deflect
	}
	for _, id in ipairs(animationIds) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		table.insert(assetsToPreload, anim)
	end

	-- Preload in background — game continues loading normally
	if #assetsToPreload > 0 then
		local success, err = pcall(function()
			ContentProvider:PreloadAsync(assetsToPreload)
		end)
		if not success then
			warn("[PreloadAssets] PreloadAsync failed:", err)
		end
	end

	print(string.format("[PreloadAssets] Preloaded %d assets in background", #assetsToPreload))
end)
