local DuelEffectUtils = require(script.Parent:WaitForChild("DuelEffectUtils"))
local EventHub        = require(game:GetService("ReplicatedStorage"):WaitForChild("EventHub"))
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DeflectAction = {}
local DEFLECT_ANIM_ID = "rbxassetid://117607954022155"
local SHIELD_OFFSET = Vector3.new(0, 1, -3)
local RISE_DISTANCE = 3
local RISE_TIME = 1

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

local function teardownShield(shieldInfo)
	if not shieldInfo then return end
	if shieldInfo.shield then shieldInfo.shield:Destroy() end
end

function DeflectAction.perform(character, chairSystem, side)
	local shieldInfo = setupShield(character, side)

	DuelEffectUtils.playAnimation(character, DEFLECT_ANIM_ID, "DeflectAction", function()
		teardownShield(shieldInfo)
	end)
end

return DeflectAction
