--[[
	DuelRules
	Single source of truth for what a player is ALLOWED to do this round.
	Shared by the HUD (to grey out / block cards) and DuelClient (to gate
	confirm + reads MAX_HP). Pure functions: no state, no side effects, no UI.
]]

local DuelRules = {}

DuelRules.MAX_HP = 3
DuelRules.Choices = { Shoot = "Shoot", Reload = "Reload", Deflect = "Deflect" }

-- Shooting needs a loaded bullet.
function DuelRules.canShoot(bullets)
	return (bullets or 0) >= 1
end

-- Deflect is locked while its cooldown is still ticking.
function DuelRules.canDeflect(deflectCooldown)
	return (deflectCooldown or 0) <= 0
end

-- Is this choice legal given the current bullets + deflect cooldown?
function DuelRules.canUse(choice, bullets, deflectCooldown)
	if choice == "Shoot"   then return DuelRules.canShoot(bullets) end
	if choice == "Deflect" then return DuelRules.canDeflect(deflectCooldown) end
	return true
end

return DuelRules
