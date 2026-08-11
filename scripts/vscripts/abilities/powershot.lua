function Banjoball:powershot( keys )
	local caster = keys.caster
	local ball = Ball.unit
	local target = Vector(keys.target_points[1].x, keys.target_points[1].y, caster:GetAbsOrigin().z)

	caster:AddNewModifier(caster,nil,"modifier_powershot", {duration = 99999}) 
	caster.isChargingPowershot = true
	local kick = caster:FindAbilityByName("kick_ball")
	kick:StartCooldown(200) -- Just to gray it out for now
	local sprint = nil
	if caster.surgeOn then
		caster:CastAbilityNoTarget(caster:FindAbilityByName("surge_break"), 0)
	end
	Timers:CreateTimer(.03, function()
		sprint = caster:FindAbilityByName("surge")
		sprint:StartCooldown(200) -- Just to gray it out for now
	end)
	
	Banjoball:ShowCastBar(caster, POWERSHOT_CASTBAR)
	
	Timers:CreateTimer(POWERSHOT_CHANNEL_TIME, function()
		-- Break if caster has cancelled powershot
		if not caster.isChargingPowershot then return end
		
		self:powershotCancel(caster)
		Banjoball:HideCastBar(caster)
		
		-- Break if caster doesn't have the ball
		if caster ~= ball.controller then
			PlayAnimation("act_dota_idle", caster)
			return
		end
		
		local ballPos = ball:GetAbsOrigin()
		
		PlayAnimation("act_dota_cast_deafening_blast", caster)
		
		ball.controller:EmitSound("Hero_VengefulSpirit.MagicMissile")

		KickBall({keys = keys, hero = caster, xy_velocity = POWERSHOT_VELOCITY, z_velocity = 0, type = 3, friction = true})
		
		ball.dontChangeFriction = true
		ball:SetPhysicsFriction(NO_FRICTION)

		powershotTimer_a = Timers:CreateTimer(POWERSHOT_DURATION_MIN, function()
				ball:SetPhysicsFriction(BALL_FRICTION)

				powershotTimer_b = Timers:CreateTimer(POWERSHOT_DURATION_MAX, function()
						Banjoball:PowerStop()
					end)
			end)

		ball.powershot_particle = ParticleManager:CreateParticle("particles/powershot/spirit_breaker_charge.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
		ball.affectedByPowershot = true
	end)
end

function Banjoball:powershotCancel( hero )
	if not hero.isChargingPowershot then return end
	hero.isChargingPowershot = false
	
	PlayAnimation("act_dota_idle", hero)
	
	if hero:HasModifier("modifier_powershot") then
		hero:RemoveModifierByName("modifier_powershot")
	end
	
	local kick = hero:FindAbilityByName("kick_ball")
	kick:EndCooldown()
	local sprint = hero:FindAbilityByName("surge")
	sprint:EndCooldown()
	
	Banjoball:HideCastBar(hero)
end

function Banjoball:PowerStop()
	local ball = Ball.unit
	ball.dontChangeFriction = false
	ball:SetPhysicsFriction(BALL_FRICTION)
	ParticleManager:DestroyParticle(ball.powershot_particle, false)
	ball.pshotInvoke = false
	ball.affectedByPowershot = false
	if powershotTimer_a then Timers:RemoveTimer(powershotTimer_a) end
	if powershotTimer_b then Timers:RemoveTimer(powershotTimer_b) end
end