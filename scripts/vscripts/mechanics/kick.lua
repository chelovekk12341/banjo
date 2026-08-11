-- This function is called when the "KICK" ability is used.
function Banjoball:kick_ball( keys )
	local ball = Ball.unit
	local caster = keys.caster

	-- Preventing usage without the ball.
	if caster ~= ball.controller then return end

	caster:StartGesture(ACT_DOTA_ATTACK)

	-- Kicking the ball.
	KickBall({keys = keys, hero = caster, xy_velocity = caster.kickPower, z_velocity = caster.kickZ, type = 1, gravity = KICK_GRAVITY})
	ball:EmitSound( "Kick".. RandomInt(1, NUM_KICK_SOUNDS) )
end

--[[ 
	This function implements kick logic.
		▪ keys: something with information about the target point;
		▪ hero: the kicker;
		▪ xy & z velocities: the ball's kick force;
		▪ type: the self-usage logic, where 1 means kicking backwards, 2 means kicking above themselves, and 3 means kicking forward.
]]
function KickBall(info, rotation)
	local keys = info.keys
	local hero = info.hero
	local xy_velocity = info.xy_velocity
	local z_velocity = info.z_velocity
	local type = info.type

	local ball = Ball.unit
	local ballPos = ball:GetAbsOrigin()
	local heroPos = hero:GetAbsOrigin()
	local direction = info.direction or Vector(keys.target_points[1].x - ballPos.x, keys.target_points[1].y - ballPos.y, 0):Normalized()

	if ball.glyphed then
		ball.glyphed = false
		if ball.glyphParticle then ParticleManager:DestroyParticle(ball.glyphParticle, false) end
		if ball.glyphTimer then Timers:RemoveTimer(ball.glyphTimer) end
	end

	-- Ensuring that kicking behind the goal line doesn't count as a goal (using the hero's position rather than the ball's, because it looks better).
	if heroPos.x < R_SCORE then ball.kickedFromRadiantGoal = true
	elseif heroPos.x > D_SCORE then ball.kickedFromDireGoal = true end

	-- Releasing the ball from the hero's control.
	Banjoball:RegisterBallHit(hero)
	ball.controller = nil
	ball.highestPosition = heroPos.z
	ball.invisTime = 0

	-- Если мяч был скрыт Dissimilate, делаем его видимым, так как он покинул владение героя
	if ball.dissimilate_hidden then
		ball:RemoveNoDraw()
		if ball.particleDummy then
			ball.particleDummy:RemoveNoDraw()
		end
		ball.dissimilate_hidden = nil

		local modifier = hero:FindModifierByName("modifier_void_spirit_dissimilate_oow")
		if modifier then
			modifier.had_ball = nil
		end
	end

	-- Overriding the ball's position to prevent it from raising too high in the air when it's kicked immediately; and putting the ball back on the field if the caster pushed it into the wall.
	ball:SetAbsOrigin( Vector(ballPos.x, ballPos.y, heroPos.z) )
	if not IsPointOnField(ballPos) then ball:SetAbsOrigin( ClosestPointOnField(ballPos) ) end

	-- Setting XY and Z vectors according to a situation (giving less force for the ball in the air, and changing XY direction if the player clicked on the hero's model).
	if (heroPos - keys.target_points[1]):Length() <= KICK_HERO_RADIUS or (ballPos - keys.target_points[1]):Length() <= KICK_BALL_RADIUS then
		if type == 1 then
			direction = -1 * hero:GetForwardVector():Normalized()
			z_velocity = 0
		elseif type == 2 then direction = 0 xy_velocity = 0 z_velocity = 1000
		elseif type == 3 then direction = hero:GetForwardVector():Normalized()
		elseif type == 4 then direction = (RotatePosition( -1 * hero:GetForwardVector():Normalized(), QAngle(0, rotation * CURVESHOT_STARTING_ANGLE, 0), Vector(0,0,0))):Normalized() end
	end

	-- Reducing gravity for a little bit to make the ball travel with a good-looking trajectory.
	ball:SetPhysicsAcceleration(GRAVITY)
	if info.gravity then
		-- ball:SetPhysicsAcceleration(info.gravity)
		-- Timers:CreateTimer(GRAVITY_CHANGE_TIME, function()
			-- ball:SetPhysicsAcceleration(GRAVITY)
		-- end)
	end
	-- Removing friction from all kicking abilities to make the trajectory good.
	if not info.friction then
		ball.dontChangeFriction = true
		ball:SetPhysicsFriction(NO_FRICTION)
			
		Timers:CreateTimer(KICK_NO_FRICTION_DURATION, function()
			ball:SetPhysicsFriction(BALL_FRICTION)
			ball.dontChangeFriction = false
		end)
	end
	
	-- Overriding the ball's velocity (instead of adding) to prevent the ball from accelerating when it's kicked immediately.
	ball:SetPhysicsVelocity( direction * xy_velocity + Vector(0, 0, z_velocity) )

	-- Printing the ball's velocity for debugging purposes.
		-- local iterator = 0
		-- Timers:CreateTimer(function()
		-- 	if ball.vVelocity:Length()*30 <= 1 or iterator > 30 then return end

		-- 	iterator = iterator + 1
		-- 	local length = Vector(ball.vVelocity.x, ball.vVelocity.y, 0):Length()
		-- 	print( string.format( "Velocity = %d", length*30 ), "at", string.format("%.2f", GameRules:GetGameTime()), "", iterator )

		-- 	return FRAME_TIME
		-- end)
end