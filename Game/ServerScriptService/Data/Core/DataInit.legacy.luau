--[[
	DataInit (ServerScriptService.Data.DataInit)

	Thin bootstrap. Requires the data services and kicks off their Init()s.
	No business logic lives here.

	Order matters:
	  1. CoinService.Init()        — registers the coin remote
	  2. GunPurchaseService.Init()
ShieldPurchaseService.Init() — registers the shop remote + ProfileReady listener
	  3. DataManager.Init()        — starts profile sessions, fires ProfileReady
]]--

local ServerScriptService = game:GetService("ServerScriptService")

local DataManager        = require(ServerScriptService.Data:FindFirstChild("DataManager", true))
local CoinService        = require(ServerScriptService.Data:FindFirstChild("CoinService", true))
local GunPurchaseService = require(ServerScriptService.Data:FindFirstChild("GunPurchaseService", true))
local ShieldPurchaseService = require(ServerScriptService.Data:FindFirstChild("ShieldPurchaseService", true))
local PurchaseService       = require(ServerScriptService.Data:FindFirstChild("PurchaseService", true))
local MatchTracker       = require(ServerScriptService.Analytics.MatchTracker)
local LeaderboardService = require(ServerScriptService.LeaderboardService)

-- 1. Services register their listeners before profiles start loading.
CoinService.Init()
GunPurchaseService.Init()
ShieldPurchaseService.Init()
PurchaseService.SetProfileGetter(DataManager.GetProfile)  -- inject data layer
PurchaseService.Init()   -- single MarketplaceService.ProcessReceipt; grants registered above
MatchTracker.Init()   -- own analytics DataStore; independent of the profile lifecycle
LeaderboardService.Init() -- starts the wins board (render loop); wins come via LeaderboardService.AddWin

-- 2. Now start the profile lifecycle (fires ProfileReady per player).
DataManager.Init()
