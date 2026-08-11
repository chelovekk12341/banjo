function Banjoball:ogre_smash( keys )
	local caster = keys.caster
	local ball = Ball.unit
	--ball.razNePidoraz = true

	caster:FindAbilityByName("kick_ball"):StartCooldown(OGRE_SMASH_DELAY)
	
	Timers:CreateTimer(OGRE_SMASH_DELAY_BALL, function()
		local casterPos = caster:GetAbsOrigin()
		local dir = caster:GetForwardVector()
		local perp = Vector(-dir.y, dir.x, 0):Normalized()
		local corners = {}
			
		-- Create hitbox: 0 = bottom right, clockwise from there.
		corners[0] = casterPos - (perp * OGRE_SMASH_NEAR_WIDTH / 2)
		corners[1] = casterPos + (perp * OGRE_SMASH_NEAR_WIDTH / 2)
		corners[2] = casterPos + (perp * OGRE_SMASH_FAR_WIDTH / 2) + (dir * OGRE_SMASH_LENGTH)
		corners[3] = casterPos - (perp * OGRE_SMASH_FAR_WIDTH / 2) + (dir * OGRE_SMASH_LENGTH)

		local targets = {}
		local targetCount = 0
		-- Test for heroes
		for _,hero in ipairs(Banjoball.vHeroes) do
			if hero ~= caster then
				local heroPos = hero:GetAbsOrigin()
				if isUnitInHitbox(hero, corners) and (heroPos.z >= casterPos.z - OGRE_SMASH_Z_DOWN and heroPos.z <= casterPos.z + OGRE_SMASH_Z_UP) then
					table.insert(targets, hero)
					targetCount = targetCount + 1
				end
			end
		end
		
		Banjoball:IterateProjectiles( function( proj )
			local projPos = proj:GetAbsOrigin()
			if isUnitInHitbox(proj, corners) and (projPos.z >= casterPos.z - OGRE_SMASH_Z_DOWN and projPos.z <= casterPos.z + OGRE_SMASH_Z_UP) then
				table.insert(targets, proj)
				targetCount = targetCount + 1
			end
		end)
		
		-- Make smash shots more possible. FUTURE BUFF: make it add a z bump
		if ball.lastController == caster then
			corners[2] = corners[2] + (dir * OGRE_SMASH_BALL_LENGTH)
			corners[3] = corners[3] + (dir * OGRE_SMASH_BALL_LENGTH)
		end
		local ballPos = ball:GetAbsOrigin()
		if not ball.controller and isUnitInHitbox(ball, corners)  and (ballPos.z >= casterPos.z - OGRE_SMASH_Z_DOWN and ballPos.z <= casterPos.z + OGRE_SMASH_Z_UP)then
			table.insert(targets, ball)
			caster.spellAssistTimer = GameRules:GetGameTime() -- Set assist
			targetCount = targetCount + 1
		end
		
		local smashParticle = ParticleManager:CreateParticle("particles/ogre_smash/ogre_magi_ogresmash_start.vpcf", PATTACH_CUSTOMORIGIN, caster)
		ParticleManager:SetParticleControl(smashParticle, 0, casterPos + (dir*OGRE_SMASH_PARTICLE_POS))

		-- Apply force to everything being smashed
		if targetCount > 0 then
			for _, target in ipairs(targets) do
				if target == ball then
					if ball.affectedByPowershot == true then
						Banjoball:PowerStop()
						ballaffectxy = ballaffectxy * 1.5
					end
					-- Slamshoting logic, that depends on distance to the nearest goal area.
					if ( ball:GetAbsOrigin() - caster:GetAbsOrigin() ):Length() <= SMASHSHOT_RADIUS and ball:GetAbsOrigin().z <= casterPos.z + OGRE_SMASH_Z_UP and not ball.controller then 
						local ballVelocity = ball:GetPhysicsVelocity()
						local direction = ( ballPos - casterPos ):Normalized()
						local ogreIsRadiant = caster:GetTeam() == DOTA_TEAM_GOODGUYS
						local coordinate = (ogreIsRadiant and SMASHSHOT_COORDINATE_X ) or -1 * SMASHSHOT_COORDINATE_X
				
						if ogreIsRadiant and casterPos.x >= coordinate or (not ogreIsRadiant) and casterPos.x <= coordinate then casterPos.x = coordinate end
						if math.abs(casterPos.y) <= SMASHSHOT_COORDINATE_Y then casterPos.y = 0 else casterPos.y = math.abs(casterPos.y) - SMASHSHOT_COORDINATE_Y end
				
						local distance = Vector(casterPos.x - coordinate, casterPos.y, 0):Length()
						local slamshot_xy = math.max( math.min(distance*SMASHSHOT_DISTANCE_MULT_XY, SMASHSHOT_MAXIMAL_VELOCITY_XY), SMASHSHOT_MINIMAL_VELOCITY_XY )
						local slamshot_z = 0
				
						if ball.vVelocity.z > 0 and caster:GetAbsOrigin().z <= GROUND_Z then
							slamshot_xy = SMASHSHOT_AIR_XY
							slamshot_z = SMASHSHOT_AIR_Z
							ball:SetAbsOrigin( direction*SMASHSHOT_LENGTH + Vector(ballPos.x, ballPos.y, SMASHSHOT_HEIGHT) )
						end
						ball:SetPhysicsVelocity(direction*slamshot_xy + Vector(ballVelocity.x, ballVelocity.y, slamshot_z) )
						Banjoball:RegisterBallHit(caster)
					end

					-- ball.yaSmoktavYNazara = true

					-- Timers:CreateTimer(OGRE_SMASH_RICOSHET_TIME, function()
						-- ball.yaSmoktavYNazara = false
					-- end)

					target:EmitSound("Hero_OgreMagi.Ignite.Cast")
				else
					--Timers:CreateTimer(OGRE_SMASH_DELAY, function()
						local targetPos = target:GetAbsOrigin()
						if (not isUnitInHitbox(target, corners)) or (not (targetPos.z >= casterPos.z - OGRE_SMASH_Z_DOWN and targetPos.z <= casterPos.z + OGRE_SMASH_Z_UP)) then
							return
						end
						local velocityMult = OGRE_SMASH_FORCE
						if target.isBanjoHero and target:GetTeam() ~= caster:GetTeam() then
							velocityMult = velocityMult * OGRE_SMASH_ENEMY_HERO_FORCE_MULTIPLIER
						end
						target:AddPhysicsVelocity(dir * velocityMult)
						target:EmitSound("Hero_OgreMagi.Attack")
						local smashCracks = ParticleManager:CreateParticle("particles/units/heroes/hero_nevermore/nevermore_requiemofsouls_ground_cracks.vpcf", PATTACH_CUSTOMORIGIN, target)
						ParticleManager:SetParticleControl(smashCracks, 0, target:GetAbsOrigin())
						-- Remove no bounce you slimy bastards
						target.noBounce = false
						if target == ball.controller then
							-- Give Ogre assists if he hit the ball-carrier.
							caster.assistTimer = GameRules:GetGameTime()
						end
						
						-- Apply daze
						if not Banjoball:IsProjectile(target) and caster:GetTeam() ~= target:GetTeam() then
							target.smashedBy = caster
							caster.spellKey = keys.ability
							keys.ability:ApplyDataDrivenModifier(caster, target, "modifier_ogresmash_daze", {})
						end
					--end)
				end
			end
		end
	end)
end