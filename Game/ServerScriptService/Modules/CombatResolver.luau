--[[
	CombatResolver
	Single responsibility: given two choices + bullet counts,
	return damage and bullet changes.
	
	3 choices: Shoot, Reload, Deflect
	
	Matrix:
	              Opponent
	         Shoot      Reload     Deflect
	You:
	Shoot  → Cancels out   Opp hit    Reflected back
	Reload → You hit    Both load  Both safe
	Deflect→ Reflected  Both safe  Both safe
	
	Shoot requires >= 1 bullet, costs 1 bullet.
	Reload gives +1 bullet (capped at MAX).
	Deflect reflects incoming shoot back at shooter.
]]

local CombatResolver = {}

function CombatResolver.resolve(leftChoice, rightChoice, leftBullets, rightBullets)
	local result = {
		leftDamage       = 0,
		rightDamage      = 0,
		leftBulletDelta  = 0,
		rightBulletDelta = 0,
	}

	-- None = did nothing, still vulnerable to being shot
	if leftChoice == "None" then leftChoice = nil end
	if rightChoice == "None" then rightChoice = nil end

	-- Process Reload
	if leftChoice == "Reload" then
		result.leftBulletDelta = 1
	end
	if rightChoice == "Reload" then
		result.rightBulletDelta = 1
	end

	-- Process Left shooting
	if leftChoice == "Shoot" and leftBullets >= 1 then
		result.leftBulletDelta = result.leftBulletDelta - 1

		if rightChoice == "Deflect" then
			result.leftDamage = result.leftDamage + 1
		elseif rightChoice == "Shoot" then
			-- Both shooting: cancels out, no damage
		else
			result.rightDamage = result.rightDamage + 1
		end
	end

	-- Process Right shooting
	if rightChoice == "Shoot" and rightBullets >= 1 then
		result.rightBulletDelta = result.rightBulletDelta - 1

		if leftChoice == "Deflect" then
			result.rightDamage = result.rightDamage + 1
		elseif leftChoice == "Shoot" then
			-- Both shooting: cancels out, no damage
		else
			result.leftDamage = result.leftDamage + 1
		end
	end

	return result
end

-- Validate a choice before accepting it
function CombatResolver.isValidChoice(choice, bullets)
	if choice == "Shoot" then
		return bullets >= 1
	end
	if choice == "Reload" or choice == "Deflect" or choice == "None" then
		return true
	end
	return false
end

return CombatResolver
