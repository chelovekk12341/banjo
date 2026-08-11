tusk_curve_kick = class({})

function tusk_curve_kick:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_tusk/tusk_snowball_impact.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/tuskarr/tusk_ti5_immortal/tusk_ice_shards_projectile_stout_flek.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/ancient_apparition/ancient_apparation_ti8/ancient_ice_vortex_ti8_color_light.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_razor/razor_static_link.vpcf", context)
	PrecacheResource("particle", "particles/ui_mouseactions/range_display.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tusk.vsndevts", context)
end

function tusk_curve_kick:OnSpellStart()
	local caster = self:GetCaster()
	local ball = Ball.unit
	
	-- Break if caster doesn't have the ball
	if caster ~= ball.controller then
		self:EndCooldown()
		ShowErrorMsg(caster, "Необходимо владеть мячом")
		return
	end


	
	ball.curveshot = false
	if caster.tuskCurveshotTrailParticle then 
		ParticleManager:DestroyParticle(caster.tuskCurveshotTrailParticle, true) 
		caster.tuskCurveshotTrailParticle = nil
	end
	if caster.tuskCurveshotTimer then 
		Timers:RemoveTimer(caster.tuskCurveshotTimer) 
		caster.tuskCurveshotTimer = nil
	end
	if caster.tuskRemainingTimer then 
		Timers:RemoveTimer(caster.tuskRemainingTimer) 
		caster.tuskRemainingTimer = nil
	end
	
	local ballPos = ball:GetAbsOrigin()
	local target = self:GetCursorPosition()
	target = Vector(target.x, target.y, ballPos.z)
	local direction = (target-ballPos):Normalized()
	local dir_forward = caster:GetForwardVector():Normalized()
	
	-- Determine curve direction (rotation: -1 for left curve, 1 for right curve)
	local cross = dir_forward.x * direction.y - dir_forward.y * direction.x
	local rotation = -1
	if cross > 0 then
		rotation = 1
	end
	
	direction = (RotatePosition(direction, QAngle(0, rotation * CURVESHOT_STARTING_ANGLE, 0), Vector(0,0,0))):Normalized()
	
	-- Create the custom ice trail from Tusk's Ti5 Immortal (following the ball in 3D)
	caster.tuskCurveshotTrailParticle = ParticleManager:CreateParticle( "particles/econ/items/tuskarr/tusk_ti5_immortal/tusk_ice_shards_projectile_stout_flek.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy )
	ParticleManager:SetParticleControl( caster.tuskCurveshotTrailParticle, 0, ballPos )
	ParticleManager:SetParticleControlEnt( caster.tuskCurveshotTrailParticle, 3, ball.particleDummy, PATTACH_ABSORIGIN_FOLLOW, "", ball.particleDummy:GetAbsOrigin(), true )
	
	-- Walrus Kick Particle Effect (Snowball explosion)
	local punch_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_tusk/tusk_snowball_impact.vpcf", PATTACH_CUSTOMORIGIN, caster)
	ParticleManager:SetParticleControl(punch_pfx, 0, ballPos)
	ParticleManager:ReleaseParticleIndex(punch_pfx)
	
	-- Animation and Sounds
	pcall(function()
		caster:FadeGesture(ACT_DOTA_ATTACK)
		caster:StartGesture(ACT_DOTA_CAST_ABILITY_3)
	end)
	
	caster:EmitSound("Hero_Tusk.WalrusKick.Cast")
	ball:EmitSound("Hero_Tusk.WalrusKick.Target")
	
	ball.curveshot = true

	local yolo = CURVESHOT_YOLO_FACTOR

	if caster:GetAbsOrigin().z > GROUND_Z then
		yolo = yolo * KICK_AIR_MULT
	end

	-- Reduced both horizontal speed and height by 20%
	-- Horizontal: CURVESHOT_VELOCITY * 0.8
	-- Vertical: CROSS_BASE_VEL_Z * 2 * 0.8 = CROSS_BASE_VEL_Z * 1.6
	local kickVelocityXY = CURVESHOT_VELOCITY * 0.8
	local kickVelocityZ = CROSS_BASE_VEL_Z * 1.6

	-- Рассчитаем и нарисуем траекторию полета мяча (3D-симуляция)
	local sim_pos = ballPos
	local sim_vel = direction * kickVelocityXY + Vector(0, 0, kickVelocityZ)
	local sim_rot = rotation * -1
	local sim_curveshotTime = CURVESHOT_TIME
	local sim_yolo = yolo

	local points = {}
	table.insert(points, sim_pos)

	-- Моделируем движение на 45 шагов вперед (1.5 сек)
	local dt = 1 / 30
	for i = 1, 45 do
		if sim_curveshotTime > 0 then
			local ballSpeed = sim_vel:Length() -- 3D-скорость мяча
			local dampening = ballSpeed / kickVelocityXY
			
			local rot_dir = RotatePosition(sim_vel, QAngle(0, sim_rot * CURVESHOT_ROTATION, 0), Vector(0,0,0))
			rot_dir.z = 0
			rot_dir = rot_dir:Normalized()

			local rot_force = CURVESHOT_ROTATION_FORCE
			local sim_yolo_add = sim_yolo
			if sim_curveshotTime <= CURVESHOT_TIME * TIME_CURV then
				rot_force = CURVESHOT_ROTATION_FORCE_MIN
				sim_yolo_add = 0
			end

			local curvedVel = (sim_vel + (rot_dir * rot_force * dampening)):Normalized() * (ballSpeed + sim_yolo_add)
			sim_vel = Vector(curvedVel.x, curvedVel.y, sim_vel.z)
			sim_curveshotTime = sim_curveshotTime - 0.03
		end

		-- Физика трения (в physics.lua применяется только к горизонтальной скорости и без умножения на dt)
		local speed = Vector(sim_vel.x, sim_vel.y, 0):Length()
		if speed > 0 then
			local friction = AIR_FRICTION
			if (i * dt) <= KICK_NO_FRICTION_DURATION then
				friction = NO_FRICTION
			elseif sim_pos.z <= GROUND_FRICTION_COORDINATE then
				friction = BALL_FRICTION
			end
			sim_vel.x = sim_vel.x * (1 - friction)
			sim_vel.y = sim_vel.y * (1 - friction)
		end

		-- Физика гравитации (в kick.lua изменение гравитации закомментировано, всегда действует GRAVITY)
		local current_gravity = GRAVITY.z

		-- В physics.lua сначала обновляются координаты, затем скорость
		sim_pos = sim_pos + sim_vel * dt
		sim_vel.z = sim_vel.z + current_gravity * dt

		if sim_pos.z < GROUND_Z then
			sim_pos.z = GROUND_Z
			table.insert(points, sim_pos)
			break
		end

		if not IsPointOnField(sim_pos) then
			table.insert(points, ClosestPointOnField(sim_pos))
			break
		end

		table.insert(points, sim_pos)
	end

	-- Отрисовка траектории по высоте полета мяча
	local line_particles = {}
	for i = 1, #points - 1 do
		local pfx = ParticleManager:CreateParticle("particles/econ/items/ancient_apparition/ancient_apparation_ti8/ancient_ice_vortex_ti8_color_light.vpcf", PATTACH_WORLDORIGIN, nil)
		ParticleManager:SetParticleControl(pfx, 0, points[i])
		ParticleManager:SetParticleControl(pfx, 1, points[i+1])
		table.insert(line_particles, pfx)
	end

	-- Метка приземления на земле
	local land_pos = points[#points]
	land_pos.z = GROUND_Z
	-- local land_pfx = ParticleManager:CreateParticle("particles/econ/items/tuskarr/tusk_ti9_immortal/tusk_ti9_walruspunch_start_water.vpcf", PATTACH_WORLDORIGIN, nil)
	-- ParticleManager:SetParticleControl(land_pfx, 0, land_pos)
	-- ParticleManager:SetParticleControl(land_pfx, 1, Vector(100, 0, 0))
	
	-- local land_pfx2 = ParticleManager:CreateParticle("particles/econ/items/tuskarr/tusk_ti9_immortal/tusk_ti9_golden_walruspunch_start_rocks.vpcf", PATTACH_WORLDORIGIN, nil)
	-- ParticleManager:SetParticleControl(land_pfx2, 0, land_pos)
	-- ParticleManager:SetParticleControl(land_pfx2, 1, Vector(100, 0, 0))




	-- Удаляем все эффекты через 1.2 сек
	Timers:CreateTimer(1.2, function()
		for _, pfx in ipairs(line_particles) do
			ParticleManager:DestroyParticle(pfx, true)
			ParticleManager:ReleaseParticleIndex(pfx)
		end
		-- if land_pfx then
		-- 	ParticleManager:DestroyParticle(land_pfx, true)
		-- 	ParticleManager:ReleaseParticleIndex(land_pfx)
		-- end
	end)

	KickBall({keys = { target_points = { target } }, hero = caster, xy_velocity = kickVelocityXY, z_velocity = kickVelocityZ, type = 4, direction = direction}, rotation)

	rotation = rotation * -1 -- Reverse rotation for actual curveshot logic in timer
	
	local curveshotTime = CURVESHOT_TIME
	local trailRef = caster.tuskCurveshotTrailParticle

	-- Curveshot Logic
	caster.tuskCurveshotTimer = Timers:CreateTimer(function()

		local ballVel = ball:GetPhysicsVelocity()
		local ballSpeed = ballVel:Length()
		local dampening = ballSpeed / kickVelocityXY
		
		if not ball.curveshot or curveshotTime <= 0 then
			ball.curveshot = false
			
			if ball.controller then
				if trailRef then ParticleManager:DestroyParticle(trailRef, true) end
			else
				ball.curveshot = true
				local partDestroyTime = CURVESHOT_ADDITIONAL_PARTICLE_TIME
				
				caster.tuskRemainingTimer = Timers:CreateTimer(function()

					if not ball.curveshot or partDestroyTime <= 0 then
						if trailRef then ParticleManager:DestroyParticle(trailRef, true) end
						ball.curveshot = false
						return nil
					end
					
					partDestroyTime = partDestroyTime - .03
					return .03
				end)
			end
			return nil
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
end
