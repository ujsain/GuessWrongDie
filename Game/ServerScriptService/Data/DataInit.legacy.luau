--[[
	DataInit (ServerScriptService.Data.DataInit)

	Thin bootstrap. Requires the data services and kicks off their Init()s.
	No business logic lives here.

	Order matters:
	  1. CoinService.Init()        — registers the coin remote
	  2. GunPurchaseService.Init() — registers the shop remote + ProfileReady listener
	  3. DataManager.Init()        — starts profile sessions, fires ProfileReady
]]--

local ServerScriptService = game:GetService("ServerScriptService")

local DataManager        = require(ServerScriptService.Data.DataManager)
local CoinService        = require(ServerScriptService.Data.CoinService)
local GunPurchaseService = require(ServerScriptService.Data.GunPurchaseService)

-- 1. Services register their listeners before profiles start loading.
CoinService.Init()
GunPurchaseService.Init()

-- 2. Now start the profile lifecycle (fires ProfileReady per player).
DataManager.Init()
