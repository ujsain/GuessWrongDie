--[[
	WinLoseTesting (LocalScript)  --  STUDIO TEST TOOL
	Hotkeys to preview the duel end screens and spawn a bot.

		8 -> WIN  end screen  (real win art + smoke slide-in)
		9 -> LOSE end screen  (real lose art + smoke slide-in)
		7 -> spawn a bot opponent (fires the same RequestBot remote the
		     "Play With AI" button uses -- you must be SEATED and the table
		     must be in WAITING phase, exactly like the button)

	Previews the END-SCREEN PRESENTATION only: it drives the real GameOverScreen
	module directly over the existing InGameUI, so there is no second HUD and no
	double-wired buttons. The server reward chain (coins, HP reset, seat unlock)
	listens on the GameOver remote and does NOT fire here.

	Gated to Studio so players can't trigger fake end screens in a published
	build. Delete this script before shipping.
]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then return end

local player = Players.LocalPlayer

local UIFolder       = player:WaitForChild("PlayerGui"):WaitForChild("InGameUI"):WaitForChild("UI")
local GameOverScreen = require(UIFolder:WaitForChild("GameOverScreen"))
local EventHub       = require(ReplicatedStorage:WaitForChild("EventHub"))
local RequestBot     = EventHub.RequestBot

local function preview(won)
	local gui = player.PlayerGui:WaitForChild("InGameUI")
	gui.Enabled = true
	GameOverScreen.new(gui):play(won, false)   -- (won, isDraw=false) -> art path
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.Eight then
		preview(true)            -- WIN
	elseif kc == Enum.KeyCode.Nine then
		preview(false)           -- LOSE
	elseif kc == Enum.KeyCode.Seven then
		RequestBot:FireServer()  -- spawn bot (must be seated, table WAITING)
	end
end)
