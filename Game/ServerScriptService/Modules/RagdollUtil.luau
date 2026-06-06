--[[
	RagdollUtil
	Shared: turns a character's Motor6D joints into BallSocketConstraints
	so it can flop. Used by both player ragdoll (RagdollEffect) and bot
	ragdoll (BotManager).
]]
local RagdollUtil = {}

function RagdollUtil.applyConstraints(character)
	for _, v in pairs(character:GetDescendants()) do
		if v:IsA("Motor6D") and v.Name ~= "RootJoint" then
			local a0 = Instance.new("Attachment")
			a0.CFrame = v.C0
			a0.Name = "RagdollAtt0"
			a0.Parent = v.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = v.C1
			a1.Name = "RagdollAtt1"
			a1.Parent = v.Part1
			local ball = Instance.new("BallSocketConstraint")
			ball.Attachment0 = a0
			ball.Attachment1 = a1
			ball.LimitsEnabled = true
			ball.TwistLimitsEnabled = true
			ball.UpperAngle = 45
			ball.TwistLowerAngle = -45
			ball.TwistUpperAngle = 45
			ball.Name = "RagdollConstraint"
			ball.Parent = v.Part0
			v.Enabled = false
		end
	end
end

return RagdollUtil
