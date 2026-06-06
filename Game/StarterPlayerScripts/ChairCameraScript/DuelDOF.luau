local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local DuelDOF = {}

local activeDOF = nil
local fadeInTween = nil
local fadeOutTween = nil
local keepAliveConnection = nil

local SETTINGS = {
	FocusDistance = 10,
	InFocusRadius = 3,
	FarIntensity = 1,
	NearIntensity = 0.5,
	FadeTime = 0.5,
}

function DuelDOF.enable(camera, chairCameraPart, tableCenterPart)
	if fadeOutTween then fadeOutTween:Cancel() fadeOutTween = nil end
	if fadeInTween then fadeInTween:Cancel() fadeInTween = nil end
	if activeDOF then activeDOF:Destroy() activeDOF = nil end
	if keepAliveConnection then keepAliveConnection:Disconnect() keepAliveConnection = nil end

	local focusDist = SETTINGS.FocusDistance
	if chairCameraPart and tableCenterPart then
		focusDist = (chairCameraPart.Position - tableCenterPart.Position).Magnitude
	end

	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "DuelDepthOfField"
	dof.FocusDistance = focusDist
	dof.InFocusRadius = SETTINGS.InFocusRadius
	dof.FarIntensity = 0
	dof.NearIntensity = 0
	dof.Parent = camera
	activeDOF = dof

	fadeInTween = TweenService:Create(dof, TweenInfo.new(SETTINGS.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FarIntensity = SETTINGS.FarIntensity,
		NearIntensity = SETTINGS.NearIntensity,
	})
	fadeInTween:Play()

	-- Keep-alive: periodically touch the DOF so the engine doesn't deactivate it
	keepAliveConnection = RunService.Heartbeat:Connect(function()
		if activeDOF and activeDOF.Parent then
			-- Read a property to keep the instance active in the renderer
			local _ = activeDOF.FarIntensity
		end
	end)
end

function DuelDOF.disable()
	if fadeInTween then fadeInTween:Cancel() fadeInTween = nil end
	if fadeOutTween then fadeOutTween:Cancel() fadeOutTween = nil end
	if keepAliveConnection then keepAliveConnection:Disconnect() keepAliveConnection = nil end

	if not activeDOF then return end

	local dof = activeDOF
	activeDOF = nil

	fadeOutTween = TweenService:Create(dof, TweenInfo.new(SETTINGS.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		FarIntensity = 0,
		NearIntensity = 0,
	})
	fadeOutTween:Play()
	fadeOutTween.Completed:Connect(function()
		dof:Destroy()
		fadeOutTween = nil
	end)
end

return DuelDOF
