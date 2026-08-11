function Banjoball:ball_lightning( keys )
	local caster = keys.caster
	local ball = Ball.unit
	local impuls = BALL_LIGHTNING_VELOCITY
	local manaCost = BALL_LIGHTNING_INITIAL_MANA_COST

	-- SwapAbilities( caster, "ball_lightning_break", "ball_lightning", ABILITY_SLOT_E )
	if caster.isInBallLightning then
		Banjoball:ball_lightning_break( keys )
	else
		if caster:HasModifier("modifier_shadowraze_root") then
			caster.surgeOn = false
			caster:StopSound("BallLightning.Loop")
			return
		end

		-- Prohibiting usage with the ball.
		if caster == ball.controller then
			caster.surgeOn = false
			caster:StopSound("BallLightning.Loop")
			return 
		end
		
		local mana = caster:GetMana()
		if mana < manaCost then caster.surgeOn = false return end
		caster:SetMana(mana - manaCost)
		local balllightning = caster:FindAbilityByName("ball_lightning")
		
		if #GetUnitsInTrueRadius(caster:GetAbsOrigin(), SUPER_SPRINT_NOHERO_RADIUS) > 1 then
			Banjoball:SlamNearby(caster, caster:GetAbsOrigin(), BALL_LIGHTNING_NOHERORADIUS, BALL_LIGHTNING_KNOCKBACK_XY, 0, BALL_LIGHTNING_NOHERORADIUS, function(caster, entity, direction, slam_xy, slam_z)
				if entity ~= caster and entity ~= Ball.unit then return (direction*slam_xy + Vector(0, 0, slam_z)) end
				
				return Vector(0, 0, 0)
			end)
		end

		caster.isInBallLightning = true
		caster:AddNewModifier(caster,nil,"modifier_self_root", {duration = 99999}) 
		-- Create particle and set colors
		caster.surgeParticle = ParticleManager:CreateParticle("particles/ball_lightning/ball_lightning.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
		ParticleManager:SetParticleControl(caster.surgeParticle, 2, caster.colArr[COLOR_INDEX_BASE])
		ParticleManager:SetParticleControl(caster.surgeParticle, 3, caster.colArr[COLOR_INDEX_LIGHTEST])
		ParticleManager:SetParticleControl(caster.surgeParticle, 4, caster.colArr[COLOR_INDEX_DARK])
		
		ParticleManager:SetParticleControlEnt(caster.surgeParticle, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
		ParticleManager:SetParticleControlEnt(caster.surgeParticle, 1, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
		
		caster.dontChangeFriction = true
		caster:SetPhysicsFriction(NO_FRICTION)
		local dir = caster:GetForwardVector()

		caster:AddPhysicsVelocity(dir * impuls)
		
		caster:EmitSound("BallLightning")
		caster:EmitSound("BallLightning.Loop")
	end
end

function Banjoball:ball_lightning_break( keys )
	local caster = keys.caster

	Banjoball:BallLightningBreak( caster )
end

function Banjoball:BallLightningBreak( caster )
	local ball = Ball.unit
	local wasInBallLightning = caster.isInBallLightning
	
	if caster:HasModifier("modifier_self_root") then
		caster:RemoveModifierByName("modifier_self_root")
		if caster.surgeParticle then
			ParticleManager:DestroyParticle(caster.surgeParticle, false)
		end
		caster.surgeOn = false
		SwapAbilities( caster, "ball_lightning", "ball_lightning_break", ABILITY_SLOT_E )
		caster.isInBallLightning = false
	end
	
	if caster ~= ball.controller then
		local vel = caster:GetPhysicsVelocity():Length()
		local dir = caster:GetPhysicsVelocity():Normalized()
		if (vel >= BALL_LIGHTNING_VELOCITY_END) then
			caster:SetPhysicsVelocity(dir * (vel - BALL_LIGHTNING_VELOCITY_END))
		else
			caster:SetPhysicsVelocity(Vector(0,0,0))
		end
	end

	caster:SetPhysicsFriction(GROUND_FRICTION)
	
	caster.dontChangeFriction = false
	caster:StopSound("BallLightning.Loop")
end