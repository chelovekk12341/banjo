clockcog = class({})

function clockcog:OnSpellStart()
    local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	local dir = (point-caster:GetAbsOrigin())
	if dir:Length() == 0 then dir = caster:GetForwardVector() end
	dir = dir:Normalized()
	local vel = dir*HOOKSHOT_VELOCITY
	local projDummy = Banjoball:CreateProjectile(PROJECTILE_INDEX_SWAP, caster, 300, Vector(0,0,0), 0.1, caster:GetAbsOrigin() + 150*dir, true)
	--caster.projDummy = projDummy
	
	if caster.ClockCogInst then
		caster.ClockCogInst:Remove()
	end
	caster.ClockCogInst = projDummy
	
	projDummy.projParticle = ParticleManager:CreateParticle("particles/heroes/clockwerk/custom_cog2.vpcf", PATTACH_RENDERORIGIN_FOLLOW, projDummy)
	ParticleManager:SetParticleControlEnt(projDummy.projParticle, 0, projDummy, 5, nil, projDummy:GetAbsOrigin(), true)
	ParticleManager:SetParticleControl(projDummy.projParticle, 2, Vector(COG_SIZE,COG_SIZE,COG_SIZE))
	caster:EmitSound("Hero_Rattletrap.Power_Cogs")
	Timers:CreateTimer(2, function()
		caster:StopSound("Hero_Rattletrap.Power_Cogs")
	end)
	local collider = projDummy:AddColliderFromProfile('circlenom')
	collider.radius = COG_CHANGED or 100
	collider.multiplier = 0.5
	collider.test = function(self, colder, unit)
		--print('PROCKED procked', projDummy==unit, collider==unit)
		if caster.hookDummy and unit == caster.hookDummy then
			caster.hookDummy:Trigger(unit)
		end
		return true
	end
	collider.filter = Banjoball.colliderFilter
	projDummy.onProjectileCollision = function( collided )
		projDummy:Trigger(collided)
		return false
	end
	function projDummy:Remove()
		ParticleManager:DestroyParticle(projDummy.projParticle, true)
		Banjoball:DestroyProjectile(projDummy)
		projDummy = nil
		caster.ClockCogInst = nil
	end
	function projDummy:Collided(collided)
		--Banjoball:DisableProjectile(projDummy)
		if collided:GetTeam() == caster:GetTeam() or (collided.AffectedByCogs and GameRules:GetGameTime() - collided.AffectedByCogs < 1) then
			return
		end
		collided.AffectedByCogs = GameRules:GetGameTime()
		local ligParticle = ParticleManager:CreateParticle("particles/heroes/clockwerk/rattletrap_cog_leash.vpcf", PATTACH_RENDERORIGIN_FOLLOW, collided)
		ParticleManager:SetParticleControlEnt(ligParticle, 0, collided, PATTACH_POINT_FOLLOW, 'attach_hitloc', collided:GetAbsOrigin(), false)
		ParticleManager:SetParticleControlEnt(ligParticle, 5, projDummy, PATTACH_OVERHEAD_FOLLOW, nil, projDummy:GetAbsOrigin(), false)
		caster:EmitSound("Hero_Rattletrap.Power_Cogs_Impact")
		local slow = collided:AddNewModifier(caster, self ,"modifier_clockcog_slow", {duration=5}) -- returns CDOTA_Buff type
		local pushedC = 0
		Timers:CreateTimer(0, function()
			pushedC = pushedC + 1
			if pushedC > 26 then
				ParticleManager:DestroyParticle(ligParticle, true)
				slow:Destroy()
				return
			end
			local Pushdir = (collided:GetAbsOrigin() - projDummy:GetAbsOrigin()):Normalized()
			local ppower = COG_PUSH_VELOCITY* (1/math.floor((pushedC+4)/5))
			--print(ppower)
			collided:AddPhysicsVelocity(Pushdir*ppower)
			return FRAME_TIME
		end)
	end

	function projDummy:Trigger(collided)
		if not Banjoball:IsProjectileActive(projDummy) then
			return
		end
		if collided then
			if collided.goalie then return end
			projDummy:Collided(collided)
		end
	end
	if GetGoalPointIsWithin(projDummy:GetAbsOrigin()) == caster:GetTeam() then
		Timers:CreateTimer(COG_GOALZONE_DESTROY, function()
		if not projDummy then return end
			projDummy:Remove()
		end)
	end
	local cog_duration = self:GetSpecialValueFor("cog_duration")
	if cog_duration <= 0 then cog_duration = 10.0 end

	Timers:CreateTimer(cog_duration, function()
		if not projDummy or not Banjoball:IsProjectileActive(projDummy) then return end
		projDummy:Remove()
	end)
end

