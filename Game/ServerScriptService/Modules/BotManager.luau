--[[
	BotManager
	Owns the physical bot rig. The cloned rig carries an "Animate"
	script (same one player characters use), so once it's seated it
	auto-plays the sitting pose.
	On death the bot uses Roblox's DEFAULT joint break (no ragdoll).
]]
local ServerStorage = game:GetService("ServerStorage")

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

	hum.BreakJointsOnDeath = true  -- default break-apart on death
	hum.DisplayName = "Dead-Eye Dan"

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

-- Kill the bot: default joint break (no ragdoll constraints).
function BotManager.killBot(character)
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.Health = 0
end

function BotManager.despawnBot(character)
	if character and character.Parent then
		character:Destroy()
	end
end

return BotManager
