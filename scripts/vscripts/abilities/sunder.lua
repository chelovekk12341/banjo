sunder = class({})

function sunder:GetAOERadius()
	return 125 -- This value is equal to SUNDER_RADIUS constant.
end

function sunder:OnSpellStart()
    local caster = self:GetCaster()
	local target = self:GetCursorPosition()
	local ball = Ball.unit

	-- Checking if Sunder target out of the Cast Range, by calculating a unit vector (a direction) and distance between target and the hero.
	local dir = (target - caster:GetAbsOrigin()):Normalized()
	local dist = (target - caster:GetAbsOrigin()):Length()
	if dist > SUNDER_CAST_RANGE then
		target = caster:GetAbsOrigin() + dir*SUNDER_CAST_RANGE
	end
	target.z = caster:GetAbsOrigin().z

	local sunderCount = 0
	local totalSunderTicks = (caster:HasModifier("modifier_goalie") and SUNDER_DURATION_FOR_GOALIE) or 1
	local sundered = {} -- This array stores sundered units and prevents them from being affected again.
	Timers:CreateTimer(function()
		-- Exiting the timer if needed.
		if sunderCount >= totalSunderTicks then return end

		-- Visualizing the skill.
		local sunderParticle = ParticleManager:CreateParticle("particles/aghanim_beam_burn.vpcf", PATTACH_CUSTOMORIGIN, caster)
		ParticleManager:SetParticleControl(sunderParticle, 1, Vector(target.x + 20, target.y - 20, 325)) -- Vector sets the values to second control point (position) in the hammer.
		
		-- Creating an array and containing all heroes, that were caught in the AoE.
		local targets = {}
		for _,hero in ipairs(Banjoball.vHeroes) do
			if hero ~= caster then
				if IsUnitInTrueRadius(hero:GetAbsOrigin(), target, SUNDER_RADIUS) and not sundered[hero] then
					table.insert(targets, hero)
					sundered[hero] = true
				end
			end
		end
		-- Checking if we need to include the ball in the array.
		if ((ball:GetAbsOrigin().x - target.x)^2+(ball:GetAbsOrigin().y - target.y)^2)^0.5 <= SUNDER_RADIUS and not sundered[ball] then
			table.insert(targets, ball)
			sundered[ball] = true
			-- If the ball is stopped in the goal area, taking the ball counts as a save.
			if GetGoalUnitIsWithin( ball ) and caster:GetTeam() ~= ball.lastMovedBy:GetTeam() then
				ball.sundered = true
			end
		end

		-- Inputting gathered heroes in the function, that swaps their velocity.
		VelocitySwap(caster, targets, caster:HasModifier("modifier_goalie"))

		-- Starting new iteration of the timer.
		sunderCount = sunderCount + 1
		return FRAME_TIME
	end)

	caster:EmitSound("Hero_Terrorblade.Sunder.Cast")
end

function VelocitySwap(getter,giverArray,isGoalie)
	local ball = Ball.unit
	local finishvel = 0 -- A variable, that stacks velocity.
	-- A cycle, that gives every unit the velocity of the caster and stacks final velocity.
	for i,giver in pairs(giverArray) do
		if giver ~= getter and not Banjoball:IsProjectile(giver) then
			finishvel = finishvel + giver:GetPhysicsVelocity()
			-- Preventing the ball to receive Terrorblade's velocity if he's goalkeeper.
			if isGoalie and ball.lastMovedBy ~= getter then
				giver:SetPhysicsVelocity(Vector(0, 0, 0))
			else
				giver:SetPhysicsVelocity(getter:GetPhysicsVelocity())
			end
		end
	end
	getter:AddPhysicsVelocity((isGoalie and ball.lastMovedBy ~= getter and 0) or finishvel) -- Giving the caster final velocity if he's not the goalie.
end