local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local DuelDOF = require(script:WaitForChild("DuelDOF"))

local TWEEN_TIME = 0.8
local tweenInfo = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local isSitting = false
local currentConnection = nil

local dummyPart = Instance.new("Part")
dummyPart.Anchored = true
dummyPart.CanCollide = false
dummyPart.Transparency = 1
dummyPart.Parent = workspace

local function findChairCamera(seat)
	local parent = seat.Parent
	while parent and parent ~= workspace do
		local cam = parent:FindFirstChild("ChairCamera")
		if cam then
			return cam, parent
		end
		parent = parent.Parent
	end
	return nil, nil
end

local function findTableCenter(chairSystem)
	-- Try to find the table model or use midpoint between chairs
	local table_ = chairSystem:FindFirstChild("table") or chairSystem:FindFirstChild("Table") or chairSystem:FindFirstChild("TableModel")
	if table_ then
		if table_:IsA("BasePart") then return table_ end
		local primary = table_.PrimaryPart or table_:FindFirstChildWhichIsA("BasePart")
		if primary then return primary end
	end
	-- Fallback: use the ChairCamera itself (DOF will use default distance)
	return nil
end

local function cleanup()
	isSitting = false
	if currentConnection then
		currentConnection:Disconnect()
		currentConnection = nil
	end
	camera.CameraType = Enum.CameraType.Custom
	DuelDOF.disable()
end

local function onSeated(active, seat)
	if active and seat then
		local targetCam, chairSystem = findChairCamera(seat)
		if not targetCam then return end

		isSitting = true
		camera.CameraType = Enum.CameraType.Scriptable
		dummyPart.CFrame = camera.CFrame

		-- Enable DOF
		local tableCenter = findTableCenter(chairSystem)
		DuelDOF.enable(camera, targetCam, tableCenter)

		local tween = TweenService:Create(dummyPart, tweenInfo, {
			CFrame = targetCam.CFrame
		})

		if currentConnection then currentConnection:Disconnect() end
		currentConnection = RunService.RenderStepped:Connect(function()
			if isSitting then
				camera.CFrame = dummyPart.CFrame
			end
		end)

		tween:Play()
		tween.Completed:Connect(function()
			if currentConnection then currentConnection:Disconnect() end
			if isSitting then
				currentConnection = RunService.RenderStepped:Connect(function()
					if isSitting then
						camera.CFrame = targetCam.CFrame
					else
						cleanup()
					end
				end)
			end
		end)

	elseif not active and isSitting then
		cleanup()
	end
end

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(onSeated)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
