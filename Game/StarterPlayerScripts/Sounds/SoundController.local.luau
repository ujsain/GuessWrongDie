--[[
	SoundController (LocalScript)
	The duel sound brain. Plays the world SFX (fired by the duel effect
	modules), the countdown tick, and the background music -- all locally for
	THIS player.

	WHY ONLY THE TWO DUELISTS HEAR THE SFX:
	  - World SFX events are BindableEvents (client-only), fired from effect
	    modules that only run on the two seated players' clients.
	  - The countdown remote is only sent by the server to those two players.
	  (Background music is just a local loop, so every player hears their own.)
	  Nothing here ever reaches the wider server.

	TO SWAP IN REAL SOUNDS:
	  Put a real rbxassetid (digits only) in each IDS slot. An empty string or
	  placeholder is skipped with a one-time warn -- nothing breaks.
]]

local SoundEffects = require(script.Parent:WaitForChild("SoundEffects"))
local EventHub      = require(game:GetService("ReplicatedStorage"):WaitForChild("EventHub"))

-- === Sound asset ids ===
local IDS = {
	Shoot           = "8234107515",       -- gun fire
	Reload          = "135598971191489",  -- magazine insert / rack
	ShieldOpen      = "101501890099447",  -- shield whoosh / deploy
	Ricochet        = "107195426020897",  -- bullet hits shield + bounces
	Hit             = "74863189381790",   -- bullet hits a player
	Collide         = "103436259617153",  -- two slugs clink mid-air
	CLOCKTICK       = "78771986232064",                  -- TODO: countdown tick (plays on 5-4-3-2-1)
	GO              = "136011056790730",                                 -- TODO: "GO!" blast (plays once when the countdown ends)
	BACKGROUNDMUSIC = "89244151580650",                  -- TODO: looping background music
	WinSound        = "80792697745051",  -- TODO: match-win stinger  (digits-only rbxassetid)
	LoseSound       = "83342116842175",  -- TODO: match-lose stinger (digits-only rbxassetid)
}

-- Per-sound volume (tune to taste).
local VOL = {
	Shoot           = 0.6,
	Reload          = 0.5,
	ShieldOpen      = 0.55,
	Ricochet        = 0.5,
	Hit             = 0.65,
	Collide         = 0.55,
	CLOCKTICK       = 0.5,
	GO              = 0.7,   -- a touch louder than the ticks for punch
	BACKGROUNDMUSIC = 0.5,   -- keep low so it sits under the SFX
	WinSound        = 1.5,
	LoseSound       = 1.5,
}

local ROLLOFF = 80  -- studs; how far each positional (world) sound carries

-- Warm + keep resident instances so plays are instant.
task.spawn(function()
	local list = {}
	for _, id in pairs(IDS) do
		table.insert(list, id)
	end
	SoundEffects.Preload(list)
end)

-- Positional play, for the world SFX (located at a part / position).
local function playAt(name: string, emitter)
	SoundEffects.PlayAt(IDS[name], emitter, { volume = VOL[name], rollOff = ROLLOFF })
end

-------------------------------------------------------
-- BACKGROUND MUSIC: always on, looping, from game start.
-------------------------------------------------------
if IDS.BACKGROUNDMUSIC ~= "" then
	SoundEffects.Play(IDS.BACKGROUNDMUSIC, { loop = true, volume = VOL.BACKGROUNDMUSIC })
end

-------------------------------------------------------
-- WORLD SFX (fired from the duel effect modules)
-------------------------------------------------------

-- Gun fired (all modes: straight / deflected / collide).
EventHub.ShootEvent.Event:Connect(function(_character, _side, muzzleTip)
	playAt("Shoot", muzzleTip)
end)

-- Reload (magazine insert beat).
EventHub.ReloadEvent.Event:Connect(function(character, _side, gunPart)
	playAt("Reload", gunPart or character)
end)

-- Deflect shield rose.
EventHub.ShieldOpenEvent.Event:Connect(function(character, _side, shield)
	playAt("ShieldOpen", shield or character)
end)

-- Bullet hit a shield and bounced back.
EventHub.BulletReflectedEvent.Event:Connect(function(position)
	playAt("Ricochet", position)
end)

-- Bullet hit a player.
EventHub.BulletHitEvent.Event:Connect(function(position)
	playAt("Hit", position)
end)

-- Two bullets met mid-air. Both slugs fire this at near-identical points, so
-- debounce to a single clink.
local COLLIDE_COOLDOWN = 0.12
local lastCollide = 0
EventHub.BulletsCollideEvent.Event:Connect(function(position)
	local now = os.clock()
	if now - lastCollide < COLLIDE_COOLDOWN then
		return
	end
	lastCollide = now
	playAt("Collide", position)
end)

-------------------------------------------------------
-- COUNTDOWN TICK (rides the 5-4-3-2-1 match-start countdown).
-- Flat / 2D and local. Receiving StartCountdown means it's MY match.
-------------------------------------------------------
local countdownToken = 0
EventHub.StartCountdown.OnClientEvent:Connect(function(_tableId, seconds)
	countdownToken += 1
	local myToken = countdownToken
	task.spawn(function()
		for _ = 1, (seconds or 0) do
			if myToken ~= countdownToken then return end   -- a newer countdown took over
			SoundEffects.Play(IDS.CLOCKTICK, { volume = VOL.CLOCKTICK })
			task.wait(1)
		end
		-- The final wait above lands exactly on the "GO!" beat (DuelClient shows
		-- it at the same moment), so the blast plays in sync with the text.
		if myToken ~= countdownToken then return end
		SoundEffects.Play(IDS.GO, { volume = VOL.GO })
	end)
end)

-------------------------------------------------------
-- MATCH RESULT (win / lose / draw stinger -- THIS player only).
-- Fired by DuelClient the moment the result screen shows. The GameOver remote
-- behind it is sent only to the two duelists, and this signal is client-local,
-- so each player hears only their OWN result. Flat/2D one-shot (it's a UI
-- stinger, not a world sound). An empty id is skipped silently.
-------------------------------------------------------
EventHub.MatchResultEvent.Event:Connect(function(outcome)
	local id = IDS[outcome .. "Sound"]
	if id and id ~= "" then
		SoundEffects.Play(id, { volume = VOL[outcome .. "Sound"] })
	end
end)
