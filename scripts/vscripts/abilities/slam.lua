slam = class({})

-- This function is called whenever "slam" ability is used.
function slam:OnSpellStart()
	local caster = self:GetCaster()
	local ball = Ball.unit

	-- Preventing usage while being in the air.
	if caster:GetAbsOrigin().z > ABOVE_GROUND_Z_CONST then
		self:EndCooldown()
		self:StartCooldown(0.3)
		return
	end

	caster:StartGestureWithPlaybackRate(ACT_DOTA_CAST_ABILITY_4, 0.6)
	
	local kick_ball_ability = caster:FindAbilityByName("kick_ball")
	if kick_ball_ability then
		kick_ball_ability:StartCooldown(0.1)
	end

	Timers:CreateTimer(0.1, function()
		local affected = Banjoball:SlamNearby(caster, caster:GetAbsOrigin(), SLAM_RADIUS, SLAM_XY, SLAM_Z, nil, function(caster, entity, direction, slam_xy, slam_z)
			-- Не работает на вражеского героя в воротах
			if entity:GetTeam() ~= caster:GetTeam() and GetGoalPointIsWithin(entity:GetAbsOrigin()) ~= nil then
				return Vector(0, 0, 0)
			end

			-- Preventing slamming of the caster, the ball and any units in the air.
			if entity:GetAbsOrigin().z <= ABOVE_GROUND_Z_CONST and entity:GetPhysicsVelocity().z*30 <= 200 and entity ~= caster and entity ~= Ball.unit then 
				return ( direction*slam_xy + Vector(0, 0, slam_z) ) 
			end
			
			return Vector(0, 0, 0)
		end)
		
		local heroPos = caster:GetAbsOrigin()
		local ballPos = ball:GetAbsOrigin()
		local enemyTeam = GetHeroEnemy(caster)
		local ballInEnemyGoal = GetGoalPointIsWithin(ballPos) == enemyTeam

		if not ballInEnemyGoal and ( ballPos - heroPos ):Length() <= SLAMSHOT_RADIUS and ballPos.z <= SLAMSHOT_HEIGHT and not ball.controller then
			local distToBall = (ball:GetAbsOrigin() - caster:GetAbsOrigin()):Length()
			if distToBall <= SLAMSHOT_RADIUS then
				if ball.lastMovedBy and ball.lastMovedBy.turnovers and caster:GetTeam() ~= ball.lastMovedBy:GetTeam() then
					caster.steals = caster.steals + 1
					ball.lastMovedBy.turnovers = ball.lastMovedBy.turnovers + 1
					Banjoball:text_particle( {caster=caster, stolen=true} )
				end
				ball.lastMovedBy = caster

				local dirToBall = (ball:GetAbsOrigin() - caster:GetAbsOrigin()):Normalized()
				ball:SetPhysicsVelocity((dirToBall*SLAM_SHOT_XY + Vector(0,0,SLAM_SHOT_Z)))
				ball.slammed = true
				ball.goalIgnore = false
				
				if ball.affectedByPowershot == true then 
					Banjoball:PowerStop()
				end
				Timers:CreateTimer(function()
					if ball:GetPhysicsVelocity():Length() < SLAMSHOT_FIRE_THRESHOLD then
						ball.slammed = false
						return
					end
					
					return FRAME_TIME
				end)
			end
		end

		-- Creating a particle and a sound.
		local slamParticle = ParticleManager:CreateParticle("particles/abilities/heroes/earthshaker/slam/earthshaker_echoslam_start.vpcf", PATTACH_CUSTOMORIGIN, caster)
		ParticleManager:SetParticleControl(slamParticle, 0, caster:GetAbsOrigin())
		ParticleManager:ReleaseParticleIndex(slamParticle)
		
		caster:EmitSound("Slam")
	end)
end