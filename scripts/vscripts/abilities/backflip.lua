function Banjoball:backflip( keys )
	local caster = keys.caster
	local ball = Ball.unit
	caster.tick = 0
	local point = keys.target_points[1]
	local dif = (point - caster:GetAbsOrigin())
	local dir = dif:Normalized()

	local distance = dif:Length()
	local power = math.min(distance, BACKFLIP_AIM_RANGE) / BACKFLIP_AIM_RANGE
	
	-- Preventing the hero from jumping while rooted or if Slark isn't on the ground.
	if caster:HasModifier("modifier_shadowraze_root") or caster:GetAbsOrigin().z > GROUND_Z then
		keys.ability:EndCooldown()
		keys.ability:StartCooldown(0.1)
		return
	end

	if caster.pritaica then caster:CastAbilityNoTarget(caster:FindAbilityByName("ninja_invis_sprint_break"), 0)  end
	if caster.surgeOn then caster:CastAbilityNoTarget(caster:FindAbilityByName(caster.sprintBreak), 0) end

	-- Stopping Sprint after Backflip is cast.
	if caster.surgeOn then
		caster:CastAbilityNoTarget(caster:FindAbilityByName(caster.sprintBreak), 0)
	end

	-- Something for myphysics.lua
	caster.noBounce = true
	caster.isUsingJump = true
	caster.kickPower = BACKFLIP_KICK_VEL

	-- Applying big velocity and increase the hero's height so the hero reaches the needed Z-coordinate fast.
	caster.Height = JUMP_HEIGHT
	caster:AddPhysicsVelocity(power*dir*BACKFLIP_XY + Vector(0,0,BACKFLIP_Z))
	-- Switching the velocity to a tiny one and makes the height normal, so the hero starts casually falling down once the needed height is reached.
	Timers:CreateTimer(function()
		if caster.tick >= BACKFLIP_TIME then
			local casterVel = caster:GetPhysicsVelocity()
			-- The math.max function compares the current caster's velocity with the needed minimum (to not override any obtained extra velocity).
			caster:SetPhysicsVelocity(Vector(casterVel.x,casterVel.y,math.max(casterVel.z - BACKFLIP_Z, BACKFLIP_Z_MIN) ))
			caster.Height = BALL_COLLISION_Z_TOP

			return
		end

		caster.tick = caster.tick + 1

		return 0.03
	end)

	-- Visualizing the jump.
	caster:EmitSound("Hero_Slark.Pounce.Cast")
	caster.ninjaJump = ParticleManager:CreateParticle("particles/units/heroes/hero_slark/slark_dark_pact_pulses.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:SetParticleControlEnt(caster.ninjaJump, 1, caster, 1, "follow_origin", caster:GetAbsOrigin(), true)
end