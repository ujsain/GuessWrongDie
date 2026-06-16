--[[
	DuelClient (LocalScript)
	Thin controller: wires remote events to modules.
]]

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local DuelUI         = require(RS:WaitForChild("DuelUI"))
local DuelModules    = script.Parent:WaitForChild("DuelModules")
local ChairUtils     = require(DuelModules:WaitForChild("ChairUtils"))
local DamageVisuals  = require(DuelModules:WaitForChild("DamageVisuals"))
local RoundAnimator  = require(DuelModules:WaitForChild("RoundAnimator"))

local EventHub          = require(RS:WaitForChild("EventHub"))
local StartCountdown   = EventHub.StartCountdown
local StartChoicePhase = EventHub.StartChoicePhase
local SubmitChoice     = EventHub.SubmitChoice
local RoundResult      = EventHub.RoundResult
local GameOverRemote   = EventHub.GameOver
local RequestBot       = EventHub.RequestBot

local MAX_HP = 3

local ui = DuelUI.new()
ui:hide()
ui:hideChoices()

-- Match state
local myTableId = nil
local myBullets = 0
local myPrevHP = MAX_HP
local oppPrevHP = MAX_HP
local choiceTimerThread = nil
local matchActive = false

-------------------------------------------------------
-- Lower buttons (Leave / Play With AI)
-- Visible only while seated and NOT in an active match.
-------------------------------------------------------
local playerGui    = player:WaitForChild("PlayerGui")
local inGameUI     = playerGui:WaitForChild("InGameUI")
local lowerButtons = inGameUI:WaitForChild("LowerButtons")
local leaveBtn     = lowerButtons:WaitForChild("Leave")
local playAIBtn    = lowerButtons:WaitForChild("PlayWithAI")
lowerButtons.Visible = false

local function isSeated()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.SeatPart ~= nil
end

local function showLowerButtons()
	if matchActive then return end
	if not isSeated() then return end
	lowerButtons.Visible = true
end

local function hideLowerButtons()
	lowerButtons.Visible = false
end

-- Play With AI: ask the server to drop a bot into the empty seat.
local aiDebounce = false
playAIBtn.MouseButton1Click:Connect(function()
	if matchActive or not myTableId or not isSeated() then return end
	if aiDebounce then return end
	aiDebounce = true
	RequestBot:FireServer()
	task.delay(2, function() aiDebounce = false end)
end)

-- Leave: stand up from the chair (same effect as pressing Space). Waiting only.
leaveBtn.MouseButton1Click:Connect(function()
	if matchActive then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Sit = false end
end)

-------------------------------------------------------
-- Helpers
-------------------------------------------------------
local function lockSeat()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.JumpPower = 0
		hum.WalkSpeed = 0
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end

local function unlockSeat()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.JumpPower = 50
		hum.WalkSpeed = 16
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end

local function stopTimer()
	if choiceTimerThread then
		task.cancel(choiceTimerThread)
		choiceTimerThread = nil
	end
end

-------------------------------------------------------
-- UI confirm callback
-------------------------------------------------------
ui.onConfirm = function(choice)
	if myTableId then
		SubmitChoice:FireServer(myTableId, choice)
	end
	stopTimer()
end

-------------------------------------------------------
-- Seated handler
-------------------------------------------------------
local function onSeated(active, seat)
	if active and seat then
		local chairSystem = ChairUtils.getChairSystem(seat)
		if not chairSystem then return end
		local tableIdVal = chairSystem:FindFirstChild("TableId")
		if not tableIdVal then return end
		myTableId = tableIdVal.Value
		myBullets = 0
		matchActive = false
		lowerButtons.Visible = true
	elseif not active then
		myTableId = nil
		myBullets = 0
		matchActive = false
		stopTimer()
		ui:hide()
		unlockSeat()
		hideLowerButtons()
	end
end

-------------------------------------------------------
-- Remote: Countdown
-------------------------------------------------------
StartCountdown.OnClientEvent:Connect(function(tableId, seconds)
	if tableId ~= myTableId then return end

	matchActive = true
	hideLowerButtons()
	myPrevHP = MAX_HP
	oppPrevHP = MAX_HP
	lockSeat()

	ui:show()
	ui:hideChoices()
	ui:setSide(ChairUtils.getMySide(myTableId, player))
	ui:updateMyStats(MAX_HP, 0)
	ui:updateOppStats(MAX_HP)

	for i = seconds, 1, -1 do
		ui:showCountdown("Match starts in " .. i .. "...")
		task.wait(1)
	end
	ui:showCountdown("GO!")
	task.wait(0.5)
	ui:showCountdown("")
end)

-------------------------------------------------------
-- Remote: Choice Phase
-------------------------------------------------------
StartChoicePhase.OnClientEvent:Connect(function(tableId, timer)
	if tableId ~= myTableId then return end

	ui:showChoices(myBullets)
	ui:showCountdown("")

	stopTimer()
	choiceTimerThread = task.spawn(function()
		local remaining = timer
		while remaining > 0 do
			ui:updateTimer(remaining)
			task.wait(1)
			remaining -= 1
		end
		ui:updateTimer(0)
	end)
end)

-------------------------------------------------------
-- Remote: Round Result
-------------------------------------------------------
RoundResult.OnClientEvent:Connect(function(tableId, myChoice, oppChoice, myHP, myBul, oppHP, _oppBul)
	if tableId ~= myTableId then return end

	stopTimer()
	myBullets = myBul

	local oppChar, oppSide = ChairUtils.getOpponentInfo(myTableId, player)
	local anyShoot = (myChoice == "Shoot") or (oppChoice == "Shoot")

	-- One-shot damage callback (guarded against double-fire)
	local damageApplied = false
	local function applyDamageVisuals()
		if damageApplied then return end
		damageApplied = true

		DamageVisuals.syncHealth(player.Character, myHP, MAX_HP)
		if myHP < myPrevHP then DamageVisuals.flashRed(player.Character) end
		if oppHP < oppPrevHP then DamageVisuals.flashRed(oppChar) end
		myPrevHP = myHP
		oppPrevHP = oppHP
		ui:updateMyStats(myHP, myBullets)
		ui:updateOppStats(oppHP)
	end

	if anyShoot then
		-- Show updated bullets now, but keep old HP until fire moment
		ui:updateMyStats(myPrevHP, myBullets)
		task.delay(3, applyDamageVisuals) -- safety fallback
	else
		applyDamageVisuals()
	end

	ui:hideChoices()
	ui:showCountdown("GO!")

	-- Play animations
	local chairSystem = ChairUtils.getCurrentChairSystem(myTableId)
	local mySide = ChairUtils.getMySide(myTableId, player)
	if chairSystem and mySide then
		RoundAnimator.playRound(
			myChoice, oppChoice,
			player.Character, oppChar,
			chairSystem, mySide,
			oppSide or ((mySide == "Left") and "Right" or "Left"),
			applyDamageVisuals
		)
	end
end)

-------------------------------------------------------
-- Remote: Game Over
-------------------------------------------------------
GameOverRemote.OnClientEvent:Connect(function(tableId, winnerId, reason)
	if tableId ~= myTableId then return end

	stopTimer()
	matchActive = false
	unlockSeat()

	-- Reset HP for survivors so the red vignette clears
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = hum.MaxHealth
		end
	end

	if reason == "opponent_left" then
		ui:showCountdown("Opponent left! You win!")
		task.wait(3)
		ui:hide()
		if isSeated() and not matchActive then showLowerButtons() end
	else
		local isDraw = (winnerId == nil)
		local won = (winnerId == player.UserId)
		ui:showGameOver(won, isDraw)
		task.delay(3.1, function()
			if isSeated() and not matchActive then showLowerButtons() end
		end)
	end
end)

-------------------------------------------------------
-- Character wiring
-------------------------------------------------------
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(onSeated)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
