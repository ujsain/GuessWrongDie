--[[
	DuelClient (LocalScript)
	Thin controller: owns match state, wires remote events to the HUD, and turns
	HUD signals back into remote fires. No GUI is touched directly (the HUD owns
	that) and no game rules live here (see DuelRules).
]]

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local playerGui = player:WaitForChild("PlayerGui")
local UIFolder  = playerGui:WaitForChild("InGameUI"):WaitForChild("UI")

local DuelHUD       = require(UIFolder:WaitForChild("DuelHUD"))
local DuelModules   = script.Parent.Parent:WaitForChild("DuelModules")
local ChairUtils    = require(DuelModules:WaitForChild("ChairUtils"))
local DamageVisuals = require(DuelModules:WaitForChild("DamageVisuals"))
local RoundAnimator = require(DuelModules:WaitForChild("RoundAnimator"))
local DuelRules     = require(RS:WaitForChild("DuelRules"))

local EventHub         = require(RS:WaitForChild("EventHub"))
local StartCountdown   = EventHub.StartCountdown
local StartChoicePhase = EventHub.StartChoicePhase
local SubmitChoice     = EventHub.SubmitChoice
local RoundResult      = EventHub.RoundResult
local GameOverRemote   = EventHub.GameOver
local RequestBot       = EventHub.RequestBot
local MatchResultEvent = EventHub.MatchResultEvent

local MAX_HP = DuelRules.MAX_HP

local ui = DuelHUD.new()
ui:hide()
ui:hideChoices()

-- Match state ------------------------------------------------------------
local myTableId = nil
local myBullets = 0
local myPrevHP = MAX_HP
local oppPrevHP = MAX_HP
local choiceTimerThread = nil
local matchActive = false

-- Seated helpers ---------------------------------------------------------
local function isSeated()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.SeatPart ~= nil
end

local function showLowerButtons()
	if matchActive then return end
	if not isSeated() then return end
	ui:setLowerButtons(true)
end

local function hideLowerButtons()
	ui:setLowerButtons(false)
end

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

-- HUD signals ------------------------------------------------------------
ui.onConfirm = function(choice)
	if myTableId then
		SubmitChoice:FireServer(myTableId, choice)
	end
	stopTimer()
end

-- Play With AI: ask the server to drop a bot into the empty seat.
local aiDebounce = false
ui.onPlayAI = function()
	if matchActive or not myTableId or not isSeated() then return end
	if aiDebounce then return end
	aiDebounce = true
	RequestBot:FireServer()
	task.delay(2, function() aiDebounce = false end)
end

-- Leave: stand up from the chair (same effect as pressing Space). Waiting only.
ui.onLeave = function()
	if matchActive then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Sit = false end
end

-- Seated handler ---------------------------------------------------------
local function onSeated(active, seat)
	if active and seat then
		local chairSystem = ChairUtils.getChairSystem(seat)
		if not chairSystem then return end
		local tableIdVal = chairSystem:FindFirstChild("TableId")
		if not tableIdVal then return end
		myTableId = tableIdVal.Value
		myBullets = 0
		matchActive = false
		ui:setLowerButtons(true)
	elseif not active then
		-- Unseated mid-match = we DIED (the server's ragdoll zeros Humanoid.Health,
		-- breaking the seat weld). NOT a voluntary leave, so don't tear down here:
		-- that nulls myTableId (GameOver would bail) and ui:hide() wipes the result
		-- screen. A dead humanoid is the reliable signal this unseat was a death.
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local dead = (hum ~= nil) and (hum.Health <= 0)
		if matchActive or dead then return end
		myTableId = nil
		myBullets = 0
		matchActive = false
		stopTimer()
		ui:hide()
		unlockSeat()
		hideLowerButtons()
	end
end

-- Remote: Countdown ------------------------------------------------------
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
	ui:updateOppStats(MAX_HP, 0)

	for i = seconds, 1, -1 do
		ui:showCountdown("Match starts in " .. i .. "...")
		task.wait(1)
	end
	ui:showCountdown("GO!")
	task.wait(0.5)
	ui:showCountdown("")
end)

-- Remote: Choice Phase ---------------------------------------------------
StartChoicePhase.OnClientEvent:Connect(function(tableId, timer, deflectCD)
	if tableId ~= myTableId then return end

	ui:showChoices(myBullets, deflectCD or 0)
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

-- Remote: Round Result ---------------------------------------------------
RoundResult.OnClientEvent:Connect(function(tableId, myChoice, oppChoice, myHP, myBul, oppHP, oppBul)
	if tableId ~= myTableId then return end

	stopTimer()
	myBullets = myBul

	local oppChar, oppSide = ChairUtils.getOpponentInfo(myTableId, player)
	local anyShoot = (myChoice == "Shoot") or (oppChoice == "Shoot")

	-- One-shot damage callback (guarded against double-fire). Never writes
	-- Humanoid.Health on the client -- match HP lives in the hearts UI; death is
	-- solely the server's job (ragdollSide), fired once.
	local damageApplied = false
	local function applyDamageVisuals()
		if damageApplied then return end
		damageApplied = true
		if myHP < myPrevHP then DamageVisuals.flashRed(player.Character) end
		if oppHP < oppPrevHP then DamageVisuals.flashRed(oppChar) end
		myPrevHP = myHP
		oppPrevHP = oppHP
		ui:updateMyStats(myHP, myBullets)
		ui:updateOppStats(oppHP, oppBul)
	end

	if anyShoot then
		-- Show updated bullets now, but keep old HP until the fire moment.
		ui:updateMyStats(myPrevHP, myBullets)
		task.delay(3, applyDamageVisuals) -- safety fallback
	else
		applyDamageVisuals()
	end

	ui:hideChoices()
	ui:showCountdown("GO!")

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

-- Remote: Game Over ------------------------------------------------------
GameOverRemote.OnClientEvent:Connect(function(tableId, winnerId, reason)
	if tableId ~= myTableId then return end

	stopTimer()
	matchActive = false
	unlockSeat()

	-- Reset HP for survivors so the red vignette clears.
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = hum.MaxHealth
		end
	end

	if reason == "opponent_left" then
		MatchResultEvent:Fire("Win")   -- opponent leaving counts as a win
		ui:showGameOver(true, false)
	else
		local isDraw = (winnerId == nil)
		local won = (winnerId == player.UserId)
		MatchResultEvent:Fire(isDraw and "Draw" or (won and "Win" or "Lose"))
		ui:showGameOver(won, isDraw)
	end

	task.delay(3.1, function()
		if isSeated() and not matchActive then showLowerButtons() end
	end)
end)

-- Character wiring -------------------------------------------------------
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(onSeated)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
