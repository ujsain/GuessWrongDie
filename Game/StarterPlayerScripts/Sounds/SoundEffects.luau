local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")

local SoundEffects = {}

local container = Instance.new("Folder")
container.Name = "SFX_Container"
container.Parent = SoundService

-- One resident, preloaded Sound per id, kept alive so the audio asset stays
-- in memory. One-shots are played by cloning the resident (instant, no load
-- hitch); loops play on the resident itself so Stop() can control them.
local residents: { [string]: Sound } = {}

local function isValidId(id: string): boolean
	-- A valid Roblox asset id is digits only. Placeholder strings like
	-- "RING_SHINE_SOUND_ID" or an empty/nil id are rejected.
	return type(id) == "string" and id:match("^%d+$") ~= nil
end

-- Get (or lazily create) the resident sound for an id.
local function getResident(id: string): Sound
	local existing = residents[id]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = id
	sound.SoundId = "rbxassetid://" .. id
	sound.Parent = container
	residents[id] = sound
	return sound
end

--- Warm a list of ids once at startup. Creates the resident instances and
--- preloads their assets, then KEEPS them alive so later plays are instant.
function SoundEffects.Preload(ids: { string })
	local toLoad = {}
	for _, id in ipairs(ids) do
		if isValidId(id) then
			table.insert(toLoad, getResident(id))
		end
	end
	if #toLoad > 0 then
		ContentProvider:PreloadAsync(toLoad)
	end
end

function SoundEffects.Play(id: string, options: {loop: boolean?, volume: number?}?): Sound?
	if not isValidId(id) then
		warn("[SoundEffects] Skipped invalid sound id: " .. tostring(id))
		return nil
	end

	local opts = options or {}
	local resident = getResident(id)

	if opts.loop == true then
		-- Looping sounds (gliding, falling, music) play on the resident
		-- instance directly so Stop(id) can find and control them.
		resident.Looped = true
		resident.Volume = opts.volume or 0.5
		if not resident.IsPlaying then
			resident:Play()
		end
		return resident
	end

	-- One-shot: clone the already-resident sound and play the copy. The asset
	-- is shared with the live resident, so it's in memory and plays with no
	-- delay; cloning also lets rapid bursts (coins) overlap cleanly.
	local sound = resident:Clone()
	sound.Looped = false
	sound.Volume = opts.volume or 0.5
	sound.Parent = container
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, 30)
	sound:Play()
	return sound
end

--- Positional one-shot. `emitter` may be a BasePart (sound emits from it),
--- a Model (uses PrimaryPart / HumanoidRootPart), or a Vector3 world position
--- (a tiny invisible holder part is spawned and cleaned up). Anything else
--- falls back to a flat 2D play so a sound is never silently lost.
--- options: { volume: number?, rollOff: number? }
function SoundEffects.PlayAt(id: string, emitter, options): Sound?
	if not isValidId(id) then
		warn("[SoundEffects] Skipped invalid sound id: " .. tostring(id))
		return nil
	end

	local opts = options or {}

	-- Resolve the emitter to a part or a position.
	local emitterPart: BasePart? = nil
	local emitterPos: Vector3? = nil
	if typeof(emitter) == "Vector3" then
		emitterPos = emitter
	elseif typeof(emitter) == "Instance" then
		if emitter:IsA("BasePart") then
			emitterPart = emitter
		elseif emitter:IsA("Model") then
			emitterPart = emitter.PrimaryPart or emitter:FindFirstChild("HumanoidRootPart")
		end
	end

	if not emitterPart and not emitterPos then
		-- Couldn't place it in the world: don't lose the sound, play flat.
		return SoundEffects.Play(id, { volume = opts.volume })
	end

	local resident = getResident(id)
	local sound = resident:Clone()
	sound.Looped = false
	sound.Volume = opts.volume or 0.5
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = opts.rollOff or 80

	local holder: Part? = nil
	if emitterPart then
		sound.Parent = emitterPart
	else
		holder = Instance.new("Part")
		holder.Name = "SFX_Emitter"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CastShadow = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Position = emitterPos
		holder.Parent = workspace
		sound.Parent = holder
	end

	local lifetime = (sound.TimeLength > 0 and sound.TimeLength or 6) + 0.5
	sound.Ended:Connect(function()
		sound:Destroy()
		if holder then holder:Destroy() end
	end)
	Debris:AddItem(sound, lifetime)
	if holder then Debris:AddItem(holder, lifetime + 0.1) end

	sound:Play()
	return sound
end

function SoundEffects.Stop(id: string)
	if not isValidId(id) then return end
	local fullId = "rbxassetid://" .. id

	-- Stop the resident loop but keep it alive for reuse.
	local resident = residents[id]
	if resident and resident.IsPlaying then
		resident:Stop()
	end

	-- Stop and clean up any one-shot clones of this id.
	for _, sound in container:GetChildren() do
		if sound:IsA("Sound") and sound ~= resident and sound.SoundId == fullId then
			sound:Stop()
			sound:Destroy()
		end
	end
end

function SoundEffects.StopAll()
	for _, sound in container:GetChildren() do
		if sound:IsA("Sound") then
			sound:Stop()
			-- Destroy one-shot clones; keep resident instances alive.
			if residents[sound.Name] ~= sound then
				sound:Destroy()
			end
		end
	end
end

return SoundEffects
