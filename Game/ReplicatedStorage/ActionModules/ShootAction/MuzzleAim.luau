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
	local rawAxis = axis
	local mainPart = DuelEffectUtils.getPart(pistol, "Main")
	if mainPart and (muzzleTip.Position - mainPart.Position):Dot(axis) < 0 then
		axis = -axis
	end

	-- flatten to horizontal, then snap to the nearest world cardinal axis so the
	-- slug flies dead-straight along one axis regardless of the recoil pose.
	local flat = Vector3.new(axis.X, 0, axis.Z)
	local snapped = false
	if flat.Magnitude > 0.05 then
		snapped = true
		if math.abs(flat.X) >= math.abs(flat.Z) then
			axis = Vector3.new(flat.X >= 0 and 1 or -1, 0, 0)
		else
			axis = Vector3.new(0, 0, flat.Z >= 0 and 1 or -1)
		end
	end
	print(string.format("[MUZZLE-DBG] side=%s rawZ=(%.3f, %.3f, %.3f) flatMag=%.4f snapped=%s finalAxis=(%.2f, %.2f, %.2f)", tostring(side), rawAxis.X, rawAxis.Y, rawAxis.Z, flat.Magnitude, tostring(snapped), axis.X, axis.Y, axis.Z))

	-- Bullet starts from its own anchor if present (decoupled from the flash),
	-- otherwise falls back to the muzzle tip.
	local bulletPart = DuelEffectUtils.getPart(pistol, "BulletOrigin")
	local bulletOrigin = bulletPart and bulletPart.Position or muzzleTip.Position

	-- returns: pistol, muzzleTip, flashOrigin, axis, bulletOrigin
	return pistol, muzzleTip, muzzleTip.Position, axis, bulletOrigin
end

return MuzzleAim
