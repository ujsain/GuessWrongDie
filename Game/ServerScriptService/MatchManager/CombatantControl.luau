--[[
	CombatantControl
	Everything that physically affects a duelist's avatar -- works for both human
	players and bot rigs. Keeps Humanoid pokes (health sync, movement lock,
	ragdoll) and bot lifecycle out of the match loop.
]]

local MatchConfig = require(script.Parent:WaitForChild("MatchConfig"))
local BotManager  = require(script.Parent:WaitForChild("Bot"):WaitForChild("BotManager"))

local CombatantControl = {}

-- The character backing a side (bot rig or human character), or nil.
function CombatantControl.charOf(side)
	if side.isBot then return side.botChar end
	return side.player and side.player.Character
end

-- Stable token to detect "this occupant left / changed".
function CombatantControl.token(side)
	if side.isBot then return side.botChar end
	return side.player
end

-- Match HP (0..MAX_HEALTH) -> Humanoid.Health.
function CombatantControl.syncHealth(side, matchHealth)
	local char = CombatantControl.charOf(side)
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local ratio = matchHealth / MatchConfig.MAX_HEALTH
	hum.Health = math.max(0, ratio * hum.MaxHealth)
end

function CombatantControl.lock(side)
	local char = CombatantControl.charOf(side)
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.JumpPower = 0; hum.WalkSpeed = 0 end
end

function CombatantControl.unlock(side)
	local char = CombatantControl.charOf(side)
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.JumpPower = 50; hum.WalkSpeed = 16 end
end

-- Kill/ragdoll a side. Bots route through BotManager; humans zero out + flag.
function CombatantControl.ragdoll(side)
	local char = CombatantControl.charOf(side)
	if not char then return end
	if side.isBot then
		BotManager.killBot(char)
	else
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
			hum:SetAttribute("Ragdolled", true)
		end
	end
end

-- Fire a remote only to human sides (bots have no client).
function CombatantControl.fireHuman(remote, side, ...)
	if side.player then remote:FireClient(side.player, ...) end
end

-- Despawn any bots on a match and clear their registration.
function CombatantControl.cleanupBots(match)
	for _, s in ipairs({ match.left, match.right }) do
		if s.isBot then
			BotManager.despawnBot(s.botChar)
			s.isBot = false
			s.botChar = nil
		end
	end
end

return CombatantControl
