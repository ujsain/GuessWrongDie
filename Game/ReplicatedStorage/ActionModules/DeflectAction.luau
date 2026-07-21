local DuelEffectUtils = require(script.Parent:WaitForChild("DuelEffectUtils"))
local EventHub        = require(game:GetService("ReplicatedStorage"):WaitForChild("EventHub"))
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")

local DeflectAction = {}
local DEFLECT_ANIM_ID = "rbxassetid://117607954022155"
local SHIELD_OFFSET = Vector3.new(0, 1, -3)
local RISE_DISTANCE = 3
local RISE_TIME = 1
-- Hard ceiling on how long a shield may exist. The deflect action visually
-- completes well within the round's resolve window, so this only ever fires
-- as a safety net if every other cleanup path fails.
local SHIELD_MAX_LIFETIME = 8

-- Default shield id. MUST stay in sync with ShieldPurchaseService.DEFAULT and a
-- real child name under ReplicatedStorage.Shields. Used for bots (no Player) and
-- as the fallback when a player's EquippedShield is missing / unknown.
local DEFAULT_SHIELD = "MarvelShield"

-- Which shield TEMPLATE this character should raise. Reads the (replicated)
-- "EquippedShield" attribute off the owning player; bots have no player, so they
-- fall back to the default. Always returns a real template (default fallback),
-- or nil only if the Shields folder is somehow empty.
local function resolveEquippedShield(character)
	local shieldsFolder = RS:WaitForChild("Shields")
	local name = DEFAULT_SHIELD
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		local equipped = player:GetAttribute("EquippedShield")
		if type(equipped) == "string" and equipped ~= "" then
			name = equipped
		end
	end
	return shieldsFolder:FindFirstChild(name) or shieldsFolder:FindFirstChild(DEFAULT_SHIELD)
end

-- Anchor + disable collisions on every part of the (cloned) shield. Works for a
-- bare Part or a multi-part Model.
local function lockParts(shield)
	if shield:IsA("BasePart") then
		shield.Anchored = true
		shield.CanCollide = false
	end
	for _, d in ipairs(shield:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
end

-- Smoothly raise the shield from startCF to targetCF. Driven through a tweened
-- NumberValue + PivotTo so it behaves identically for a single Part and a
-- multi-part Model (the whole thing moves rigidly by its pivot each frame,
-- instead of tweening one part's CFrame).
local function riseTo(shield, startCF, targetCF)
	local driver = Instance.new("NumberValue")
	driver.Value = 0
	local conn
	conn = driver:GetPropertyChangedSignal("Value"):Connect(function()
		shield:PivotTo(startCF:Lerp(targetCF, driver.Value))
	end)
	local tween = TweenService:Create(
		driver,
		TweenInfo.new(RISE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = 1 }
	)
	tween.Completed:Connect(function()
		if conn then conn:Disconnect(); conn = nil end
		driver:Destroy()
	end)
	tween:Play()
end

local function setupShield(character, side)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local template = resolveEquippedShield(character)
	if not template then return nil end
	local shield = template:Clone()

	-- Models need a PrimaryPart for PivotTo to behave predictably.
	if shield:IsA("Model") and not shield.PrimaryPart then
		shield.PrimaryPart = shield:FindFirstChildWhichIsA("BasePart", true)
	end

	-- Resting spot: in front of and slightly above the chest, facing out to the
	-- correct side. Start a few studs lower so it rises into place.
	local targetPos = (rootPart.CFrame * CFrame.new(SHIELD_OFFSET)).Position
	local startPos  = targetPos - Vector3.new(0, RISE_DISTANCE, 0)
	local yAngle    = (side == "Left") and math.rad(90) or math.rad(-90)
	local rot       = CFrame.Angles(0, yAngle, 0)
	local startCF   = CFrame.new(startPos) * rot
	local targetCF  = CFrame.new(targetPos) * rot

	lockParts(shield)
	shield:PivotTo(startCF)        -- place before it enters the world (no flash)
	shield.Parent = workspace
	riseTo(shield, startCF, targetCF)

	-- Shield-open sound, positional at the shield, the moment it starts rising.
	EventHub.ShieldOpenEvent:Fire(character, side, shield)

	return { shield = shield }
end

-- Idempotent: safe to call from any cleanup path (animation done, character
-- removed, or Debris timeout). Nils the reference so repeat calls no-op.
local function teardownShield(shieldInfo)
	if not shieldInfo or not shieldInfo.shield then return end
	shieldInfo.shield:Destroy()
	shieldInfo.shield = nil
end

function DeflectAction.perform(character, chairSystem, side)
	local shieldInfo = setupShield(character, side)
	if not shieldInfo then return end

	-- The shield lives in workspace, independent of the character, so it does NOT
	-- die with the bot. This module runs on the CLIENT while the bot is destroyed
	-- by the SERVER, so neither the deflect animation's Stopped event nor the
	-- character's Destroying event reliably fire here -- both leak the shield when
	-- the bot is despawned (e.g. it wins the round, player dies). The signals that
	-- DO fire client-side for a replicated removal are AncestryChanged (parent
	-- becomes nil) and, as a guaranteed catch-all, a Debris timeout.
	local conn
	local function cleanup()
		if conn then conn:Disconnect(); conn = nil end
		teardownShield(shieldInfo)
	end

	-- Primary: bot character removed from the world -> kill the shield now.
	conn = character.AncestryChanged:Connect(function(_, parent)
		if not parent then cleanup() end
	end)

	-- Backstop: shield can never outlive this no matter what happens.
	Debris:AddItem(shieldInfo.shield, SHIELD_MAX_LIFETIME)

	-- Fast/happy path: animation finished normally.
	DuelEffectUtils.playAnimation(character, DEFLECT_ANIM_ID, "DeflectAction", cleanup)
end

return DeflectAction
