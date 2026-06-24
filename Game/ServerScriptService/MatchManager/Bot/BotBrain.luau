--[[
	BotBrain
	Decides a bot's action for a round.
	v1: random VALID choice (Shoot only when it has ammo).
	Swap this body later for ammo-tracking / difficulty tiers --
	nothing else needs to change.
]]
local BotBrain = {}

local WITH_AMMO           = {"Shoot", "Reload", "Deflect"}
local NO_AMMO             = {"Reload", "Deflect"}
-- Same pools minus Deflect, used while deflect is on cooldown.
local WITH_AMMO_NODEFLECT = {"Shoot", "Reload"}
local NO_AMMO_NODEFLECT   = {"Reload"}

-- side = the bot's MatchState side table { bullets, health, ... }
-- deflectLocked = true when Deflect is currently on cooldown (must not be picked)
function BotBrain.decide(side, deflectLocked)
	local pool
	if side.bullets >= 1 then
		pool = deflectLocked and WITH_AMMO_NODEFLECT or WITH_AMMO
	else
		pool = deflectLocked and NO_AMMO_NODEFLECT or NO_AMMO
	end
	return pool[math.random(1, #pool)]
end

return BotBrain
