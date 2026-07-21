--[[
	GunPurchaseService (server — ServerScriptService.Data.Services.GunPurchaseService)

	Owns buying + equipping guns. Ownership / equipped state lives on profile.Data
	(ProfileStore persists it), initialised lazily.

	Pricing comes from StarterGui.ShopGUI.Prices.Guns, interpreted by ShopGUI.Pricing:
	  • free  (0 / absent)   -> auto-owned
	  • cash  (number > 0)   -> bought with coins via the ShopRemote "buy" path
	  • robux ({ productId }) -> bought with Robux: the client prompts the Developer
	    Product and PurchaseService grants ownership from ProcessReceipt. Robux
	    items are REFUSED over the cash path so they can't be taken for free.

	EventHub.ShopRemote: Client ("buy"/"equip"/"requestState"); Server ("owned"/"buyFailed").
	Equipped gun is mirrored to the player attribute "EquippedGun".
]]--

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local StarterGui          = game:GetService("StarterGui")

local DataManager     = require(ServerScriptService.Data:FindFirstChild("DataManager", true))
local CoinService     = require(ServerScriptService.Data:FindFirstChild("CoinService", true))
local GunSelection    = require(ServerScriptService.Data:FindFirstChild("GunSelection", true))
local PurchaseService = require(ServerScriptService.Data:FindFirstChild("PurchaseService", true))
local EventHub        = require(ReplicatedStorage:WaitForChild("EventHub"))
local Prices          = require(StarterGui:WaitForChild("ShopGUI"):WaitForChild("Prices")).Guns
local Pricing         = require(StarterGui:WaitForChild("ShopGUI"):WaitForChild("Pricing"))

local PISTOLS = ReplicatedStorage:WaitForChild("Pistols")
local DEFAULT = GunSelection.DEFAULT

local GunPurchaseService = {}

local function gunExists(name)
	return type(name) == "string" and PISTOLS:FindFirstChild(name) ~= nil
end

--------------------------------------------------------------------------------
-- Profile-backed state
--------------------------------------------------------------------------------
local function ensureState(profile)
	if type(profile.Data.OwnedGuns) ~= "table" then
		profile.Data.OwnedGuns = {}
	end
	if type(profile.Data.EquippedGun) ~= "string" then
		profile.Data.EquippedGun = DEFAULT
	end

	local owned = profile.Data.OwnedGuns
	owned[DEFAULT] = true                            -- default gun always owned
	for _, gun in ipairs(PISTOLS:GetChildren()) do
		if Pricing.isFree(Prices[gun.Name]) then     -- free guns auto-owned
			owned[gun.Name] = true
		end
	end

	if not owned[profile.Data.EquippedGun] then      -- equipped must be owned
		profile.Data.EquippedGun = DEFAULT
	end
end

local function pushOwned(player, profile)
	EventHub.ShopRemote:FireClient(player, "owned", profile.Data.OwnedGuns)
end

local function applyEquipped(player, profile)
	player:SetAttribute("EquippedGun", profile.Data.EquippedGun)
	GunSelection.set(player, profile.Data.EquippedGun)
end

local function syncPlayer(player)
	local profile = DataManager.GetProfile(player)
	if not profile then return end
	ensureState(profile)
	applyEquipped(player, profile)
	pushOwned(player, profile)
end

--- Mark a gun owned + tell the client. Shared by the cash path and the Robux
--- ProcessReceipt grant. Idempotent: re-granting an owned gun is harmless.
local function grantOwnership(player, profile, name)
	ensureState(profile)
	profile.Data.OwnedGuns[name] = true
	pushOwned(player, profile)
end

--------------------------------------------------------------------------------
-- Requests (ShopRemote — cash / free only)
--------------------------------------------------------------------------------
local function doBuy(player, name)
	if not gunExists(name) then return end
	local profile = DataManager.GetProfile(player)
	if not profile then return end
	ensureState(profile)

	if profile.Data.OwnedGuns[name] then return end      -- already owned

	local entry = Prices[name]

	-- Robux items must go through PromptProductPurchase -> ProcessReceipt;
	-- never grant them over the cash path.
	if Pricing.isRobux(entry) then
		EventHub.ShopRemote:FireClient(player, "buyFailed", name)
		return
	end

	local price = Pricing.cashPrice(entry)
	if price > 0 then
		local newBalance = CoinService.Spend(player, price, name)
		if not newBalance then                            -- couldn't afford
			EventHub.ShopRemote:FireClient(player, "buyFailed", name)
			return
		end
	end

	grantOwnership(player, profile, name)
end

local function doEquip(player, name)
	if not gunExists(name) then return end
	local profile = DataManager.GetProfile(player)
	if not profile then return end
	ensureState(profile)

	if not profile.Data.OwnedGuns[name] then return end   -- must own it
	if profile.Data.EquippedGun == name then return end

	profile.Data.EquippedGun = name
	applyEquipped(player, profile)
end

--------------------------------------------------------------------------------
-- Register this category's Robux Developer Products with the central router.
-- Items with a 0 / missing productId (placeholder) are skipped automatically.
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- Lifecycle (call from DataInit BEFORE DataManager.Init)
--------------------------------------------------------------------------------
function GunPurchaseService.Init()
	registerProducts()

	DataManager.ProfileReady:Connect(syncPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		if DataManager.GetProfile(player) then
			syncPlayer(player)
		end
	end

	EventHub.ShopRemote.OnServerEvent:Connect(function(player, action, name)
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

return GunPurchaseService
