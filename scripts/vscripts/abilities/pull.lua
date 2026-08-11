function Banjoball:pull( keys )
	local caster = keys.caster
	caster.pullPower = PULL_ACCEL_FORCE

	-- cant cast pull while being ball controller.
	if caster == Ball.unit.controller then
		ShowErrorMsg(caster, "Can't cast Pull as the ball controller")
		return
	end

	-- Preventing the hero from dashing while rooted.
	if caster:HasModifier("modifier_shadowraze_root") then
		keys.ability:StartCooldown(0.1)
		return
	end

	if #GetUnitsInTrueRadius(caster:GetAbsOrigin(), SUPER_SPRINT_NOHERO_RADIUS) > 1 then
		Banjoball:SlamNearby(caster, caster:GetAbsOrigin(), BALL_LIGHTNING_NOHERORADIUS, BALL_LIGHTNING_KNOCKBACK_XY, 0, BALL_LIGHTNING_NOHERORADIUS, function(caster, entity, direction, slam_xy, slam_z)
			if entity ~= caster and entity ~= Ball.unit then return (direction*slam_xy + Vector(0, 0, slam_z)) end
			
			return Vector(0, 0, 0)
		end)
	end
	
	caster.currPullAccel = Vector(0,0,0)
	caster.isUsingPull = true
	local pullToggleAbility = caster:FindAbilityByName("pull_toggle")
	pullToggleAbility:SetActivated(true)
	pullToggleAbility:ToggleAbility()
	SwapAbilities( caster, "pull_break", "pull", ABILITY_SLOT_Q )
	caster.pull_break = caster:FindAbilityByName("pull_break")
	
	local ball = Ball.unit

	-- particle
	caster.pullParticle = ParticleManager:CreateParticle("particles/lina_tether/lina_tether.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(caster.pullParticle, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(caster.pullParticle, 1, ball.particleDummy, 1, "follow_origin", ball.particleDummy:GetAbsOrigin(), true)

	caster:EmitSound("Hero_Wisp.Tether")
	caster:EmitSound("Hero_Wisp.Tether.Target")

	-- Display the time counter particle for the player, above the wisp.
	Banjoball:CreateCountdownTimer( caster, PULL_COUNTDOWN_TIMER_PATH, PULL_MAX_DURATION, function() return true end,nil,true)
	
	caster.pull_start_time = GameRules:GetGameTime()
	
	local pullTime = 0
	caster.pullTimer = Timers:CreateTimer(function()
		pullTime = pullTime + PULL_TICK_RATE
		if pullTime >= PULL_MAX_DURATION or ball.controller == caster or caster:HasModifier("modifier_shadowraze_root") then
			Banjoball:BreakPull(caster)
			return nil
		end
		-- Break from Pull
		if not caster.isUsingPull then
			return nil
		end
		local dirToBall = (ball:GetAbsOrigin() - caster:GetAbsOrigin()):Normalized()
		caster:AddPhysicsVelocity(dirToBall * caster.pullPower)

		return PULL_TICK_RATE
	end)
end

function Banjoball:pull_break( keys )
	Banjoball:BreakPull(keys.caster)
end

function Banjoball:BreakPull( caster )
	if not caster.isUsingPull then return end

	local pullToggleAbility = caster:FindAbilityByName("pull_toggle")
	if pullToggleAbility:GetToggleState() then
		pullToggleAbility:ToggleAbility()
	end
	pullToggleAbility:SetActivated(false)
	caster.isUsingPull = false
	SwapAbilities( caster, "pull", "pull_break", ABILITY_SLOT_Q )
	local pullAbility = caster:FindAbilityByName("pull")

	-- remove particle effect
	ParticleManager:DestroyParticle(caster.pullParticle, false)
	Banjoball:DestroyCountdownTimer(caster)

	caster:EmitSound("Hero_Wisp.Tether.Stop")
	caster:StopSound("Hero_Wisp.Tether")
	
	-- determine cooldown to set
	local timeDiff = GameRules:GetGameTime() - caster.pull_start_time
	local pullCooldown = PULL_MINIMAL_CD
	if timeDiff > 0.3 then pullCooldown = PULL_MINIMAL_CD + timeDiff*PULL_CD_MULT end

	pullAbility:StartCooldown(pullCooldown)
end