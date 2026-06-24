--[[
	WinsBoardStore (ServerScriptService.Analytics.WinsBoardStore)

	OrderedDataStore wrapper for the GLOBAL "Matches Won" board.
	Separate from ProfileStore: the profile holds each player's authoritative
	MatchesWon total; this store is only the sortable, cross-server index that
	GetSortedAsync ranks for the top-N list.

	OrderedDataStore is required because a normal DataStore / ProfileStore can't
	be queried for "top 10". Its values must be integers -- win counts are.

	API:
	  WinsBoardStore.Set(userId, total)  -- mirror a player's authoritative total (yields)
	  WinsBoardStore.GetTop(limit)       -- { {userId=, wins=}, ... } highest first (yields)
]]

local DataStoreService = game:GetService("DataStoreService")

local STORE_NAME  = "DuelWins_v1"   -- never rename: old keys would ghost into results
local MAX_RETRIES = 3

local WinsBoardStore = {}

local store
local storeOk = pcall(function()
	store = DataStoreService:GetOrderedDataStore(STORE_NAME)
end)
if not storeOk then
	warn("[WinsBoardStore] OrderedDataStore unavailable (Studio API access off?) -- board stays empty")
end

function WinsBoardStore.IsAvailable()
	return storeOk
end

--- Mirror a player's authoritative win total into the sortable store.
function WinsBoardStore.Set(userId, total)
	if not storeOk then return false end
	if typeof(total) ~= "number" or total ~= math.floor(total) or total < 0 then
		return false
	end
	local key = tostring(userId)
	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(function()
			store:SetAsync(key, total)
		end)
		if ok then return true end
		warn(("[WinsBoardStore] Set failed (%d/%d): %s"):format(attempt, MAX_RETRIES, tostring(err)))
		task.wait(2 ^ attempt)
	end
	return false
end

--- Top `limit` players by wins, highest first.
function WinsBoardStore.GetTop(limit)
	if not storeOk then return {} end
	limit = math.clamp(limit or 10, 1, 100)

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, limit)   -- false = descending
	end)
	if not ok or not pages then
		warn("[WinsBoardStore] GetTop failed:", pages)
		return {}
	end

	local result = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(result, { userId = userId, wins = entry.value })
		end
	end
	return result
end

return WinsBoardStore
