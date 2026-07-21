--[[
	Template (ServerScriptService.Data.Template)

	Default profile data. New players start with these values; existing
	players pick up any newly-added fields via profile:Reconcile() in DataManager.
]]--

return {
	-- Currency
	Coins = 0,

	-- Lifetime stats (mirrored to the "MatchesWon" attribute
	-- for clients, and to the global wins OrderedDataStore)
	MatchesWon = 0,

	-- Robux developer-product idempotency: PurchaseIds already granted
	-- (capped FIFO list; see Data.Services.PurchaseService)
	PurchaseIdCache = {},
}
