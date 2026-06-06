--[[
	BotBrain
	Decides a bot's action for a round.
	v1: random VALID choice (Shoot only when it has ammo).
	Swap this body later for ammo-tracking / difficulty tiers --
	nothing else needs to change.
]]
local BotBrain = {}

local WITH_AMMO = {"Shoot", "Reload", "Deflect"}
local NO_AMMO   = {"Reload", "Deflect"}

-- side = the bot's MatchState side table { bullets, health, ... }
function BotBrain.decide(side)
	local pool = (side.bullets >= 1) and WITH_AMMO or NO_AMMO
	--return "Reload"
	return pool[math.random(1, #pool)]
end

return BotBrain
