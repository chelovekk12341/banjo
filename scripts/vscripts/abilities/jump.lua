jump = class({})

function jump:OnSpellStart()
    local caster = self:GetCaster()
	caster.tick = 0
	
	-- Preventing the hero from jumping with the ball or in the air.
	if  caster:GetAbsOrigin().z > ABOVE_GROUND_Z_CONST  or Ball.unit.controller == caster or caster:HasModifier("modifier_root_full") then
		self:EndCooldown()
		return
	end

	-- Preventing the hero from running or wasting mana in the air or using both spells during one tick.
	-- if caster.surgeOn then Banjoball:surge_break(keys) end
	-- caster:GetAbilityByIndex(2):StartCooldown(0.2)

	-- Reducing the values of the jump outside of the goal area.
	local jumpZ = JUMP_Z
	local jumpXY = JUMP_XY
	local jumpHeight = JUMP_HEIGHT
	if not caster:HasModifier("modifier_goalie") then
		jumpZ = JUMP_Z * JUMP_FIELD_MULT
		jumpXY = JUMP_XY * JUMP_FIELD_MULT
		jumpHeight = JUMP_HEIGHT * JUMP_FIELD_HEIGHT
	end
	-- Keeping the velocity of a running hero such as Anti-Mage or Storm Spirit.
	local casterVelocity = Vector(caster:GetPhysicsVelocity().x, caster:GetPhysicsVelocity().y, 0):Length()
	jumpXY = math.max(jumpXY, casterVelocity*JUMP_XY_MOD)

	-- Если Primal Beast прыгает во время разбега Onslaught
	if caster:HasModifier("modifier_primal_beast_onslaught_run") then
		local onslaught_speed = 1400
		local onslaught_ability = caster:FindAbilityByName("primal_beast_onslaught_custom")
		if onslaught_ability then
			local s = onslaught_ability:GetSpecialValueFor("charge_speed")
			if s > 0 then onslaught_speed = s end
		end
		
		jumpXY = math.max(jumpXY, onslaught_speed)
		
		caster.onslaught_interrupted_by_jump = true
		caster.onslaught_stop_run = true
	end

	-- Applying big velocity and increase the hero's height so the hero reaches the needed Z-coordinate fast.
	caster.Height = jumpHeight
	caster.isUsingJump = true
	caster:AddPhysicsVelocity(caster:GetForwardVector()*jumpXY + Vector(0,0,jumpZ))
	-- Switching the velocity to a tiny one and makes the height normal, so the hero starts casually falling down once the needed height is reached.
	Timers:CreateTimer(function()
		if caster.tick >= JUMP_TIME then
			local casterVel = caster:GetPhysicsVelocity()
			-- The math.max function compares the current caster's velocity with the needed minimum (to not override any obtained extra velocity).
			caster:SetPhysicsVelocity(Vector(casterVel.x,casterVel.y,math.max(casterVel.z - jumpZ, JUMP_Z_MIN) ))
			caster.Height = BALL_COLLISION_Z_TOP
			caster.isUsingJump = false

			return
		end

		caster.tick = caster.tick + 1

		return 0.03
	end)
	
	-- Preventing the hero from bouncing.
	caster.noBounce = true

	-- Visualizing the skill.
	local part = ParticleManager:CreateParticle("particles/units/heroes/hero_rubick/rubick_telekinesis.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(part, 1, caster, 1, "follow_origin", caster:GetAbsOrigin(), true)
	ParticleManager:SetParticleControl(part, 2, Vector(.8,0,0))
end