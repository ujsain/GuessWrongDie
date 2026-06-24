--[[
	MatchLogStore (ServerScriptService.Analytics.MatchLogStore)

	Buffered DataStore wrapper for per-match analytics rows.
	Completely separate from ProfileStore -- own DataStore ("MatchLogs_v1"),
	own keys ("log_<userId>"). Never touches player profiles.

	(Adapted from the SkyDiving JumpLogStore: the Append/Flush/Get/Wipe
	engine is unchanged; only the store name and Print() formatting differ.)

	API:
	  MatchLogStore.Append(userId, entry)  -- buffer an entry (no yield)
	  MatchLogStore.Flush(userId)          -- write buffer to DataStore (yields)
	  MatchLogStore.FlushAll()
	  MatchLogStore.Get(userId)            -- saved + still-buffered entries
	  MatchLogStore.Print(userId)          -- formatted table + summary in the output
	  MatchLogStore.Wipe(userId)           -- delete one player's log
]]

local DataStoreService = game:GetService("DataStoreService")

local STORE_NAME  = "MatchLogs_v1"
local KEY_PREFIX  = "log_"
local MAX_ENTRIES = 500      -- per player, oldest trimmed first
local MAX_RETRIES = 3

local MatchLogStore = {}

local store
local storeOk = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not storeOk then
	warn("[MatchLogStore] DataStore unavailable (Studio API access off?) -- entries stay in memory only")
end

local buffers: { [number]: { any } } = {}

local function key(userId: number): string
	return KEY_PREFIX .. tostring(userId)
end

function MatchLogStore.Append(userId: number, entry)
	local buf = buffers[userId]
	if not buf then
		buf = {}
		buffers[userId] = buf
	end
	table.insert(buf, entry)
end

function MatchLogStore.Flush(userId: number): boolean
	local buf = buffers[userId]
	if not buf or #buf == 0 then return true end
	if not storeOk then return false end

	local toWrite = buf
	buffers[userId] = {}

	for attempt = 1, MAX_RETRIES do
		local ok, err = pcall(function()
			store:UpdateAsync(key(userId), function(old)
				old = old or {}
				for _, e in ipairs(toWrite) do
					table.insert(old, e)
				end
				while #old > MAX_ENTRIES do
					table.remove(old, 1)
				end
				return old
			end)
		end)
		if ok then return true end
		warn(("[MatchLogStore] Flush failed (attempt %d/%d): %s"):format(attempt, MAX_RETRIES, tostring(err)))
		task.wait(2 ^ attempt)
	end

	-- All retries failed: re-queue at the front so nothing is lost while the server lives.
	local cur = buffers[userId] or {}
	for i = #toWrite, 1, -1 do
		table.insert(cur, 1, toWrite[i])
	end
	buffers[userId] = cur
	return false
end

function MatchLogStore.FlushAll()
	for userId in pairs(buffers) do
		MatchLogStore.Flush(userId)
	end
end

function MatchLogStore.Get(userId: number): { any }
	local saved = {}
	if storeOk then
		local ok, result = pcall(function()
			return store:GetAsync(key(userId))
		end)
		if ok and typeof(result) == "table" then
			saved = result
		end
	end
	for _, e in ipairs(buffers[userId] or {}) do
		table.insert(saved, e)
	end
	return saved
end

function MatchLogStore.Wipe(userId: number)
	buffers[userId] = nil
	if storeOk then
		pcall(function()
			store:RemoveAsync(key(userId))
		end)
	end
end

--- DEV ONLY. Permanently deletes EVERY player's match log in this store.
--- Returns how many keys were removed. There is no undo.
function MatchLogStore.WipeAll(): number
	table.clear(buffers)
	if not storeOk then return 0 end
	local removed = 0
	local ok, err = pcall(function()
		local pages = store:ListKeysAsync(KEY_PREFIX)
		while true do
			for _, k in ipairs(pages:GetCurrentPage()) do
				pcall(function() store:RemoveAsync(k.KeyName) end)
				removed += 1
			end
			if pages.IsFinished then break end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then warn("[MatchLogStore] WipeAll failed:", err) end
	return removed
end

--- DEV ONLY. Prints EVERY player's log + summary to the Output window and
--- returns the player count. Does one GetAsync per player (plus paginated key
--- listing), so it's a dev/debug tool -- don't call it on a hot path.
--- Covers both persisted players and any still buffered in this live server.
function MatchLogStore.PrintAll(): number
	local seen = {}
	-- players whose rows are still buffered in THIS server (not yet flushed)
	for userId in pairs(buffers) do seen[userId] = true end
	-- players with data persisted in the store
	if storeOk then
		local ok, err = pcall(function()
			local pages = store:ListKeysAsync(KEY_PREFIX)
			while true do
				for _, k in ipairs(pages:GetCurrentPage()) do
					local id = tonumber(k.KeyName:match("^" .. KEY_PREFIX .. "(.+)$"))
					if id then seen[id] = true end
				end
				if pages.IsFinished then break end
				pages:AdvanceToNextPageAsync()
			end
		end)
		if not ok then warn("[MatchLogStore] PrintAll list failed:", err) end
	end

	local count = 0
	for userId in pairs(seen) do
		count += 1
		MatchLogStore.Print(userId)
	end
	print(("=== PrintAll: %d player(s) ==="):format(count))
	return count
end

--------------------------------------------------------------------------------
-- Per-player read-back. This is the "track down one player" view: every match
-- they played, plus a derived summary answering matches-played / W-L-D /
-- aborts / average duration / longest single-session streak.
--------------------------------------------------------------------------------
function MatchLogStore.Print(userId: number)
	local entries = MatchLogStore.Get(userId)
	local wins, losses, draws, aborts = 0, 0, 0, 0
	local durSum, durN = 0, 0
	local bestSession = 0

	print(("=== MatchLog %d -- %d entries ==="):format(userId, #entries))
	print("Match# | Outcome | Duration | Table | Opponent | When (UTC)")
	for _, e in ipairs(entries) do
		local dur = (typeof(e.duration) == "number") and string.format("%.1fs", e.duration) or "-"
		print(("%s | %s | %s | %s | %s | %s"):format(
			tostring(e.matchNo or "?"),
			tostring(e.outcome or "?"),
			dur,
			tostring(e.tableId or "?"),
			tostring(e.opponent or "?"),
			os.date("!%Y-%m-%d %H:%M", e.t or 0)))

		if e.outcome == "Win" then wins += 1
		elseif e.outcome == "Loss" then losses += 1
		elseif e.outcome == "Draw" then draws += 1
		elseif e.outcome == "Abort" then aborts += 1 end

		if typeof(e.duration) == "number" then
			durSum += e.duration
			durN += 1
		end
		if typeof(e.matchNo) == "number" and e.matchNo > bestSession then
			bestSession = e.matchNo
		end
	end

	local played = wins + losses + draws
	local avg = (durN > 0) and (durSum / durN) or 0
	print(("--- SUMMARY  played=%d  W=%d L=%d D=%d  aborted=%d  avgDuration=%.1fs  longestSession=%d matches ---")
		:format(played, wins, losses, draws, aborts, avg, bestSession))
end

return MatchLogStore