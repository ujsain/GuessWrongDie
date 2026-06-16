--[[
	DuelUI
	Grabs existing GUI from StarterGui. No runtime creation.
]]

local DuelUI = {}
DuelUI.__index = DuelUI

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Default positions
local LEFT_POS  = UDim2.new(0, 20, 0.5, -25)
local RIGHT_POS = UDim2.new(1, -140, 0.5, -25)

function DuelUI.new()
	local self = setmetatable({}, DuelUI)
	self.selectedChoice = nil
	self.onConfirm = nil

	local pg = player.PlayerGui
	local gui = pg:WaitForChild("InGameUI", 10)
	if not gui then return self end

	self.gui = gui
	-- All elements now live under the "InGame" Frame inside the InGameUI ScreenGui
	local root = gui:WaitForChild("InGame")
	self.root = root
	self.gui.Enabled = true   -- keep ScreenGui enabled so sibling LowerButtons can show while waiting
	self.root.Visible = false  -- combat HUD hidden until a match starts

	self.countdownLabel = root.CountdownLabel
	self.timerLabel     = root.TimerLabel
	self.resultLabel    = root.ResultLabel
	self.bottomBar      = root.ButtonBar
	self.confirmBtn     = root.ConfirmButton

	self.myStats  = root.MyStats
	self.oppStats = root.OppStats
	self.myHeartsLabel   = root.MyStats.HeartsLabel
	self.myBulletsLabel  = root.MyStats.BulletsLabel
	self.oppHeartsLabel  = root.OppStats.HeartsLabel

	self.choiceButtons = {
		Shoot   = self.bottomBar.ShootButton,
		Reload  = self.bottomBar.ReloadButton,
		Deflect = self.bottomBar.DeflectButton,
	}

	self.originalColors = {}
	for name, btn in pairs(self.choiceButtons) do
		self.originalColors[name] = btn.BackgroundColor3
	end

	for name, btn in pairs(self.choiceButtons) do
		btn.MouseButton1Click:Connect(function()
			self:_selectChoice(name)
		end)
	end

	self.confirmBtn.MouseButton1Click:Connect(function()
		if not self.selectedChoice or not self.onConfirm then return end
		-- Block confirm when Shoot is selected with no bullets
		if self.selectedChoice == "Shoot" and (self._currentBullets or 0) < 1 then return end

		self.onConfirm(self.selectedChoice)
		self:hideChoices()
		self.countdownLabel.Text = "Waiting for opponent..."
	end)

	return self
end

function DuelUI:setSide(side)
	if side == "Left" then
		self.myStats.Position = LEFT_POS
		self.oppStats.Position = RIGHT_POS
	else
		self.myStats.Position = RIGHT_POS
		self.oppStats.Position = LEFT_POS
	end
end

function DuelUI:_selectChoice(name)
	self.selectedChoice = name
	for choiceName, btn in pairs(self.choiceButtons) do
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		local shine = btn:FindFirstChild("ShineBack")
		if choiceName == name then
			if stroke then stroke.Thickness = 3 end
			if shine then shine.Visible = true end
		else
			if stroke then stroke.Thickness = 0 end
			if shine then shine.Visible = false end
		end
	end
	self.confirmBtn.Visible = true

	-- Fade confirm button when Shoot is selected with no bullets
	local img = self.confirmBtn:FindFirstChild("ImageLabel")
	if img then
		if name == "Shoot" and (self._currentBullets or 0) < 1 then
			img.ImageTransparency = 0.5
		else
			img.ImageTransparency = 0
		end
	end
end

function DuelUI:show()
	if self.gui then self.gui.Enabled = true end
	if self.root then self.root.Visible = true end
end

function DuelUI:hide()
	if not self.gui then return end
	if self.root then self.root.Visible = false end
	self:hideChoices()
	self.countdownLabel.Text = ""
	self.resultLabel.Visible = false
	self.timerLabel.Text = ""
end

function DuelUI:destroy()
	self:hide()
end

function DuelUI:showCountdown(text)
	self.countdownLabel.Text = text
end

function DuelUI:showChoices(bullets)
	self._currentBullets = bullets
	self.selectedChoice = nil
	self.confirmBtn.Visible = false
	self.bottomBar.Visible = true

	for name, btn in pairs(self.choiceButtons) do
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Thickness = 0 end
		local shine = btn:FindFirstChild("ShineBack")
		if shine then shine.Visible = false end
		btn.BackgroundTransparency = 1

		if name == "Shoot" and bullets < 1 then
			btn.BackgroundTransparency = 0.7
			btn.AutoButtonColor = false
		else
			btn.AutoButtonColor = true
		end
	end
end

function DuelUI:hideChoices()
	self.bottomBar.Visible = false
	self.confirmBtn.Visible = false
	self.timerLabel.Text = ""
end

function DuelUI:updateTimer(seconds)
	self.timerLabel.Text = "Pick a choice... " .. tostring(math.ceil(seconds))
end

function DuelUI:updateMyStats(health, bullets)
	self.myHeartsLabel.Text = string.rep("♥", health) .. string.rep("♡", 3 - health)
	if bullets then self.myBulletsLabel.Text = "Bullets: " .. bullets end
end

function DuelUI:updateOppStats(health)
	self.oppHeartsLabel.Text = string.rep("♥", health) .. string.rep("♡", 3 - health)
end

function DuelUI:showResult(text, duration)
	self.resultLabel.Text = text
	self.resultLabel.Visible = true
	task.delay(duration or 2, function()
		self.resultLabel.Visible = false
	end)
end

function DuelUI:showGameOver(won, isDraw)
	if isDraw then
		self.countdownLabel.Text = "DRAW!"
	elseif won then
		self.countdownLabel.Text = "YOU WIN!"
		self.countdownLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
	else
		self.countdownLabel.Text = "YOU LOSE!"
		self.countdownLabel.TextColor3 = Color3.fromRGB(231, 76, 60)
	end
	task.delay(3, function()
		self.countdownLabel.TextColor3 = Color3.new(1,1,1)
		self:hide()
	end)
end

return DuelUI
