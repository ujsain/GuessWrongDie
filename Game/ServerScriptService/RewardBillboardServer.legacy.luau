--[[
	RewardBillboardServer
	- Sets the table's single RewardBillboard text from the ChairSystem's RewardCoins IntValue.
	- Hides the billboard while a match is on (both seats occupied), shows it again
	  when a seat frees up.
	Self-contained: reads only the scene, touches no other script.
]]

local function formatMoney(n)
	local s = tostring(math.floor(n))
	local k
	repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return "$" .. s
end

-- the single billboard now lives on table > RewardAnchor > RewardBillboard
local function getBillboard(cs)
	local tbl = cs:FindFirstChild("table")
	local anchor = tbl and tbl:FindFirstChild("RewardAnchor")
	return anchor and anchor:FindFirstChild("RewardBillboard")
end

local function refreshText(cs, rv)
	local bb = getBillboard(cs)
	local amount = bb and bb:FindFirstChild("Amount")
	if amount then amount.Text = formatMoney(rv.Value) end
end

local function setupTable(cs)
	local rv = cs:FindFirstChild("RewardCoins")
	if not rv then return end

	local leftSeat  = cs.LeftChair  and cs.LeftChair:FindFirstChild("Seat")
	local rightSeat = cs.RightChair and cs.RightChair:FindFirstChild("Seat")
	if not leftSeat or not rightSeat then return end

	local function updateVisibility()
		local bb = getBillboard(cs)
		if not bb then return end
		local matchOn = (leftSeat.Occupant ~= nil) and (rightSeat.Occupant ~= nil)
		bb.Enabled = not matchOn
	end

	refreshText(cs, rv)
	updateVisibility()

	rv:GetPropertyChangedSignal("Value"):Connect(function() refreshText(cs, rv) end)
	leftSeat:GetPropertyChangedSignal("Occupant"):Connect(updateVisibility)
	rightSeat:GetPropertyChangedSignal("Occupant"):Connect(updateVisibility)
end

for _, cs in ipairs(workspace:GetDescendants()) do
	if cs.Name == "ChairSystem" and cs:IsA("Folder") then
		setupTable(cs)
	end
end
