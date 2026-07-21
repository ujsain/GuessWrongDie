--[[
	LeaderboardService (ServerScriptService.LeaderboardService)

	Self-contained global "Matches Won" board. INDEPENDENT of MatchTracker /
	MatchLogStore -- shares no data with the analytics layer.

	Server-only. No events, no client script:
	  * MatchManager calls LeaderboardService.AddWin(winner) directly the moment
	    a human wins a duel.
	  * AddWin: +1 to that player's MatchesWon in their profile, mirror it to the
	    Player attribute, write the new total to WinsBoardStore.
	  * On a timer (and ~3s after each win) reads the top N and draws the rows
	    straight onto the SurfaceGui on the wall. That GUI sits on a Part in
	    Workspace, so server-built rows replicate to every client for free.

	Profile = source of truth. OrderedDataStore = sortable mirror.
	Attribute = client-readable mirror. All set from the same number.
]]

local Players             = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")

local DataManager    = require(ServerScriptService.Data:FindFirstChild("DataManager", true))
local WinsBoardStore = require(ServerScriptService.Analytics.WinsBoardStore)

local TOP_N            = 10
local REFRESH_INTERVAL = 60
local POST_WIN_DELAY   = 3
local ROW_PREFIX       = "LBRow_"

local LeaderboardService = {}

local nameCache = {}
local refreshQueued = false
local scroll, template

--------------------------------------------------------------------------------
local function resolveName(userId)
	local cached = nameCache[userId]
	if cached then return cached end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	name = (ok and name) or ("User_" .. userId)
	nameCache[userId] = name
	return name
end

local function clearRows()
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame")
			and (child.Name:sub(1, #ROW_PREFIX) == ROW_PREFIX or child.Name:match("^FakeRow")) then
			child:Destroy()
		end
	end
end

local function makeRow(order, rankText, nameText, amountText, userId)
	local row = template:Clone()
	row.Name = ROW_PREFIX .. order
	row.LayoutOrder = order
	row.Visible = true
	row.Rank.Text = rankText
	row.PlrName.Text = nameText
	row.Amount.Text = amountText
	if userId then
		row.PlayerIcon.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(userId)
		row.PlayerIcon.Visible = true
	else
		row.PlayerIcon.Visible = false
	end
	row.Parent = scroll
	return row
end

local function render()
	if not scroll or not template then return end
	clearRows()

	local top = WinsBoardStore.GetTop(TOP_N)
	if #top == 0 then
		local row = makeRow(1, "", "No duels won yet -- be the first!", "", nil)
		row.Rank.Visible = false
		row.Amount.Visible = false
		row.PlrName.TextXAlignment = Enum.TextXAlignment.Center
		row.PlrName.Size = UDim2.fromScale(0.9, 0.55)
		row.PlrName.Position = UDim2.fromScale(0.05, 0.5)
		return
	end

	for rank, entry in ipairs(top) do
		makeRow(rank, "#" .. rank, resolveName(entry.userId), tostring(entry.wins), entry.userId)
	end
end

local function queueRefresh()
	if refreshQueued then return end
	refreshQueued = true
	task.delay(POST_WIN_DELAY, function()
		refreshQueued = false
		render()
	end)
end

--------------------------------------------------------------------------------
-- Called directly by MatchManager when a human wins. Bots/nil are ignored.
function LeaderboardService.AddWin(winner)
	if typeof(winner) ~= "Instance" or not winner:IsA("Player") then return end
	local profile = DataManager.GetProfile(winner)
	if not profile then return end

	local newTotal = (profile.Data.MatchesWon or 0) + 1
	profile.Data.MatchesWon = newTotal
	winner:SetAttribute("MatchesWon", newTotal)

	task.spawn(function()
		WinsBoardStore.Set(winner.UserId, newTotal)
		queueRefresh()
	end)
end

--------------------------------------------------------------------------------
function LeaderboardService.Init()
	local board = Workspace:WaitForChild("Map"):WaitForChild("InGameSystems"):WaitForChild("Leaderboard")
	scroll   = board.SurfaceGui.MainFrame.Players.Scroll
	template = board:FindFirstChild("Template")

	task.spawn(function()
		render()
		while true do
			task.wait(REFRESH_INTERVAL)
			render()
		end
	end)

	print("[LeaderboardService] Ready (server-rendered, direct AddWin)")
end

return LeaderboardService
