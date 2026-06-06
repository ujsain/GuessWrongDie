--[[
	Template (ServerScriptService.Data.Template)

	Default profile data. New players start with these values; existing
	players pick up any newly-added fields via profile:Reconcile() in DataManager.
]]--

return {
	-- Currency
	Coins = 0,
}
