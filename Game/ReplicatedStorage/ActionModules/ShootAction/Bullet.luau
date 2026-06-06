-- The physical slug: clone, move, impact. Purely cosmetic.
-- The slug's look is the child template part `DuelBullet` (edit it in Studio).
local Bullet = {}

local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")
local Config       = require(script.Parent:WaitForChild("Config"))
local EventHub     = require(game:GetService("ReplicatedStorage"):WaitForChild("EventHub"))

local TEMPLATE = script:WaitForChild("DuelBullet")

-- Clone the prebuilt slug at `origin` facing `dir`.
local function createSlug(origin, dir)
	local slug = TEMPLATE:Clone()
	slug.CFrame = CFrame.new(origin, origin + dir)
	slug.Parent = workspace
	return slug, slug:FindFirstChildWhichIsA("Trail")
end

-- Tween a slug from its current spot to destPos (facing travel dir), then onArrive.
local function moveTo(slug, destPos, onArrive)
	local dir = destPos - slug.Position
	local distance = dir.Magnitude
	if distance < 0.05 then
		if onArrive then onArrive() end
		return
	end
	dir = dir.Unit

	local travelTime = math.max(distance / Config.BULLET_SPEED, 0.02)
	local tween = TweenService:Create(
		slug,
		TweenInfo.new(travelTime, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(destPos, destPos + dir) }
	)
	tween.Completed:Once(function()
		if onArrive then onArrive() end
	end)
	tween:Play()
end

-- Basic dust puff (placeholder; richer effects later).
local function dustPuff(pos)
	local dust = Instance.new("Part")
	dust.Shape = Enum.PartType.Ball
	dust.Size = Vector3.new(0.1, 0.1, 0.1)
	dust.Color = Config.DUST_COLOR
	dust.Material = Enum.Material.Sand
	dust.Transparency = 0.3
	dust.Anchored = true
	dust.CanCollide = false
	dust.CanQuery = false
	dust.CastShadow = false
	dust.Position = pos
	dust.Parent = workspace
	TweenService:Create(
		dust,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.9, 0.9, 0.9), Transparency = 1 }
	):Play()
	Debris:AddItem(dust, 0.3)
end

local function destroySlug(slug, trail)
	if not slug or not slug.Parent then return end
	slug.Transparency = 1
	if trail then trail.Enabled = false end
	Debris:AddItem(slug, (trail and trail.Lifetime or 0.1) + 0.05)
end

-- Fake gravity: the dead slug falls (accelerating) and fades out.
local function dropAndFade(slug, trail)
	if not slug or not slug.Parent then return end
	if trail then trail.Enabled = false end
	local goal = slug.CFrame + Vector3.new(0, -Config.COLLIDE_DROP_DISTANCE, 0)
	local tween = TweenService:Create(
		slug,
		TweenInfo.new(Config.COLLIDE_DROP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = goal, Transparency = 1 }
	)
	tween.Completed:Once(function()
		if slug and slug.Parent then slug:Destroy() end
	end)
	tween:Play()
end

-- Straight shot: muzzle -> first hit (or max range).
function Bullet.fireStraight(origin, axis, shooterChar, pistol)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { shooterChar, pistol }
	params.IgnoreWater = true

	local hit = workspace:Raycast(origin, axis * Config.BULLET_MAX_RANGE, params)
	local endPos = hit and hit.Position or (origin + axis * Config.BULLET_MAX_RANGE)
	if (endPos - origin).Magnitude < 0.1 then return end

	local slug, trail = createSlug(origin, axis)
	moveTo(slug, endPos, function()
		if hit then
			dustPuff(endPos)
			-- Bullet reached a target: impact sound at the hit point.
			EventHub.BulletHitEvent:Fire(endPos)
		end
		destroySlug(slug, trail)
	end)
end

-- Deflected shot: muzzle -> fixed forward point -> back to the shooter's body.
-- onReturnHit fires the instant the slug reaches the shooter (drives HP/flash).
function Bullet.fireDeflected(origin, axis, shooterChar, onReturnHit)
	local bouncePos = origin + axis * Config.DEFLECT_FORWARD_DISTANCE

	local returnPos = origin
	local root = shooterChar and shooterChar:FindFirstChild("HumanoidRootPart")
	if root then returnPos = root.Position end

	local slug, trail = createSlug(origin, axis)
	moveTo(slug, bouncePos, function()
		dustPuff(bouncePos)              -- placeholder ricochet
		-- Bullet hit the shield and is bouncing back.
		EventHub.BulletReflectedEvent:Fire(bouncePos)
		moveTo(slug, returnPos, function()
			dustPuff(returnPos)          -- hit on the shooter
			-- Reflected bullet hits the (shooter) player.
			EventHub.BulletHitEvent:Fire(returnPos)
			if onReturnHit then onReturnHit() end
			destroySlug(slug, trail)
		end)
	end)
end

-- Both-shoot collision: muzzle -> meeting point, clink, then drop + fade.
-- onCollide fires when the slug reaches the meeting point.
function Bullet.fireColliding(origin, meetingPos, onCollide)
	local dir = meetingPos - origin
	if dir.Magnitude < 0.05 then
		if onCollide then onCollide() end
		return
	end

	local slug, trail = createSlug(origin, dir.Unit)
	moveTo(slug, meetingPos, function()
		dustPuff(meetingPos)             -- placeholder clink
		-- Two slugs meet mid-air. SoundController debounces the double-fire.
		EventHub.BulletsCollideEvent:Fire(meetingPos)
		if onCollide then onCollide() end
		dropAndFade(slug, trail)
	end)
end

return Bullet
