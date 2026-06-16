--[[
	BotManager
	Owns the physical bot rig. The cloned rig carries an "Animate"
	script (same one player characters use), so once it's seated it
	auto-plays the sitting pose.
	On death the bot ragdolls via shared RagdollUtil constraints,
	matching the player ragdoll behaviour.
]]
local ServerStorage = game:GetService("ServerStorage")
local Modules = game:GetService("ServerScriptService"):WaitForChild("Modules")
local RagdollUtil = require(Modules:WaitForChild("RagdollUtil"))

local BotManager = {}

function BotManager.spawnBot(seat, sideName)
	local template = ServerStorage:FindFirstChild("BotTemplate")
	if not template then
		warn("[BotManager] No BotTemplate in ServerStorage")
		return nil
	end

	local bot = template:Clone()
	bot.Name = "Bot"
	bot:SetAttribute("IsBot", true)

	local hrp = bot:FindFirstChild("HumanoidRootPart")
	local hum = bot:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		bot:Destroy()
		return nil
	end

	hum.BreakJointsOnDeath = false  -- keep joints intact so we can ragdoll
	hum.DisplayName = "Dead-Eye Dan"

	-- Remove the default Health regen script so it doesn't interfere
	local healthScript = bot:FindFirstChild("Health")
	if healthScript then healthScript:Destroy() end

	bot:PivotTo(seat.CFrame * CFrame.new(0, 2, 0))
	bot.Parent = workspace
	pcall(function() hrp:SetNetworkOwner(nil) end) -- server owns physics

	-- Seat it. Retry until the engine registers the occupant.
	task.spawn(function()
		for _ = 1, 10 do
			if seat.Occupant == hum then break end
			seat:Sit(hum)
			task.wait(0.1)
		end
	end)

	return bot
end

-- Kill the bot: apply ragdoll constraints + flag clients, then drop health.
function BotManager.killBot(character)
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	RagdollUtil.applyConstraints(character)
	hum:SetAttribute("Ragdolled", true)  -- RagdollClient watches this to ChangeState(Physics)
	hum.Health = 0
end

function BotManager.despawnBot(character)
	if character and character.Parent then
		character:Destroy()
	end
end

return BotManager
