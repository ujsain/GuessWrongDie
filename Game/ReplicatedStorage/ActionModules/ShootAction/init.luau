--[[
	ShootAction (orchestrator)
	Sets up the gun, plays the shoot animation, and at the fire moment
	delegates the visual to MuzzleFlash + Bullet.
	mode: "straight" | "deflected" | "collide"
	Sub-modules: Config, MuzzleAim, MuzzleFlash, Bullet.
]]
local DuelEffectUtils = require(script.Parent:WaitForChild("DuelEffectUtils"))
local EventHub        = require(game:GetService("ReplicatedStorage"):WaitForChild("EventHub"))

local Config      = require(script:WaitForChild("Config"))
local MuzzleAim   = require(script:WaitForChild("MuzzleAim"))
local MuzzleFlash = require(script:WaitForChild("MuzzleFlash"))
local Bullet      = require(script:WaitForChild("Bullet"))

local ShootAction = {}

function ShootAction.perform(character, chairSystem, side, onFireMoment, mode)
	local gunInfo = DuelEffectUtils.setupGun(character, chairSystem, side)
	local track = DuelEffectUtils.playAnimation(character, Config.SHOOT_ANIM_ID, "ShootAction", function()
		DuelEffectUtils.teardownGun(gunInfo)
	end)

	local function fireNow()
		local pistol, muzzleTip, origin, axis = MuzzleAim.get(chairSystem, side)
		if muzzleTip then
			MuzzleFlash.fire(muzzleTip, origin, axis)

			-- Gunshot sound (positional at the muzzle). Fires for every mode.
			EventHub.ShootEvent:Fire(character, side, muzzleTip)

			if mode == "deflected" then
				-- slug flies out, bounces, returns; HP/flash land on return impact
				Bullet.fireDeflected(origin, axis, character, onFireMoment)
				return
			elseif mode == "collide" then
				-- both shot: find the opponent muzzle, meet just shy of center, drop
				local oppSide = (side == "Left") and "Right" or "Left"
				local _, oppMuzzle, oppOrigin = MuzzleAim.get(chairSystem, oppSide)
				local meetingPos
				if oppMuzzle and oppOrigin then
					meetingPos = origin:Lerp(oppOrigin, Config.COLLIDE_MEET_FRACTION)
				else
					meetingPos = origin + axis * Config.DEFLECT_FORWARD_DISTANCE
				end
				Bullet.fireColliding(origin, meetingPos, onFireMoment)
				return
			end

			Bullet.fireStraight(origin, axis, character, pistol)
		end
		-- straight shot (or no muzzle found): apply damage at the fire moment
		if onFireMoment then onFireMoment() end
	end

	if track then
		while track.Length == 0 and track.IsPlaying do
			task.wait()
		end
		if track.Length > 0 then
			local animDelay = (track.Length * Config.FIRE_MOMENT) / track.Speed
			task.delay(animDelay, fireNow)
		else
			fireNow()
		end
	else
		fireNow()
	end
end

return ShootAction
