magnetic_field = class({})

function magnetic_field:OnSpellStart()
    local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	-- local dir = (point-caster:GetAbsOrigin())
	-- if dir:Length() == 0 then dir = caster:GetForwardVector() end
	-- dir = dir:Normalized()
	-- local vel = dir*HOOKSHOT_VELOCITY
	local projDummy = Banjoball:CreateProjectile(PROJECTILE_INDEX_SWAP, caster, MAGNETIC_FIELD_RADIUS, Vector(0,0,0), 0.1, point, true)
	local ball = Ball.unit
	--caster.projDummy = projDummy
	projDummy.affectcaster = true
	if caster.magnetic_fieldInst then
		caster.magnetic_fieldInst:Remove()
	end
	caster.magnetic_fieldInst = projDummy
	
	projDummy.projParticle = ParticleManager:CreateParticle("particles/units/heroes/hero_arc_warden/arc_warden_magnetic.vpcf", PATTACH_RENDERORIGIN_FOLLOW, projDummy)
	--particles/units/heroes/hero_arc_warden/arc_warden_magnetic.vpcf
	ParticleManager:SetParticleControlEnt(projDummy.projParticle, 0, projDummy, 5, nil, projDummy:GetAbsOrigin(), true)
	ParticleManager:SetParticleControl(projDummy.projParticle, 1, Vector(MAGNETIC_FIELD_RADIUS, 1, 1))
	-- ParticleManager:SetParticleControl(projDummy.projParticle, 2, Vector(COG_SIZE,COG_SIZE,COG_SIZE))
	caster:EmitSound("Hero_ArcWarden.MagneticField.Cast")
	caster:EmitSound("Hero_ArcWarden.MagneticField")
	-- Timers:CreateTimer(2, function()
		-- caster:StopSound("Hero_Rattletrap.Power_Cogs")
	-- end)
	projDummy.onProjectileCollision = function( collided )
		-- projDummy:Trigger(collided)
		return false
	end
	function projDummy:Remove()
		ParticleManager:DestroyParticle(projDummy.projParticle, true)
		Banjoball:DestroyProjectile(projDummy)
		projDummy = nil
		caster.magnetic_fieldInst = nil
	end
	-- function projDummy:Collided(collided)
		--Banjoball:DisableProjectile(projDummy)
		-- print((collided:GetAbsOrigin() - projDummy:GetAbsOrigin()):Length(),projDummy.__projectileCollisionRadius,projDummy:GetAbsOrigin())
		-- if collided:GetTeam() == caster:GetTeam() or (collided.AffectedByMF and GameRules:GetGameTime() - collided.AffectedByMF < 1) then
			-- return
		-- end
		-- collided.AffectedByMF = GameRules:GetGameTime()

	-- end

	-- function projDummy:Trigger(collided)
		-- if not Banjoball:IsProjectileActive(projDummy) then
			-- return
		-- end
		-- if collided then
			-- if collided.goalie then return end
			-- projDummy:Collided(collided)
		-- end
	-- end
	-- if GetGoalPointIsWithin(projDummy:GetAbsOrigin()) == caster:GetTeam() then
		Timers:CreateTimer(MAGNETIC_FIELD_DURATION, function()
		if not projDummy then return end
			projDummy:Remove()
		end)
	function projDummy:AffectBall()
		local oldVel = ball:GetPhysicsVelocity()
			-- ball.MFCaster = caster
		local mult = MAGNETIC_FIELD_ACCELERATE
		if ball.lastMovedBy:GetTeam() ~= caster:GetTeam() then
			mult = -MAGNETIC_FIELD_DECELERATE
		end
		if ball:GetAbsOrigin().z > GROUND_Z then
			mult = mult * 0.5
		end
		local addVel = math.min(oldVel:Length() * mult,MAGNETIC_FIELD_MAXAFFECT)
		-- print(addVel)
		ball:AddPhysicsVelocity(addVel * oldVel:Normalized())
	end
	Timers:CreateTimer(0, function()
		if not projDummy then return end
		if ball.controller or (ball:GetAbsOrigin() - projDummy:GetAbsOrigin()):Length() > MAGNETIC_FIELD_RADIUS then return FRAME_TIME end
		local newtime = GameRules:GetGameTime()
		if newtime - (ball.MFLast or 0) > (FRAME_TIME*2 ) then
			projDummy:AffectBall()
			-- print('BALL AFFECTED', newtime)
		end
		ball.MFLast = GameRules:GetGameTime()
		return FRAME_TIME
	end)
	-- end
	-- Timers:CreateTimer(10, function()
		-- if not projDummy then return end
		-- projDummy:Remove()
	-- end)
end

