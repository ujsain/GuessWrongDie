--[[
	CoinService  (server — ServerScriptService.Data.CoinService)

	Simple coin logic — add / spend / balance, server-side validation,
	and the server end of CoinRemote (client spend requests).

	Earn / spend from any server script:
	    local CoinService = require(ServerScriptService.Data.CoinService)
	    CoinService.Add(player, 50, "Reward")
	    CoinService.Spend(player, 50, "ShopItem")
	    CoinService.GetBalance(player)
]]--

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local DataManager = require(ServerScriptService.Data.DataManager)
local EventHub    = require(ReplicatedStorage:WaitForChild("EventHub"))

local CoinService = {}

local MAX_COINS = 1000000000   -- hard ceiling on a balance

--------------------------------------------------------------------------------
-- Raw data mutations. Profile (ProfileStore) is the source of truth; the
-- "Coins" attribute is just the replicated mirror clients read.
--------------------------------------------------------------------------------
local function getProfile(player: Player)
	return DataManager.GetProfile(player)
end

--- Current balance, or 0 if no profile.
function CoinService.GetBalance(player: Player): number
	local profile = getProfile(player)
	if not profile then return 0 end
	return profile.Data.Coins
end

local function addCoins(player: Player, amount: number): number?
	local profile = getProfile(player)
	if not profile then return nil end
	if typeof(amount) ~= "number" then return nil end
	if amount ~= amount then return nil end          -- NaN
	if amount <= 0 then return nil end
	if amount ~= math.floor(amount) then return nil end

	local newBalance = math.min(profile.Data.Coins + amount, MAX_COINS)
	profile.Data.Coins = newBalance
	player:SetAttribute("Coins", newBalance)
	return newBalance
end

local function removeCoins(player: Player, amount: number): number?
	local profile = getProfile(player)
	if not profile then return nil end
	if typeof(amount) ~= "number" then return nil end
	if amount ~= amount then return nil end
	if amount <= 0 then return nil end
	if amount ~= math.floor(amount) then return nil end
	if profile.Data.Coins < amount then return nil end

	local newBalance = profile.Data.Coins - amount
	profile.Data.Coins = newBalance
	player:SetAttribute("Coins", newBalance)
	return newBalance
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Add coins. Pass silent = true to skip the client toast notification.
function CoinService.Add(player: Player, amount: number, reason: string, silent: boolean?): number?
	local newBalance = addCoins(player, amount)
	if not newBalance then return nil end
	if not silent then
		EventHub.CoinRemote:FireClient(player, amount, reason, newBalance)
	end
	return newBalance
end

--- Spend coins. Returns new balance or nil if the player can't afford it.
function CoinService.Spend(player: Player, amount: number, reason: string): number?
	local newBalance = removeCoins(player, amount)
	if not newBalance then return nil end
	EventHub.CoinRemote:FireClient(player, -amount, reason, newBalance)
	return newBalance
end

--------------------------------------------------------------------------------
-- Wiring (called once from DataInit)
--------------------------------------------------------------------------------
function CoinService.Init()
	EventHub.CoinRemote.OnServerEvent:Connect(function(player, action, ...)
		if typeof(action) ~= "string" then return end

		if action == "spend" then
			local amount, itemId = ...
			if typeof(amount) ~= "number" then return end
			if typeof(itemId) ~= "string" then return end
			CoinService.Spend(player, amount, itemId)
		end
	end)
end

return CoinService
