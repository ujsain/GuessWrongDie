--[[
	ChairArrowFinder (LocalScript)
	Shows a ground arrow/beam pointing the local player to the NEAREST EMPTY chair
	whenever they are NOT seated. Hides it when seated or when no empty chair exists.

	- Read-only against the world (only reads Seat.Occupant + positions).
	- Tables are found by the "ChairSystem" CollectionService tag, so tables that
	  spawn/despawn at runtime are picked up automatically (list is rebuilt per scan).
	- Drawing is delegated to the sibling "Arrow" module, which auto-tracks both
	  endpoints every RenderStepped, so we only (re)start it when the target changes.
]]

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Arrow = require(script.Parent:WaitForChild("Arrow"))

local CHAIR_SYSTEM_TAG = "ChairSystem"
local SCAN_INTERVAL    = 0.3   -- seconds between nearest-chair re-evaluations

local player = Players.LocalPlayer

-- current character refs (refreshed on respawn)
local humanoid      = nil
local rootPart      = nil
local currentTarget = nil      -- the Seat we are currently pointing at

----------------------------------------------------------------
-- SEAT DISCOVERY (by tag)
----------------------------------------------------------------
local function gatherSeats(systemFolder, out)
	for _, chairName in ipairs({ "LeftChair", "RightChair" }) do
		local chair = systemFolder:FindFirstChild(chairName)
		if chair then
			local seat = chair:FindFirstChild("Seat")
			if seat and seat:IsA("Seat") then
				table.insert(out, seat)
			end
		end
	end
end

-- Every chair Seat across all tagged ChairSystem tables. Rebuilt each scan,
-- so tables added/removed at runtime are handled with no extra bookkeeping.
local function collectSeats()
	local seats = {}
	for _, systemFolder in ipairs(CollectionService:GetTagged(CHAIR_SYSTEM_TAG)) do
		if systemFolder:IsDescendantOf(workspace) then
			gatherSeats(systemFolder, seats)
		end
	end
	return seats
end

----------------------------------------------------------------
-- NEAREST EMPTY CHAIR
----------------------------------------------------------------
local function findNearestEmptySeat()
	if not rootPart then return nil end
	local origin = rootPart.Position
	local best, bestDist = nil, math.huge
	for _, seat in ipairs(collectSeats()) do
		if seat.Occupant == nil then
			local d = (seat.Position - origin).Magnitude
			if d < bestDist then
				best, bestDist = seat, d
			end
		end
	end
	return best
end

----------------------------------------------------------------
-- ARROW DRIVING
----------------------------------------------------------------
local function stopArrow()
	currentTarget = nil
	Arrow.Stop()
end

local function isSeated()
	return humanoid ~= nil and humanoid.Sit
end

local function refresh()
	-- No valid character, or we are seated -> no arrow.
	if not rootPart or not humanoid or isSeated() then
		if currentTarget ~= nil then stopArrow() end
		return
	end

	local target = findNearestEmptySeat()
	if target then
		-- Only (re)start when the target seat actually changes; the Arrow module
		-- auto-tracks both endpoints every RenderStepped on its own.
		if target ~= currentTarget then
			currentTarget = target
			Arrow.Start(rootPart, target)
		end
	else
		if currentTarget ~= nil then stopArrow() end
	end
end

----------------------------------------------------------------
-- CHARACTER SETUP
----------------------------------------------------------------
local function onCharacter(character)
	stopArrow()
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")

	-- Instant response when sitting down / standing up (don't wait for the loop).
	humanoid.Seated:Connect(function()
		refresh()
	end)

	humanoid.Died:Connect(function()
		stopArrow()
	end)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

player.CharacterRemoving:Connect(function()
	humanoid, rootPart = nil, nil
	stopArrow()
end)

----------------------------------------------------------------
-- MAIN LOOP (throttled)
----------------------------------------------------------------
task.spawn(function()
	while true do
		refresh()
		task.wait(SCAN_INTERVAL)
	end
end)
