blink = class({})
blink_backtrack = blink

function blink:OnSpellStart()
    local caster = self:GetCaster()

	-- Preventing the hero from dashing while rooted.
	if caster:HasModifier("modifier_shadowraze_root") then 
		self:EndCooldown() 
		return 
	end

	caster.SprintMult = 1
	caster.Ball = false
	if caster == Ball.unit.controller then caster.Ball = true end
	
	if self:GetAbilityName() == "blink_backtrack" then
		-- SwapAbilities( caster, "blink", "blink_backtrack", ABILITY_SLOT_Q )
		local blinkAbil = caster:FindAbilityByName("blink")

		local fv = caster:GetForwardVector()
		
		caster.collisionEnabled = false		
		
		DummyCastBlink(caster, caster:GetAbsOrigin(), caster.pos_before_blink )
		caster:SetAbsOrigin(caster.pos_before_blink)
		caster:AddNewModifier(caster,nil,"modifier_force_normal_ball_collision", {duration=FRAME_TIME * 2})
		
		Banjoball:DestroyCountdownTimer(caster)
		ParticleManager:DestroyParticle(caster.blinkParticle, true)
		ParticleManager:DestroyParticle(caster.blinkSmoke, false)
		caster.blinkDummy:ForceKill(true)
		
		Timers:CreateTimer(.03, function()
			caster.collisionEnabled = true
		end)

		caster.SprintMult = 0
		
		return
	end
	caster:EmitSound("Hero_QueenOfPain.ScreamOfPain")

	caster.blink_timer = Timers:CreateTimer(BLINK_WAIT_TIME, function()
		local fv = caster:GetForwardVector()
		
		caster.blinkParticle = ParticleManager:CreateParticle("particles/blink/blink_ghost.vpcf", PATTACH_ABSORIGIN, caster)
		ParticleManager:SetParticleControlEnt(caster.blinkParticle, 1, caster, 1, "follow_origin", caster:GetAbsOrigin(), true)
		local blinkDummy = CreateUnitByName("dummy", caster:GetAbsOrigin(), false, nil, nil, DOTA_TEAM_NEUTRALS)
		caster.blinkDummy = blinkDummy
		caster.blinkSmoke = ParticleManager:CreateParticle("particles/blink/blink_smoke.vpcf", PATTACH_ABSORIGIN, blinkDummy)
		ParticleManager:SetParticleControlEnt(caster.blinkSmoke, 1, blinkDummy, 1, "follow_origin", blinkDummy:GetAbsOrigin(), true)
		
		caster.pos_before_blink = caster:GetAbsOrigin()
		caster.vel_before_blink = caster:GetPhysicsVelocity()
		local newPos = caster:GetAbsOrigin() + BLINK_DISTANCE*fv

		-- Are we blinking to a valid position?
		local checkPos = newPos
		local enemyTeam = GetHeroEnemy(caster)
		if (not IsPointOnField(checkPos)) or GetGoalPointIsWithin(checkPos) == enemyTeam then -- If it's nil the points in the field
			local distTraveled = 0
			newPos = caster:GetAbsOrigin()
			while (distTraveled < BLINK_DISTANCE) do
				checkPos = newPos + 10*fv
				if IsPointOnField(checkPos) and not (GetGoalPointIsWithin(checkPos) == enemyTeam) then
					newPos = checkPos
					distTraveled = distTraveled + 10 -- To be honest, I could just do away with this line and just have it run infinitely until it breaks via the break two lines down
				else
					break
				end
			end
		end

		caster.collisionEnabled = false
		DummyCastBlink(caster, caster:GetAbsOrigin(), newPos )
		caster:SetAbsOrigin(newPos)
		caster:AddNewModifier(caster,nil,"modifier_force_normal_ball_collision", {duration=FRAME_TIME * 2})

		SwapAbilities( caster, "blink_backtrack", "blink", ABILITY_SLOT_Q )
		
		Banjoball:CreateCountdownTimer( caster.blinkDummy, BLINK_COUNTDOWN_TIMER_PATH, BLINK_BACKTRACK_TIME, function() return caster:HasAbility("blink_backtrack") end,nil, true)
		
		Timers:CreateTimer(.03, function()
            caster.collisionEnabled = true
        end)
		
		Timers:CreateTimer(BLINK_BACKTRACK_TIME, function()
			if caster:HasAbility("blink_backtrack") then
				SwapAbilities( caster, "blink", "blink_backtrack", ABILITY_SLOT_Q )
				local blink = caster:FindAbilityByName("blink")
				
				Banjoball:DestroyCountdownTimer(caster)
				ParticleManager:DestroyParticle(caster.blinkSmoke, false)
				caster.blinkDummy:ForceKill(true)

				if caster.Ball then
					blink:EndCooldown()
					blink:StartCooldown(BLINK_SHORT_COOLDOWN)
				end
			end
		end)
	end)
end