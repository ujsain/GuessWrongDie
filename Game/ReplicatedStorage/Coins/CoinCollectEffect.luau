--[[
	CoinCollectEffect  (client — ReplicatedStorage.Coins.CoinCollectEffect)

	Spawns 2-D coin sprites at a screen position (e.g. where a ring was),
	scatters them outward, then flies them into the HUD coin counter.

	Usage from any LocalScript:
	    local CoinCollectEffect = require(ReplicatedStorage.Coins.CoinCollectEffect)
	    CoinCollectEffect.Play(screenPosition: Vector2)       -- from ring world pos
	    CoinCollectEffect.PlayFromWorldPos(worldPosition: Vector3)  -- convenience
]]--

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CoinCollectEffect = {}

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local COIN_COUNT       = 7          -- how many coins to spawn per burst
local COIN_SIZE        = 28         -- pixel size of each flying coin
local SCATTER_RADIUS   = 90         -- how far coins scatter outward (px)
local POP_DURATION     = 0.12       -- scale-up pop time
local SCATTER_DURATION = 0.18       -- time to reach scattered position
local FLY_DURATION     = 0.45       -- time to fly from scatter to HUD counter
local FLY_STAGGER      = 0.04       -- delay between each coin starting to fly
local START_SCALE      = 0.3        -- coins start this small
local POP_SCALE        = 1.3        -- overshoot scale during pop
local END_SCALE        = 0.5        -- coins shrink to this on arrival

--------------------------------------------------------------------------------
-- Internals
--------------------------------------------------------------------------------

-- The ScreenGui we render coins into (created once, persists)
local effectGui: ScreenGui = nil

-- Template ImageLabel (child of this ModuleScript, created at edit-time)
local coinTemplate: ImageLabel = script:WaitForChild("CoinImageTemplate")

local function getOrCreateGui(): ScreenGui
	if effectGui and effectGui.Parent then return effectGui end

	effectGui = Instance.new("ScreenGui")
	effectGui.Name = "CoinCollectEffectGui"
	effectGui.DisplayOrder = 10  -- above CurrencyGUI (5)
	effectGui.IgnoreGuiInset = false
	effectGui.ResetOnSpawn = false
	effectGui.Parent = playerGui
	return effectGui
end

--- Find the HUD coin counter's absolute position to fly toward.
local function getCounterTarget(): Vector2
	local coinDisplay = playerGui:FindFirstChild("CurrencyGUI")
	if coinDisplay then
		local counter = coinDisplay:FindFirstChild("CoinCounter")
		if counter then
			local pos = counter.AbsolutePosition
			local size = counter.AbsoluteSize
			-- Aim for the icon area (left side of the counter)
			return Vector2.new(pos.X + size.X * 0.15, pos.Y + size.Y * 0.5)
		end
	end
	-- Fallback: top-right area
	local cam = workspace.CurrentCamera
	if cam then
		return Vector2.new(cam.ViewportSize.X - 80, 38)
	end
	return Vector2.new(0, 0)
end

local function tweenPromise(obj, info, props)
	local tween = TweenService:Create(obj, info, props)
	tween:Play()
	return tween
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Play the coin collect animation from a screen-space position.
--- @param screenPos  Vector2 — origin point on screen where coins appear.
function CoinCollectEffect.Play(screenPos: Vector2)
	local gui = getOrCreateGui()
	local target = getCounterTarget()

	for i = 1, COIN_COUNT do
		task.spawn(function()
			-- Create coin
			local coin = coinTemplate:Clone()
			coin.Size = UDim2.fromOffset(COIN_SIZE, COIN_SIZE)
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
			coin.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
			coin.Visible = true

			-- Start small
			local uiScale = Instance.new("UIScale")
			uiScale.Scale = START_SCALE
			uiScale.Parent = coin

			coin.Parent = gui

			-- Random scatter direction
			local angle = math.rad(math.random(0, 360))
			local dist = SCATTER_RADIUS * (0.5 + math.random() * 0.5)
			local scatterX = screenPos.X + math.cos(angle) * dist
			local scatterY = screenPos.Y + math.sin(angle) * dist

			-- Phase 1: Pop + Scatter (simultaneous)
			local popInfo = TweenInfo.new(POP_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local scatterInfo = TweenInfo.new(SCATTER_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			tweenPromise(uiScale, popInfo, { Scale = POP_SCALE })
			local scatterTween = tweenPromise(coin, scatterInfo, {
				Position = UDim2.fromOffset(scatterX, scatterY),
			})
			scatterTween.Completed:Wait()

			-- Settle scale back to 1
			tweenPromise(uiScale, TweenInfo.new(0.06), { Scale = 1 })

			-- Stagger: wait a bit before flying to counter
			task.wait(FLY_STAGGER * (i - 1))

			-- Phase 2: Fly to counter + shrink
			local flyInfo = TweenInfo.new(FLY_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.In)

			tweenPromise(uiScale, flyInfo, { Scale = END_SCALE })
			local flyTween = tweenPromise(coin, flyInfo, {
				Position = UDim2.fromOffset(target.X, target.Y),
			})
			flyTween.Completed:Wait()

			-- Done — destroy
			coin:Destroy()
		end)
	end
end

--- Convenience: play from a world-space position (e.g. ring.Position).
--- Converts to screen coords via the current camera.
function CoinCollectEffect.PlayFromWorldPos(worldPos: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then return end

	local screenPoint, onScreen = camera:WorldToScreenPoint(worldPos)
	if not onScreen then
		-- Ring is off-screen — use center of screen as fallback
		local vp = camera.ViewportSize
		CoinCollectEffect.Play(Vector2.new(vp.X / 2, vp.Y / 2))
	else
		CoinCollectEffect.Play(Vector2.new(screenPoint.X, screenPoint.Y))
	end
end

return CoinCollectEffect
