--[[
	DataManager (ServerScriptService.Data.DataManager)

	Single owner of the ProfileStore session lifecycle.
	  - Loads / reconciles / ends profiles
	  - Pushes initial attributes to the Player instance
	  - Exposes GetProfile(player) for other services (e.g. CoinService)
	  - Fires ProfileReady so services can react to new players
]]--

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Libraries.ProfileStore)
local Template     = require(ServerScriptService.Data.Template)

local DataManager = {}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local Profiles: { [Player]: any } = {}

-- BindableEvent so other services can react when a profile is ready.
local ProfileReadyEvent = Instance.new("BindableEvent")
DataManager.ProfileReady = ProfileReadyEvent.Event  -- :Connect(function(player) end)

--------------------------------------------------------------------------------
-- Store
--------------------------------------------------------------------------------
local function GetStoreName(): string
	return RunService:IsStudio() and "Test" or "Live"
end

local PlayerStore = ProfileStore.New(GetStoreName(), Template)

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Push saved fields onto the Player as attributes so clients can read them.
local function PushAttributes(player: Player, data)
	player:SetAttribute("Coins", data.Coins)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Return the live profile for a player, or nil.
function DataManager.GetProfile(player: Player)
	return Profiles[player]
end

--------------------------------------------------------------------------------
-- Lifecycle (called once from DataInit)
--------------------------------------------------------------------------------
function DataManager.Init()
	local function PlayerAdded(player: Player)
		local profile = PlayerStore:StartSessionAsync("Player_" .. player.UserId, {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		if profile ~= nil then
			print("[DataManager] Profile loaded for", player.Name)
			profile:AddUserId(player.UserId)
			profile:Reconcile()

			profile.OnSessionEnd:Connect(function()
				Profiles[player] = nil
				player:Kick("Data error occurred. Please rejoin.")
			end)

			if player.Parent == Players then
				Profiles[player] = profile
				PushAttributes(player, profile.Data)
				ProfileReadyEvent:Fire(player)
			else
				profile:EndSession()
			end
		else
			player:Kick("Data error occurred. Please rejoin.")
		end
	end

	for _, player in Players:GetPlayers() do
		task.spawn(PlayerAdded, player)
	end
	Players.PlayerAdded:Connect(PlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		local profile = Profiles[player]
		if not profile then return end
		profile:EndSession()
		Profiles[player] = nil
	end)
end

return DataManager
