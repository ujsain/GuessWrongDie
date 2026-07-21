--[[
	ShieldPurchaseService (server — ServerScriptService.Data.Services.ShieldPurchaseService)

	Sibling of GunPurchaseService, for DEFLECT SHIELDS (cosmetic). Same pricing
	model (free / cash / robux via ShopGUI.Pricing + Prices.Shields). Robux items
	are granted by PurchaseService from ProcessReceipt and refused over the cash
	path.

	EventHub.ShieldRemote: Client ("buy"/"equip"/"requestState"); Server ("owned"/"buyFailed").
	Equipped shield is mirrored to the REPLICATED attribute "EquippedShield",
	which DeflectAction (client) reads at deflect-time. No server-side selection
	record (no GunSelection equivalent) — the client spawns the shield.
]]--

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local StarterGui          = game:GetService("StarterGui")

local DataManager     = require(ServerScriptService.Data:FindFirstChild("DataManager", true))
local CoinService     = require(ServerScriptService.Data:FindFirstChild("CoinService", true))
local PurchaseService = require(ServerScriptService.Data:FindFirstChild("PurchaseService", true))
local EventHub        = require(ReplicatedStorage:WaitForChild("EventHub"))
local Prices          = require(StarterGui:WaitForChild("ShopGUI"):WaitForChild("Prices")).Shields
local Pricing         = require(StarterGui:WaitForChild("ShopGUI"):WaitForChild("Pricing"))

local SHIELDS = ReplicatedStorage:WaitForChild("Shields")
local DEFAULT = "MarvelShield"   -- keep in sync with DeflectAction.DEFAULT_SHIELD

local ShieldPurchaseService = {}

local function shieldExists(name)
	return type(name) == "string" and SHIELDS:FindFirstChild(name) ~= nil
end

local function ensureState(profile)
	if type(profile.Data.OwnedShields) ~= "table" then
		profile.Data.OwnedShields = {}
	end
	if type(profile.Data.EquippedShield) ~= "string" then
		profile.Data.EquippedShield = DEFAULT
	end

	local owned = profile.Data.OwnedShields
	owned[DEFAULT] = true                            -- default always owned
	for _, shield in ipairs(SHIELDS:GetChildren()) do
		if Pricing.isFree(Prices[shield.Name]) then  -- free shields auto-owned
			owned[shield.Name] = true
		end
	end

	if not owned[profile.Data.EquippedShield] then   -- equipped must be owned
		profile.Data.EquippedShield = DEFAULT
	end
end

local function pushOwned(player, profile)
	EventHub.ShieldRemote:FireClient(player, "owned", profile.Data.OwnedShields)
end

local function applyEquipped(player, profile)
	player:SetAttribute("EquippedShield", profile.Data.EquippedShield)
end

local function syncPlayer(player)
	local profile = DataManager.GetProfile(player)
	if not profile then return end
	ensureState(profile)
	applyEquipped(player, profile)
	pushOwned(player, profile)
end

local function grantOwnership(player, profile, name)
	ensureState(profile)
	profile.Data.OwnedShields[name] = true
	pushOwned(player, profile)
end

local function doBuy(player, name)
	if not shieldExists(name) then return end
	local profile = DataManager.GetProfile(player)
	if not profile then return end
	ensureState(profile)

	if profile.Data.OwnedShields[name] then return end   -- already owned

	local entry = Prices[name]

	if Pricing.isRobux(entry) then
		EventHub.ShieldRemote:FireClient(player, "buyFailed", name)
		return
	end

	local price = Pricing.cashPrice(entry)
	if price > 0 then
		local newBalance = CoinService.Spend(player, price, name)
		if not newBalance then
			EventHub.ShieldRemote:FireClient(player, "buyFailed", name)
			return
		end
	end

	grantOwnership(player, profile, name)
end

local function doEquip(player, name)
	if not shieldExists(name) then return end
	local profile = DataManager.GetProfile(player)
	if not profile then return end
	ensureState(profile)

	if not profile.Data.OwnedShields[name] then return end   -- must own it
	if profile.Data.EquippedShield == name then return end

	profile.Data.EquippedShield = name
	applyEquipped(player, profile)
end

local function registerProducts()
	for name, entry in pairs(Prices) do
		local productId = Pricing.productId(entry)
		if productId then
			PurchaseService.RegisterProduct(productId, function(player, profile)
				grantOwnership(player, profile, name)
			end)
		end
	end
end

function ShieldPurchaseService.Init()
	registerProducts()

	DataManager.ProfileReady:Connect(syncPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		if DataManager.GetProfile(player) then
			syncPlayer(player)
		end
	end

	EventHub.ShieldRemote.OnServerEvent:Connect(function(player, action, name)
		if type(action) ~= "string" then return end
		if action == "buy" then
			doBuy(player, name)
		elseif action == "equip" then
			doEquip(player, name)
		elseif action == "requestState" then
			syncPlayer(player)
		end
	end)
end

return ShieldPurchaseService
