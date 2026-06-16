--[[
	GunPurchaseService (server — ServerScriptService.Data.GunPurchaseService)

	Owns buying + equipping guns. Self-contained: it never modifies DataManager
	or Template. Ownership / equipped state is stored directly on profile.Data
	(ProfileStore persists it automatically) and initialised lazily.

	The catalogue IS ReplicatedStorage.Pistols:
	  gun.Name                = item id (unique)
	  Dependencies.Price      = cost (IntValue); <= 0 means free / auto-owned
	  Dependencies.ImageLabel = card art (read by the client)

	EventHub.ShopRemote protocol:
	  Client -> server : ("buy", gunName) / ("equip", gunName) / ("requestState")
	  Server -> client : ("owned", ownedSet)
	Equipped gun is also mirrored to the player attribute "EquippedGun".
]]--

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local DataManager  = require(ServerScriptService.Data.DataManager)
local CoinService  = require(ServerScriptService.Data.CoinService)
local GunSelection = require(ServerScriptService.Modules.GunSelection)
local EventHub     = require(ReplicatedStorage:WaitForChild("EventHub"))

local PISTOLS = ReplicatedStorage:WaitForChild("Pistols")
local DEFAULT = GunSelection.DEFAULT

local GunPurchaseService = {}

--------------------------------------------------------------------------------
-- Catalogue helpers (read straight off the gun models)
--------------------------------------------------------------------------------
local function gunExists(name)
	return type(name) == "string" and PISTOLS:FindFirstChild(name) ~= nil
end

local function priceOf(name)
	local gun  = PISTOLS:FindFirstChild(name)
	local deps = gun and gun:FindFirstChild("Dependencies")
	local p    = deps and deps:FindFirstChild("Price")
	if p and (p:IsA("IntValue") or p:IsA("NumberValue")) then
		return p.Value
	end
	return 0
end

--------------------------------------------------------------------------------
-- Profile-backed state (no Template / DataManager changes needed)
--------------------------------------------------------------------------------
local function ensureState(profile)
	if type(profile.Data.OwnedGuns) ~= "table" then
		profile.Data.OwnedGuns = {}
	end
	if type(profile.Data.EquippedGun) ~= "string" then
		profile.Data.EquippedGun = DEFAULT
	end

	local owned = profile.Data.OwnedGuns
	owned[DEFAULT] = true                        -- default gun always owned
	for _, gun in ipairs(PISTOLS:GetChildren()) do
		if priceOf(gun.Name) <= 0 then           -- free guns auto-owned
			owned[gun.Name] = true
		end
	end

	if not owned[profile.Data.EquippedGun] then  -- equipped must be owned
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

--------------------------------------------------------------------------------
-- Requests
--------------------------------------------------------------------------------
local function doBuy(player, gunName)
	if not gunExists(gunName) then return end
	local profile = DataManager.GetProfile(player)
	if not profile then return end
	ensureState(profile)

	if profile.Data.OwnedGuns[gunName] then return end   -- already owned

	local price = priceOf(gunName)
	if price > 0 then
		local newBalance = CoinService.Spend(player, price, gunName)
		if not newBalance then                            -- couldn't afford
			EventHub.ShopRemote:FireClient(player, "buyFailed", gunName)
			return
		end
	end

	profile.Data.OwnedGuns[gunName] = true
	pushOwned(player, profile)
end

local function doEquip(player, gunName)
	if not gunExists(gunName) then return end
	local profile = DataManager.GetProfile(player)
	if not profile then return end
	ensureState(profile)

	if not profile.Data.OwnedGuns[gunName] then return end   -- must own it
	if profile.Data.EquippedGun == gunName then return end

	profile.Data.EquippedGun = gunName
	applyEquipped(player, profile)
end

--------------------------------------------------------------------------------
-- Lifecycle (call from DataInit BEFORE DataManager.Init so the ProfileReady
-- listener is connected before any profile loads)
--------------------------------------------------------------------------------
function GunPurchaseService.Init()
	DataManager.ProfileReady:Connect(syncPlayer)

	-- safety net: any profile already ready before we connected
	for _, player in ipairs(Players:GetPlayers()) do
		if DataManager.GetProfile(player) then
			syncPlayer(player)
		end
	end

	EventHub.ShopRemote.OnServerEvent:Connect(function(player, action, gunName)
		if type(action) ~= "string" then return end
		if action == "buy" then
			doBuy(player, gunName)
		elseif action == "equip" then
			doEquip(player, gunName)
		elseif action == "requestState" then
			syncPlayer(player)
		end
	end)
end

return GunPurchaseService
