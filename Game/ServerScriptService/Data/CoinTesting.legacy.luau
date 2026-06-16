-- TestAddCoins (DELETE BEFORE PUBLISHING)
-- Adds 5000 coins to every player who joins, after their profile loads.
-- NOTE: No wait() at the top — must connect BEFORE DataManager.Init() fires
-- ProfileReady or the event is missed entirely.

--
local ServerScriptService = game:GetService("ServerScriptService")
local DataManager = require(ServerScriptService.Data.DataManager)
local CoinService = require(ServerScriptService.Data.CoinService)

-- ProfileReady only passes (player) — profile is NOT passed through
-- BindableEvents due to cyclic table serialisation errors.
DataManager.ProfileReady:Connect(function(player)
	CoinService.Add(player, 5000, "TestGrant", true)
	print("[TestAddCoins] Gave 5000 coins to", player.Name,
		"| New balance:", CoinService.GetBalance(player))
end)

--]]