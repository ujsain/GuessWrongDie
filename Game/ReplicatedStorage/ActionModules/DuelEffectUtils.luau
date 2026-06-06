local DuelEffectUtils = {}

function DuelEffectUtils.setupGun(character, chairSystem, side)
	local pistolName = side .. "Pistol"
	local pistol = chairSystem:FindFirstChild(pistolName)
	if not pistol then return nil end

	local mainPart = pistol:FindFirstChild("Main")
	local cframeVal = pistol:FindFirstChild("CFrameValue")
	if not mainPart or not cframeVal then return nil end

	local rightHand = character:FindFirstChild("RightHand")
	if not rightHand then return nil end

	local savedParts = {}
	for _, part in ipairs(pistol:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(savedParts, {part = part, anchored = part.Anchored, cframe = part.CFrame})
			part.Anchored = false
		end
	end

	local motor = Instance.new("Motor6D")
	motor.Name = "Main"
	motor.Part0 = rightHand
	motor.Part1 = mainPart
	motor.C0 = cframeVal.Value
	motor.Parent = rightHand

	return {
		motor = motor,
		savedParts = savedParts,
	}
end

function DuelEffectUtils.teardownGun(gunInfo)
	if not gunInfo then return end
	if gunInfo.motor then gunInfo.motor:Destroy() end
	if gunInfo.savedParts then
		for _, info in ipairs(gunInfo.savedParts) do
			info.part.Anchored = info.anchored
			info.part.CFrame = info.cframe
		end
	end
end

function DuelEffectUtils.playAnimation(character, animId, label, onFinished, speed)
	if animId == "" then
		if onFinished then onFinished() end
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then if onFinished then onFinished() end return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then if onFinished then onFinished() end return end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false
	track:Play(0.2)
	track:AdjustSpeed(speed or 0.4)

	anim:Destroy()

	track.Stopped:Once(function()
		track:Destroy()
		if onFinished then onFinished() end
	end)

	return track
end

return DuelEffectUtils
