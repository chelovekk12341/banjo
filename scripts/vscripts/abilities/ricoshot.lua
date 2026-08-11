ricoshot = class({})

function ricoshot:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorPosition()
	local ball = Ball.unit
	local ballPos = ball:GetAbsOrigin()
	local target = Vector(target.x, target.y, ballPos.z)
	local dir = (target-ballPos):Normalized()

	-- Break if caster doesn't have the ball
	if caster ~= ball.controller and caster:GetTeam() ~= ball.lastMovedBy:GetTeam() then return end
	
	if caster == ball.controller then
		KickBall({keys = { target_points = { target } }, hero = caster, xy_velocity = KICK_VELOCITY, type = 3})
		ball:EmitSound("Kick" .. RandomInt(1, NUM_KICK_SOUNDS))
	end
	
	if ball.ricoshot_particle then
		ParticleManager:DestroyParticle(ball.ricoshot_particle, true)
		ball.ricoshot_particle = nil
	end
	ball.ricoshot_particle = ParticleManager:CreateParticle("particles/ranged_badguy_persistent_green.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy) --PATTACH_ABSORIGIN_FOLLOW particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tree_burst.vpcf
	ParticleManager:SetParticleControl( ball.ricoshot_particle, 0, ballPos)
	ParticleManager:SetParticleControlEnt( ball.ricoshot_particle, 0, ball.particleDummy, PATTACH_ABSORIGIN_FOLLOW, "", ball.particleDummy:GetAbsOrigin(), true )
	ball.ricoshot = RICOSHOT_DURATION
	ball.riconum = 0

	-- Curveshot Logic
	caster.ricoshotTimer = Timers:CreateTimer(function()
		if not ball.ricoshot or ball.ricoshot <= 0 or ball.controller or ball.riconum >= RICOSHOT_BOUNCES_MAX then
			ball.ricoshot = 0
			ParticleManager:DestroyParticle(ball.ricoshot_particle, true)
			return
		end
		if ball:GetPhysicsVelocity() == Vector(0,0,0) and ball.ricoshot > RICOSHOT_AFTERSTAND_TIME then
			ball.ricoshot = RICOSHOT_AFTERSTAND_TIME
		end
		
		
		ball.ricoshot = ball.ricoshot - .03
		
		return .03
	end)
end
