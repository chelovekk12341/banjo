function Banjoball:OnMyPhysicsFrame( unit )
	if not unit then return end
	
	local unitPos = unit:GetAbsOrigin()
	unit.currPos = unitPos
	local currVel = unit:GetPhysicsVelocity()
	local ball = Ball.unit

	if unit.isBall then
		local height = unitPos.z - GroundZ
		if height > 5000 then
			unit:SetNavCollisionType(PHYSICS_NAV_NOTHING)
		else
			unit:SetNavCollisionType(PHYSICS_NAV_BOUNCE)
		end
	end
	local len3dSq = Length3DSq(currVel)
	local currTime = GameRules:GetGameTime()
	unit.velocityMagnitude = len3dSq
	unit.vm = unit.velocityMagnitude
	local inAir = unitPos.z > (GroundZ+ABOVE_GROUND_Z)
	if unit.highestPosition == nil then unit.highestPosition = 0 end
	if unit.bounceCount == nil then unit.bounceCount = 0 end

	-- do above ground think logic
	if unit.isAboveGround then
		if not unit.dontChangeFriction and unit:GetPhysicsFriction() ~= AIR_FRICTION then
			if  unit:GetAbsOrigin().z > GROUND_FRICTION_COORDINATE then unit:SetPhysicsFriction(AIR_FRICTION)
			else 
				if unit.isBall then
					unit:SetPhysicsFriction(BALL_FRICTION)
				else
					unit:SetPhysicsFriction(GROUND_FRICTION)
				end
			end
		end

		if not unit:HasModifier("modifier_flail_passive") and not unit.noBounce and ball.controller ~= unit and not Banjoball:IsProjectile(unit) then
			GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, unit, "modifier_flail_passive", {})
		end

		if unitPos.z > unit.highestPosition then unit.highestPosition = unitPos.z end

		if unit.isBall then
			if ball.ballShadow then
				if unit:GetAbsOrigin().z < GROUND_Z + BALL_SHADOW_Z then
					ParticleManager:DestroyParticle(ball.ballShadow, true)
					ball.ballShadow = nil
				end
			elseif ball:GetAbsOrigin().z > GROUND_Z + BALL_SHADOW_Z then
				ball.ballShadow = ParticleManager:CreateParticle("particles/ball/ball_shadow.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
			end
		end
	else
		if not unit.dontChangeFriction then 
			if unit.isBall then
				unit:SetPhysicsFriction(BALL_FRICTION)
			else
				unit:SetPhysicsFriction(GROUND_FRICTION)
			end
		end

		if unit:HasModifier("modifier_flail_passive") then
			unit:RemoveModifierByName("modifier_flail_passive")
		end
		
		if unit.isBall then
			if unit.ballShadow then
				ParticleManager:DestroyParticle(unit.ballShadow, true)
				unit.ballShadow = nil
			end
		end
		
		-- Sliding threshold
		if currVel:Length() <= MINIMAL_VELOCITY then
			unit:SetPhysicsVelocity(Vector(0,0,0))
		end
	end

	if inAir and not unit.isAboveGround then
		unit.isAboveGround = true
		unit:SetGroundBehavior(PHYSICS_GROUND_ABOVE)

		-- if hero, set the modifier up
		if not unit:HasModifier("modifier_rooted_passive") then
			if unit ~= ball then
				GlobalDummy.rooted_passive:ApplyDataDrivenModifier(GlobalDummy, unit, "modifier_rooted_passive", {})
			end
		end
	elseif not inAir and unit.isAboveGround then
		-- bounce takes priority
		-- determine if bounce should occur.
		local bounceOccured = false
		
		if unit.highestPosition > BOUNCE_VEL_THRESHOLD and not unit.noBounce and unit.bounceCount < 2 then
			currVel = Vector(currVel.x*BOUNCE_MULT_XY, currVel.y*BOUNCE_MULT_XY, math.min(BOUNCE_MAX_Z, unit.highestPosition*BOUNCE_MULT_Z) )
			-- print(unit.highestPosition, "", unit.bounceCount)
			unit:SetPhysicsVelocity(currVel)

			bounceOccured = true
			unit.bounceCount = unit.bounceCount + 1

			-- play bounce sound
			if unit == ball and (currTime-ball.lastBounceTime > .3) and not ball.controller then
				ball:EmitSound("Bounce" .. RandomInt(1, NUM_BOUNCE_SOUNDS))
				ball.lastBounceTime = currTime
			elseif unit ~= ball then
				TryPlayCracks(unit)
			end
		end
		unit.highestPosition = 0

		if unit.noBounce then
			-- for slark
			if unit.isUsingJump then
				EmitSoundAtPosition("Hero_Slark.Pounce.Impact", unit)
				TryPlayCracks(unit,nil,nil,nil,true)
				unit.isUsingJump = false
				unit.kickPower = KICK_VELOCITY
			end
         
			unit.noBounce = false
		end

		if not bounceOccured then
			unit.isAboveGround = false
			unit.bounceCount = 0

			-- remove the modifier
			if unit:HasModifier("modifier_rooted_passive") then
				unit:RemoveModifierByName("modifier_rooted_passive")
			end
			unit:SetGroundBehavior(PHYSICS_GROUND_ABOVE)
		end
	end

	if unit.isBanjoHero then
		local hero = unit

		-- we need to handle player-player collisions, so players don't get stuck.
		-- Phase them if they're in the collision radius of a player, unphase them otherwise.
		local pp_collision = false
		for i2=0,9 do
			local hero2 = hero.pp_collisions[i2]

			local in_collision_radius = false
			if hero2 and not hero2:IsNull() then
				in_collision_radius = (hero2:GetAbsOrigin()-hero:GetAbsOrigin()):Length() <= (hero:GetPaddedCollisionRadius()+20)
			end

			if in_collision_radius then
				pp_collision = true
				break
			end
		end
	end
end

function TryPlayCracks( ... )
	local t = {...}
	local unit = t[1]
	local location = t[2]
	local checkFence = t[3]
	local bPlayerPlayerColl = t[4]
	local noSound = t[5]
	local ground_thresh = 30
	local currTime = GameRules:GetGameTime()
	local unitPos = unit:GetAbsOrigin()
	local soundPlayed = false

	if unit.velocityMagnitude > CrackThreshSq and (not unit.lastCrackTime or currTime-unit.lastCrackTime > .3) then
		--if unitPos.z < (GroundZ + ground_thresh) then
		if not location then
			ParticleManager:CreateParticle("particles/units/heroes/hero_nevermore/nevermore_requiemofsouls_ground_cracks.vpcf", PATTACH_ABSORIGIN, unit)
		else
			ParticleManager:CreateParticle("particles/units/heroes/hero_nevermore/nevermore_requiemofsouls_ground_cracks.vpcf", PATTACH_CUSTOMORIGIN, unit)
			ParticleManager:SetParticleControl(p, 0, location)
		end
		--end

		if checkFence then
			if unit.velocityMagnitude > 1.5*CrackThreshSq then
				EmitSoundAtPosition("Fence_Heavy", unitPos)
			else
				EmitSoundAtPosition("Fence_Light", unitPos)
			end
			soundPlayed = true
		end

		if not soundPlayed and not noSound then
			--local impactSound = "ThunderClapCaster"
			--local impactSound = "Impact_Medium" .. RandomInt(1, NumMediumImpactSounds)
			local impactSound = "Impact_Heavy" .. RandomInt(1, NumHeavyImpactSounds)
			if unit.velocityMagnitude > CrackThreshSq*3 then
				impactSound = "Impact_Giant" .. RandomInt(1, NumGiantImpactSounds)
			elseif unit.velocityMagnitude > CrackThreshSq*2 then
				--impactSound = "Impact_Heavy" .. RandomInt(1, NumHeavyImpactSounds)
				impactSound = "Impact_Giant" .. RandomInt(1, NumGiantImpactSounds)
			end
			if bPlayerPlayerColl then
				--impactSound = "Impact_Heavy" .. RandomInt(1, NumHeavyImpactSounds)
				impactSound = "ThunderClapCaster"
				if unit.isUsingPull then
					impactSound = "Wisp_Collision"
				end
				PlayCentaurBloodEffect(unit)
			end
			--print("sound played: " .. impactSound)
			EmitSoundAtPosition(impactSound, unitPos)
		end
		unit.lastCrackTime = currTime
	end
end

function Banjoball:SetupPersonalColliders(hero)
	

	local coll = hero:AddColliderFromProfile("momentum")
	coll.radius = MAX_COLLISION_RADIUS
	coll.filer = self.colliderFilter
	coll.elasticity = 1
	coll.test = function(self, collider, collided)
		local ball = Ball.unit
		local dist = (hero:GetAbsOrigin() - collided:GetAbsOrigin()):Length()
		
		if not IsPhysicsUnit(collided) then return false end
		
		-- Projectile Functionality: technically treat this as a collision, but return false to remove momentum calc
		if Banjoball:IsProjectile(collided) then
			local calcMomentum = false
			if Banjoball:IsProjectileActive(collided) and ( collided.affectcaster or hero ~= collided.caster) and collided.__projectileCollisionRadius >= dist then
				calcMomentum = collided.onProjectileCollision(hero)
			end
			return calcMomentum
		elseif Banjoball:IsProjectile(hero) then
			return false
		end
		
		local collRadius = HERO_DEFAULT_RADIUS * 2
		if hero.isBanjoHero and collided.isBanjoHero then
			collRadius = hero.collisionRadius + collided.collisionRadius
		end
		
		local passTest = hero.collisionEnabled and collided.collisionEnabled
		if passTest then
			if (hero.HasModifier and hero:HasModifier("modifier_spectre_passive")) or 
			   (collided.HasModifier and collided:HasModifier("modifier_spectre_passive")) then
				passTest = false
			end
		end
		if collRadius < dist or not passTest then return false end
		passTest = false
		
		-- Cut every non hero related collision out at this point
		if collided.isBanjoHero then
			local currTime = GameRules:GetGameTime()
			if hero.lastPPCollisionTime + PP_COLLISION_GRACE_PERIOD < currTime then
				hero.pp_collisions[collided:GetPlayerID()] = collided
				hero.lastPPCollisionTime = GameRules:GetGameTime()
				collided.lastPPCollisionTime = GameRules:GetGameTime()
				local collision_threshold_squared = PP_COLLISION_THRESHOLD * PP_COLLISION_THRESHOLD
				
				if hero.isUsingTackle or collided.isUsingTackle then
					-- End Tackle
					local heroPushDir = Vector(0,0,0)
					local collidedPushDir = Vector(0,0,0)
					if hero.isUsingTackle then
						collidedPushDir = (collided:GetAbsOrigin() - hero:GetAbsOrigin()):Normalized()					
						hero.tackle_end_time = GameRules:GetGameTime()
						hero.isUsingTackle = false
					end
					if collided.isUsingTackle then
						heroPushDir = (hero:GetAbsOrigin() - collided:GetAbsOrigin()):Normalized()
						collided.tackle_end_time = GameRules:GetGameTime()
						collided.isUsingTackle = false
					end
					hero:AddPhysicsVelocity(heroPushDir*CHASE_PUSH)
					collided:AddPhysicsVelocity(collidedPushDir*CHASE_PUSH)
				elseif hero.isUsingPowerdash or collided.isUsingPowerdash then
					collided.isUsingPowerdash = false
					hero.isUsingPowerdash = false
				elseif hero.vm > collision_threshold_squared or collided.vm > collision_threshold_squared then
					if hero.vm > CrackThreshSq then
						TryPlayCracks(hero, nil, nil, true)
					end

					passTest = true

					if hero.isUsingJump and not collided.isAboveGround then
						passTest = false
					end
				elseif hero:GetPhysicsVelocity():Length() ~= 0 or collided:GetPhysicsVelocity():Length() ~= 0 then
					passTest = true
				end
			end
		end

		return passTest
	end

	hero.personal_collider = coll
end

function Banjoball:OnGridNavBounce( unit, normal )
	local ball = Ball.unit
	local isBall = unit == ball

	-- done with passTest logic. move onto parsing that logic, add sounds, effects, etc.
	if isBall and not ball.controller then
		unit:EmitSound("Bounce" .. RandomInt(1, NUM_BOUNCE_SOUNDS))
	
	elseif unit.isBanjoHero then
		TryPlayCracks(unit, nil, true)

		-- If Ogre Dazed, kill momentum and reapply ogre daze
		if unit:HasModifier("modifier_ogresmash_daze") then
			Timers:CreateTimer(.03, function()
				unit:SetPhysicsVelocity(Vector(0,0,0))
			end)
			unit.smashedBy.spellKey:ApplyDataDrivenModifier(unit.smashedBy, unit, "modifier_ogresmash_daze_wall", {})
		end
	end

	if unit.isAboveGround then
		Banjoball:PlayReflectParticle(unit)
	end

end

function Banjoball:OnPreGridNavBounce( unit, normal )
end