cross = class({})

-- This function is called when the "CROSS" ability is used.
function cross:OnSpellStart()
    local caster = self:GetCaster()
	local ball = Ball.unit
	local point = Vector(self:GetCursorPosition().x, self:GetCursorPosition().y, caster:GetAbsOrigin().z)
	caster:FaceTowards(point)

	-- Preventing usage without the ball.
	if caster ~= ball.controller then return end

	-- Setting variables
	caster.isChargingCross = true
	CrossTime = GameRules:GetGameTime()
	SwapAbilities( caster, "cross_finish", "cross", ABILITY_SLOT_D )



	-- Visualising channeling.
	Banjoball:ShowCastBar(caster, CROSS_CASTBAR)

	-- Channeling  logic, which works every tick.
	Timers:CreateTimer(function()
		-- Keeping channeling if not prevented or stopping channeling if time exceeds.
		if GameRules:GetGameTime() > CrossTime + CROSS_TIME then caster.finishedCrossing = true
		elseif caster.isChargingCross then return FRAME_TIME end

		-- Stopping visualising.
		Banjoball:HideCastBar(caster)

		caster.isChargingCross = false

		-- The kicking logic, force depends on the time spent channeling.
		SwapAbilities( caster, "cross", "cross_finish", ABILITY_SLOT_D )
		if caster == ball.controller and caster.finishedCrossing then
			local mult = (GameRules:GetGameTime() - CrossTime) / CROSS_TIME
			local dir = caster:GetForwardVector()
			dir.z = 0
			dir = dir:Normalized()
			KickBall({keys = { target_points = { point } }, hero = caster, xy_velocity = CROSS_BASE_VEL_XY + mult*CROSS_ADD_VEL_XY, z_velocity = CROSS_BASE_VEL_Z + mult*CROSS_ADD_VEL_Z, type = 2, direction = dir})
			ball:EmitSound("Kick" .. RandomInt(1, NUM_KICK_SOUNDS))
		end
	end)
end

cross_finish = class({})

function cross_finish:OnSpellStart()
	local hero = self:GetCaster()
	if not hero.isChargingCross then return end
	hero.isChargingCross = false
	hero.finishedCrossing = true
end