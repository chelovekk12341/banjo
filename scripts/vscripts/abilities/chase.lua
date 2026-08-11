chase = class({})

function chase:GetCastRange(vLocation, hTarget)
	return 1346
end

function chase:GetAOERadius()
	return 1346
end

function chase:OnSpellStart()
    local caster = self:GetCaster()
	local ball = Ball.unit

	-- Preventing usage while being in the air or rooted.
	if  caster:HasModifier("modifier_shadowraze_root") then
		self:EndCooldown()
		return
	end

	-- Restricting the hero from walking during the chase.
	caster:AddNewModifier(caster,nil,"modifier_self_root", {duration = 99999})
	-- Adding haste + running animations during the chase.
	if not caster:HasModifier("modifier_rune_haste") then caster:AddNewModifier(caster, nil, "modifier_rune_haste", {}) end
	if not caster:HasModifier("modifier_haste_anim") then GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, caster, "modifier_haste_anim", {}) end
	-- Making a sound.
	caster:EmitSound("Hero_FacelessVoid.TimeWalk")

	-- Calculating certain variables for the chasing logic and physics.
	caster.chaseDistance = CHASE_DISTANCE
	caster.teleportAmount = 0
	caster.tackleParticleCounter = 0
	caster.isUsingTackle = true
		caster.traveled = 0 -- A variable for debugging.

	-- Chasing logic, which works every tick.
	Timers:CreateTimer(function()
		-- Checking if it's needed to stop.
		if caster.teleportAmount >= CHASE_DURATION or not caster.isUsingTackle or caster:HasModifier("modifier_shadowraze_root") then
			caster.isUsingTackle = false -- Ending the chase physics.

			if caster:HasModifier("modifier_self_root") then caster:RemoveModifierByName("modifier_self_root") end
			if caster:HasModifier("modifier_rune_haste") then caster:RemoveModifierByName("modifier_rune_haste") end
			if caster:HasModifier("modifier_haste_anim") then caster:RemoveModifierByName("modifier_haste_anim") end

			if caster:GetAbsOrigin().z > GROUND_Z then caster:AddPhysicsVelocity(caster:GetForwardVector()*CHASE_AIR_VELOCITY) end
			
			return -- Ending timer.
		end

		-- Validating a teleportation position.
		local fv = caster:GetForwardVector()
		local newPos = caster:GetAbsOrigin() + caster.chaseDistance*fv
		local checkPos = newPos
		if (not IsPointOnField(checkPos)) then
			newPos = caster:GetAbsOrigin()
			while (true) do
				checkPos = newPos + 10*fv
				if (not IsPointOnField(checkPos)) then break end
				newPos = checkPos
			end
		end

		-- Teleportating the hero.
		caster:SetAbsOrigin(newPos) 
		caster.teleportAmount = caster.teleportAmount + 1
		-- Printing debugging information.
			-- caster.traveled = caster.traveled + caster.chaseDistance
			-- print("speed = " .. caster.chaseDistance, "distance =" .. caster.traveled, "tick =" .. caster.teleportAmount)
		-- Increasing the range of the next teleport.
		if caster.chaseDistance + CHASE_ACCELERATION < CHASE_LIMIT then caster.chaseDistance = caster.chaseDistance + CHASE_ACCELERATION
		else caster.chaseDistance = CHASE_LIMIT end

		-- Finding enemies to cast tackle on.
		for i, entity in ipairs(GetUnitsInTrueRadius(caster:GetAbsOrigin(), CHASE_SLOW_RADIUS)) do
			if entity:GetTeam() ~= caster:GetTeam() and not entity:HasModifier("modifier_goalie") then GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, entity, "modifier_tackle_slow", {}) end
		end
		
		-- Creating a particle every second tick.
		if caster.tackleParticleCounter == 1 then
			local particle = ParticleManager:CreateParticle("particles/ghost_model.vpcf", PATTACH_ABSORIGIN, caster)
			ParticleManager:SetParticleControlEnt(particle, 1, caster, 1, "follow_origin", caster:GetAbsOrigin(), true)
			caster.tackleParticleCounter = 0
		else
			caster.tackleParticleCounter = caster.tackleParticleCounter + 1
		end

		return FRAME_TIME -- Starting a new iteration.
	end)
end