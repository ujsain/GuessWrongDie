--[[
	DataInit (ServerScriptService.Data.DataInit)

	Thin bootstrap. Requires the data services and kicks off their Init()s.
	No business logic lives here.

	Order matters:
	  1. CoinService.Init()  — registers its remote + ProfileReady-independent setup
	  2. DataManager.Init()  — starts profile sessions, fires ProfileReady
]]--

local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService.Data.DataManager)
local CoinService = require(ServerScriptService.Data.CoinService)

-- 1. Services register their listeners before profiles start loading.
CoinService.Init()

-- 2. Now start the profile lifecycle (fires ProfileReady per player).
DataManager.Init()
