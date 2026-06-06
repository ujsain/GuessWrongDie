-- Muzzle origin + outward, horizontally-flattened barrel axis.
-- Flash emits from MuzzleTip; the bullet emits from BulletOrigin (if present)
-- so the two can be positioned independently.
local MuzzleAim = {}

local DuelEffectUtils = require(script.Parent.Parent:WaitForChild("DuelEffectUtils"))

function MuzzleAim.get(chairSystem, side)
	local pistol = chairSystem:FindFirstChild(side .. "Pistol")
	if not pistol then return nil end

	local muzzleTip = DuelEffectUtils.getPart(pistol, "MuzzleTip")
	if not muzzleTip then return nil end

	local axis = muzzleTip.CFrame.ZVector
	local mainPart = DuelEffectUtils.getPart(pistol, "Main")
	if mainPart and (muzzleTip.Position - mainPart.Position):Dot(axis) < 0 then
		axis = -axis
	end

	-- flatten to horizontal so the slug flies level instead of drooping
	local flat = Vector3.new(axis.X, 0, axis.Z)
	if flat.Magnitude > 0.05 then
		axis = flat.Unit
	end

	-- Bullet starts from its own anchor if present (decoupled from the flash),
	-- otherwise falls back to the muzzle tip.
	local bulletPart = DuelEffectUtils.getPart(pistol, "BulletOrigin")
	local bulletOrigin = bulletPart and bulletPart.Position or muzzleTip.Position

	-- returns: pistol, muzzleTip, flashOrigin, axis, bulletOrigin
	return pistol, muzzleTip, muzzleTip.Position, axis, bulletOrigin
end

return MuzzleAim
