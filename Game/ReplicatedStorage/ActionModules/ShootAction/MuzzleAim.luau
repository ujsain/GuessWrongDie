-- Muzzle origin + outward, horizontally-flattened barrel axis.
-- Shared by the flash and the bullet so they emit from the same point.
local MuzzleAim = {}

function MuzzleAim.get(chairSystem, side)
	local pistol = chairSystem:FindFirstChild(side .. "Pistol")
	if not pistol then return nil end

	local muzzleTip = pistol:FindFirstChild("MuzzleTip")
	if not muzzleTip then return nil end

	local axis = muzzleTip.CFrame.ZVector
	local mainPart = pistol:FindFirstChild("Main")
	if mainPart and (muzzleTip.Position - mainPart.Position):Dot(axis) < 0 then
		axis = -axis
	end

	-- flatten to horizontal so the slug flies level instead of drooping
	local flat = Vector3.new(axis.X, 0, axis.Z)
	if flat.Magnitude > 0.05 then
		axis = flat.Unit
	end

	return pistol, muzzleTip, muzzleTip.Position, axis
end

return MuzzleAim
