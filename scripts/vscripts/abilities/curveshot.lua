curveshot = class({})
curveshot_left = curveshot
curveshot_right = curveshot

function curveshot:OnSpellStart()
    local caster = self:GetCaster()
	local ball = Ball.unit
	
	-- Break if caster doesn't have the ball
	if caster ~= ball.controller then return end
	
	ball.curveshot = false
	if curveshotParticle then ParticleManager:DestroyParticle(curveshotParticle, true) end
	if curveshotTrailParticle then ParticleManager:DestroyParticle(curveshotTrailParticle, true) end
	if caster.curveshotTimer then Timers:RemoveTimer(caster.curveshotTimer) end
	if caster.remainingTimer then Timers:RemoveTimer(caster.remainingTimer) end
	
	local ballPos = ball:GetAbsOrigin()
	local target = self:GetCursorPosition()
	target = Vector(target.x, target.y, ballPos.z)
	local direction = (target-ballPos):Normalized()
	
	local rotation = -1 -- Left
	if self:GetAbilityName() == "curveshot_right" then
		rotation = 1 -- Right
	end
	direction = (RotatePosition(direction, QAngle(0, rotation * CURVESHOT_STARTING_ANGLE, 0), Vector(0,0,0))):Normalized()
	
	curveshotParticle = ParticleManager:CreateParticle( "particles/curveshot/curveshot_ball.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy )
	ParticleManager:SetParticleControl( curveshotParticle, 0, ballPos)
	ParticleManager:SetParticleControlEnt( curveshotParticle, 1, ball.particleDummy, PATTACH_ABSORIGIN_FOLLOW, "", ball.particleDummy:GetAbsOrigin(), true )
	curveshotTrailParticle = ParticleManager:CreateParticle( "particles/curveshot/curveshot_trail.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy )
	ParticleManager:SetParticleControl( curveshotTrailParticle, 0, ballPos )
	ParticleManager:SetParticleControlEnt( curveshotTrailParticle, 3, ball.particleDummy, PATTACH_ABSORIGIN_FOLLOW, "", ball.particleDummy:GetAbsOrigin(), true )
	
	ball.curveshot = true
	ball:EmitSound("Hero_StormSpirit.ElectricVortexCast")

	local yolo = CURVESHOT_YOLO_FACTOR

	if  caster:GetAbsOrigin().z > GROUND_Z then
		yolo = yolo * KICK_AIR_MULT
	end

	KickBall({keys = { target_points = { target } }, hero = caster, xy_velocity = CURVESHOT_VELOCITY, z_velocity = 0, type = 4, direction = direction}, rotation)
	rotation = rotation * -1 -- Reverse rotation for actual curveshot
	
	local curveshotTime = CURVESHOT_TIME

	-- Curveshot Logic
	caster.curveshotTimer = Timers:CreateTimer(function()
		local ballVel = ball:GetPhysicsVelocity()
		local ballSpeed = ballVel:Length()
		local dampening = ballSpeed / CURVESHOT_VELOCITY
		
		if not ball.curveshot or curveshotTime <= 0 then
			
			ball.curveshot = false
			
			if ball.controller then
				ParticleManager:DestroyParticle(curveshotParticle, true)
				ParticleManager:DestroyParticle(curveshotTrailParticle, true)
			else
				ball.curveshot = true
				local partDestroyTime = CURVESHOT_ADDITIONAL_PARTICLE_TIME
				
				-- YOLO TIMER
				caster.remainingTimer = Timers:CreateTimer(function()
					if not ball.curveshot or partDestroyTime <= 0 then
						ParticleManager:DestroyParticle(curveshotParticle, true)
						ParticleManager:DestroyParticle(curveshotTrailParticle, true)
						ball.curveshot = false
						return
					end
					
					partDestroyTime = partDestroyTime - .03
					return .03
				end)
			end
			return
		end
		
		direction = (RotatePosition(ballVel, QAngle(0, rotation * CURVESHOT_ROTATION, 0), Vector(0,0,0)))
		direction.z = 0
		direction = direction:Normalized()
		
		ball:AddPhysicsVelocity(Vector(-ballVel.x, -ballVel.y, 0))
		local curvedVel = (ballVel + (direction*CURVESHOT_ROTATION_FORCE * dampening)):Normalized() * (ballSpeed + yolo)
		if curveshotTime <= CURVESHOT_TIME*TIME_CURV then
			curvedVel = (ballVel + (direction*CURVESHOT_ROTATION_FORCE_MIN * dampening)):Normalized() * (ballSpeed)
		end
		ball:AddPhysicsVelocity(Vector(curvedVel.x, curvedVel.y, 0))

		curveshotTime = curveshotTime - .03
		
		return .03
	end)

	ball.curveshotHero = caster
end