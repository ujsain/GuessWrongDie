local Arrow = {}

local BEAM_CONFIG = {
	Texture = 'rbxassetid://16848361091',
	TextureSpeed = 4,
	TextureLength = 2,
	TextureMode = Enum.TextureMode.Wrap,
	Width0 = 3,
	Width1 = 4,
	LightEmission = 0.75,
	FaceCamera = true,
	Segments = 10,
	Brightness = 1,
	Color = ColorSequence.new(Color3.fromRGB(235, 212, 128)),
	Transparency = NumberSequence.new(0),
}

-- How far above the ground the beam floats (tweak this!)
local GROUND_Y_OFFSET = 1.5

local _beam = nil
local _att0 = nil
local _att1 = nil
local _connection = nil
local _originRef = nil
local _targetRef = nil

local RunService = game:GetService('RunService')

local function CreateBeam()
	local beam = Instance.new('Beam')
	for prop, value in BEAM_CONFIG do
		beam[prop] = value
	end
	beam.Enabled = false
	beam.Parent = workspace
	return beam
end

local function GetPosition(source)
	if typeof(source) == 'Vector3' then
		return source
	elseif typeof(source) == 'Instance' then
		if source:IsA('BasePart') then
			return source.Position
		elseif source:IsA('Model') and source.PrimaryPart then
			return source.PrimaryPart.Position
		elseif source:IsA('Attachment') then
			return source.WorldPosition
		end
	end
	return nil
end

local function UpdatePositions()
	if not _att0 or not _att1 or not _beam then return end
	local originPos = GetPosition(_originRef)
	local targetPos = GetPosition(_targetRef)
	if originPos and targetPos then
		-- Offset origin down to foot level if tracking a character
		if typeof(_originRef) == 'Instance' and _originRef:IsA('BasePart') then
			local character = _originRef.Parent
			if character then
				local humanoid = character:FindFirstChildOfClass('Humanoid')
				if humanoid then
					local footDrop = humanoid.HipHeight + _originRef.Size.Y * 0.5
					originPos = originPos - Vector3.new(0, footDrop, 0)
				end
			end
		end

		-- Flatten both points to the same Y (ground level) so beam lies flat
		local groundY = originPos.Y + GROUND_Y_OFFSET
		_att0.WorldPosition = Vector3.new(originPos.X, groundY, originPos.Z)
		_att1.WorldPosition = Vector3.new(targetPos.X, groundY, targetPos.Z)
		_beam.Enabled = true
	else
		_beam.Enabled = false
	end
end

function Arrow.Start(origin, target)
	Arrow.Stop()
	_originRef = origin
	_targetRef = target
	_att0 = Instance.new('Attachment')
	_att0.Parent = workspace.Terrain
	_att1 = Instance.new('Attachment')
	_att1.Parent = workspace.Terrain
	_beam = CreateBeam()
	_beam.Attachment0 = _att0
	_beam.Attachment1 = _att1
	UpdatePositions()
	if typeof(origin) == 'Instance' or typeof(target) == 'Instance' then
		_connection = RunService.RenderStepped:Connect(UpdatePositions)
	end
end

function Arrow.Stop()
	if _connection then
		_connection:Disconnect()
		_connection = nil
	end
	if _beam then
		_beam:Destroy()
		_beam = nil
	end
	if _att0 then
		_att0:Destroy()
		_att0 = nil
	end
	if _att1 then
		_att1:Destroy()
		_att1 = nil
	end
	_originRef = nil
	_targetRef = nil
end

return Arrow
