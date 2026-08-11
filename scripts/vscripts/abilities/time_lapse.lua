time_lapse = class({})

function time_lapse:OnSpellStart()
	local caster = self:GetCaster()

	-- Preventing usage while being in the air or rooted.
	if  caster:HasModifier("modifier_shadowraze_root") then
		self:EndCooldown()
		return
	end
	
	-- if caster.surgeOn then
		-- caster:CastAbilityNoTarget(caster:FindAbilityByName(caster.sprintBreak), 0)
	-- end
	
	-- Grab the old vel and position
	local newPos = caster.trackedPosition[caster.trackedEndSafe]
	local newVel = caster.trackedVelocity[caster.trackedEndSafe]
	
	local timeLapseParticle = ParticleManager:CreateParticle("particles/time_lapse/time_lapse.vpcf", PATTACH_ABSORIGIN, caster)
	caster:EmitSound("Hero_Weaver.TimeLapse")
	
	-- Set new position
	caster.collisionEnabled = false
	caster.BallCollRadius = (caster.originalBallCollRadius or BALL_COLLISION_DIST) + TIME_LAPSE_INCREASE
	caster:SetAbsOrigin(newPos)
	caster:SetPhysicsVelocity(newVel)
	caster:AddNewModifier(caster,nil,"modifier_force_normal_ball_collision", {duration=FRAME_TIME * 2})
	Timers:CreateTimer(TIME_LAPSE_COLL_DELAY, function()
		caster.BallCollRadius = caster.originalBallCollRadius or BALL_COLLISION_DIST
		caster.collisionEnabled = true
	end)
	
	-- Set landing particles
	local qangle = VectorToAngles(caster:GetForwardVector())
	ParticleManager:SetParticleControl(timeLapseParticle, 1, Vector(qangle.x, qangle.y, qangle.z))
	ParticleManager:SetParticleControl(timeLapseParticle, 2, newPos)
	local landParticle = ParticleManager:CreateParticle("particles/time_lapse/time_lapse_land.vpcf", PATTACH_POINT, caster)
	ParticleManager:SetParticleControl(landParticle, 0, newPos)
	
	
	Banjoball:SlamNearby(caster, caster:GetAbsOrigin(), TIME_LAPSE_SLAM_RADIUS, -TIME_LAPSE_SLAM_XY, -TIME_LAPSE_SLAM_Z)
	
	-- Reset last timers
	caster.trackedStart = caster.trackedEndSafe
	caster.trackedEnd = caster.trackedEndSafe + 1
	if caster.trackedEnd == TRACKER_CIRCULAR_BUFFER_END then caster.trackedEnd = 1 end
	
	if caster.trackedParticle then
		local arrowPos = Vector(caster.trackedPosition[caster.trackedEndSafe].x, caster.trackedPosition[caster.trackedEndSafe].y, caster.trackedPosition[caster.trackedEndSafe].z + TRACKER_ARROW_Z_OFFSET)
		ParticleManager:SetParticleControl(caster.trackedParticle, 0, arrowPos)
	end
end