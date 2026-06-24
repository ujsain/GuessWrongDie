--[[
	GunSelection
	Per-player pistol selection + swapping a seat's pistol model on sit/stand.
	The single source of truth for which gun a player carries into a duel.

	Swap is transparent to the duel code: the new model keeps the same name
	(LeftPistol/RightPistol) and Dependencies (Main/AnimationOffset/MuzzleTip/
	BulletOrigin), so setupGun / MuzzleAim / Bullet / sounds all keep working.

	Each gun may carry a Vector3Value "PositionOffset" in its Dependencies. On
	swap the model is placed at the seat's canonical resting spot, then nudged
	by that offset in world space: X/Z horizontal, Y up.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PISTOLS  = ReplicatedStorage:WaitForChild("Pistols")
local DEFAULT  = "L35"

local GunSelection = {}
GunSelection.DEFAULT = DEFAULT

-- player -> gun name (in memory; cleared when they leave)
local selected = {}

-- chairSystem -> { [pistolName] = canonicalHomeCFrame } ; offsets backed out
local homes = setmetatable({}, { __mode = "k" })

local function sidePistolName(side)
	local s = tostring(side):lower()
	if s == "left"  then return "LeftPistol"  end
	if s == "right" then return "RightPistol" end
	return nil
end

local function templateFor(name)
	return (name and PISTOLS:FindFirstChild(name)) or PISTOLS:FindFirstChild(DEFAULT)
end

local function mainOf(model)
	local deps = model and model:FindFirstChild("Dependencies")
	return deps and deps:FindFirstChild("Main")
end

local function offsetOf(model)
	local deps = model and model:FindFirstChild("Dependencies")
	local v = deps and deps:FindFirstChild("PositionOffset")
	if v and v:IsA("Vector3Value") then return v.Value end
	return Vector3.zero
end

--------------------------------------------------------------------
-- Selection state
--------------------------------------------------------------------
function GunSelection.get(player)
	return selected[player] or DEFAULT
end

function GunSelection.set(player, gunName)
	if type(gunName) ~= "string" then return false end
	if not PISTOLS:FindFirstChild(gunName) then
		warn(("[GunSelection] unknown gun %q - ignored"):format(gunName))
		return false
	end
	selected[player] = gunName
	return true
end

--------------------------------------------------------------------
-- Swap mechanic
--------------------------------------------------------------------
local function swap(chairSystem, side, gunName)
	if not chairSystem then return end
	local pistolName = sidePistolName(side)
	if not pistolName then return end

	local current = chairSystem:FindFirstChild(pistolName)

	-- Establish the drift-proof canonical home for this seat once: take the
	-- current pistol's resting Main and back out whatever offset it carries.
	homes[chairSystem] = homes[chairSystem] or {}
	if not homes[chairSystem][pistolName] then
		local cMain = mainOf(current)
		if cMain then
			homes[chairSystem][pistolName] = cMain.CFrame - offsetOf(current)
		end
	end

	-- Already the requested gun? nothing to rebuild.
	if current and current:GetAttribute("GunName") == gunName then return end

	local template = templateFor(gunName)
	if not template then return end

	local clone = template:Clone()
	clone.Name = pistolName
	clone:SetAttribute("GunName", template.Name)

	local newMain = mainOf(clone)
	if not newMain then clone:Destroy(); return end

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end

	-- Place at canonical home, nudged by this gun's PositionOffset (world space).
	local home = homes[chairSystem][pistolName]
		or (mainOf(current) and mainOf(current).CFrame)
		or clone:GetPivot()

	clone.PrimaryPart = newMain
	clone:PivotTo(home + offsetOf(clone))
	clone.Parent = chairSystem

	if current then current:Destroy() end
end

-- side is "left"/"right" (as SeatManager reports)
function GunSelection.applyForPlayer(chairSystem, side, player)
	swap(chairSystem, side, GunSelection.get(player))
end

function GunSelection.restoreDefault(chairSystem, side)
	swap(chairSystem, side, DEFAULT)
end

--------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	selected[player] = nil
end)

return GunSelection
