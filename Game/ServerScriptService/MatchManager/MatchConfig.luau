--[[
	MatchConfig
	All match tuning constants in one place (data only). The single source of
	truth for MAX_HEALTH on the server -- MatchState reads it from here, so a
	balance change happens in exactly one spot.
]]

return {
	COUNTDOWN         = 5,
	CHOICE_TIME       = 10,
	RESOLVE_DELAY     = 3,
	DEATH_DELAY       = 1.2,
	GAMEOVER_HOLD     = 3,     -- seconds the result screen holds before respawn/cleanup
	SEAT_SETTLE_DELAY = 0.5,   -- let the client Seated event process before countdown
	COIN_REWARD_DELAY = 0.45,  -- short beat before paying coins (lets the win screen show)

	DEFAULT_CHOICE = "None",
	MAX_HEALTH     = 3,
	DEFLECT_COOLDOWN_ROUNDS = 1,  -- rounds a side's Deflect is locked after it deflects

	BOTS_ENABLED  = false,  -- master switch for bot opponents (PvP still works either way)
	BOT_GRACE     = 4,      -- seconds a lone human waits before a bot fills the chair
	BOT_THINK_MIN = 1,
	BOT_THINK_MAX = 3,
}
