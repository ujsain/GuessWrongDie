local DuelEffectUtils = require(script.Parent:WaitForChild("DuelEffectUtils"))
local EventHub        = require(game:GetService("ReplicatedStorage"):WaitForChild("EventHub"))
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DeflectAction = {}
local DEFLECT_ANIM_ID = "rbxassetid://117607954022155"
local SHIELD_OFFSET = Vector3.new(0, 1, -3)
local RISE_DISTANCE = 3
local RISE_TIME = 1
-- Hard ceiling on how long a shield may exist. The deflect action visually
-- completes well within the round's resolve window, so this only ever fires
-- as a safety net if every other cleanup path fails.
local SHIELD_MAX_LIFETIME = 8

local function setupShield(character, side)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local shieldTemplate = RS:WaitForChild("Shields"):WaitForChild("Shield")
	local shield = shieldTemplate:Clone()

	if shield:IsA("BasePart") then
		shield.Anchored = true
		shield.CanCollide = false

		local targetPos = (rootPart.CFrame * CFrame.new(SHIELD_OFFSET)).Position
		local startPos = targetPos - Vector3.new(0, RISE_DISTANCE, 0)
		local yAngle = (side == "Left") and math.rad(90) or math.rad(-90)
		local rot = CFrame.Angles(0, yAngle, 0)

		shield.CFrame = CFrame.new(startPos) * rot
		shield.Orientation = Vector3.new(0, (side == "Left") and 90 or -90, 0)

		shield.Parent = workspace

		local tween = TweenService:Create(shield, TweenInfo.new(RISE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(targetPos) * rot
			-- orientation maintained by CFrame tween
		})
		tween:Play()

		-- Shield-open sound, positional at the shield, the moment it starts rising.
		EventHub.ShieldOpenEvent:Fire(character, side, shield)
	else
		shield.Parent = workspace
		EventHub.ShieldOpenEvent:Fire(character, side, shield)
	end

	for _, part in ipairs(shield:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

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
