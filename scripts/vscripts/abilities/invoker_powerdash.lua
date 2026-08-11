function Banjoball:powerdash( keys )
	local caster = keys.caster
	local ball = Ball.unit

	-- Preventing the hero from dashing while rooted.
	if caster:HasModifier("modifier_shadowraze_root") then
		keys.ability:EndCooldown()
		keys.ability:StartCooldown(0.1)
		return
	end

	-- Computing a unit vector (a direction) from the place a player clicked on.
	local target = Vector(keys.target_points[1].x, keys.target_points[1].y, caster:GetAbsOrigin().z)
	local dir = (target-caster:GetAbsOrigin()):Normalized()

	caster.isUsingPowerdash = true -- something for myphysics.lua
	caster.powerdashIterations = 0

	-- Powerdash logic, which works every tick.
	Timers:CreateTimer(function()
		-- Checking if it's needed to stop.
		if caster.powerdashIterations >= POWERDASH_DURATION or not caster.isUsingPowerdash or caster:HasModifier("modifier_shadowraze_root") then
			caster.isUsingPowerdash = false
			if caster:HasModifier("modifier_powerdash") then
				caster:RemoveModifierByName("modifier_powerdash")
			end
			-- Ending timer.
			return
		end

		-- Initializing variables to compute a teleportation position.
		local newPos = caster:GetAbsOrigin() + POWERDASH_DISTANCE*dir
		local checkPos = newPos
		--  A variable that stops the hero from diving behind the goal line.If the hero is deep inside, it becomes false, and it's allowed to use Dash through this coordinate.
		isOutside = true
		if (caster:GetAbsOrigin().x < -POWERDASH_LIMIT_X) or (caster:GetAbsOrigin().x > POWERDASH_LIMIT_X) then	isOutside = false end
		
		-- Validating a teleportation position and computing a new one if it's outside the field or behind a goal line.
		if (not IsPointOnField(checkPos)) or (isOutside and ( (checkPos.x < -POWERDASH_LIMIT_X) or (checkPos.x > POWERDASH_LIMIT_X) ))  then
			-- Resetting the teleportation position and starting a cycle. The cycle validates every position in the 10-unit range until it finds a wall or the goal line.
			newPos = caster:GetAbsOrigin()
			while (true) do
				checkPos = newPos + 10*dir
				if (not IsPointOnField(checkPos)) or (isOutside and ( (checkPos.x < -POWERDASH_LIMIT_X) or (checkPos.x > POWERDASH_LIMIT_X) )) then break end
				newPos = checkPos
			end
		end
		caster:SetAbsOrigin(newPos) -- Finally, teleporting the hero.
		
		caster.powerdashIterations = caster.powerdashIterations + 1

		return 0.03 -- Starting a new iteration.
	end)
end