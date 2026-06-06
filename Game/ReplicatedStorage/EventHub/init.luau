--[[
	EventHub (ReplicatedStorage)
	Central registry of all game events. Every event is a PHYSICAL child of
	this module (under RemoteEvents / LocalEvents), exposed here so callers do:
	    local EventHub = require(ReplicatedStorage.EventHub)
	    EventHub.SubmitChoice:FireServer(tableId, choice)

	Adding an event: create the RemoteEvent / BindableEvent as a child of the
	matching folder, then expose it with one line below.
]]

local EventHub = {}

local RemoteEvents = script:WaitForChild("RemoteEvents")
local LocalEvents  = script:WaitForChild("LocalEvents")

-- === RemoteEvents (client <-> server) ===

-- Coins: bidirectional.
--   Server -> client: (amount, reason, newBalance)
--   Client -> server: ("spend", amount, itemId)
EventHub.CoinRemote = RemoteEvents:WaitForChild("CoinRemote")

-- Duel / match flow.
EventHub.StartCountdown   = RemoteEvents:WaitForChild("StartCountdown")    -- server -> client: (tableId, seconds)
EventHub.StartChoicePhase = RemoteEvents:WaitForChild("StartChoicePhase")  -- server -> client: (tableId, timer)
EventHub.SubmitChoice     = RemoteEvents:WaitForChild("SubmitChoice")      -- client -> server: (tableId, choice)
EventHub.RoundResult      = RemoteEvents:WaitForChild("RoundResult")       -- server -> client: (tableId, myChoice, oppChoice, myHP, myBul, oppHP, oppBul)
EventHub.GameOver         = RemoteEvents:WaitForChild("GameOver")          -- server -> client: (tableId, winnerId, reason)

-- === LocalEvents (client-only BindableEvents) ===
-- These are CLIENT-LOCAL signals fired from the duel effect modules at the
-- exact moment each thing happens on screen. They never touch the server, so
-- only the local player (one of the two duelists) reacts to them. The sound
-- layer is the first listener; any future client system (camera shake, hit
-- markers, analytics) can subscribe to the same signals without touching the
-- effect code. Names describe WHAT happened, not what any one listener does.
EventHub.ShootEvent           = LocalEvents:WaitForChild("ShootEvent")            -- (character, side, muzzleTip)  - a gun fired
EventHub.ReloadEvent          = LocalEvents:WaitForChild("ReloadEvent")           -- (character, side, gunPart)    - a reload happened
EventHub.ShieldOpenEvent      = LocalEvents:WaitForChild("ShieldOpenEvent")       -- (character, side, shield)     - a deflect shield rose
EventHub.BulletReflectedEvent = LocalEvents:WaitForChild("BulletReflectedEvent")  -- (position)                    - a bullet hit a shield and bounced
EventHub.BulletHitEvent       = LocalEvents:WaitForChild("BulletHitEvent")        -- (position)                    - a bullet hit a player
EventHub.BulletsCollideEvent  = LocalEvents:WaitForChild("BulletsCollideEvent")   -- (position)                    - two bullets met mid-air

return EventHub
