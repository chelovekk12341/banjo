hookshot = class({})

function hookshot:OnSpellStart()
    local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	local dir = (point-caster:GetAbsOrigin())
	if dir:Length() == 0 then dir = caster:GetForwardVector() end
	dir = dir:Normalized()
	local vel = dir*HOOKSHOT_VELOCITY
	local projDummy = Banjoball:CreateProjectile(PROJECTILE_INDEX_SWAP, caster, SWAP_COLLISION_RADIUS, vel, NO_FRICTION, caster:GetAbsOrigin() + 150*dir, true)
	local ball = Ball.unit
	caster.hookDummy = projDummy
	
	projDummy.projParticle = ParticleManager:CreateParticle("particles/heroes/clockwerk/rattletrap_hookshot.vpcf", PATTACH_RENDERORIGIN_FOLLOW, projDummy)
	ParticleManager:SetParticleControlEnt(projDummy.projParticle, 0, caster, 5, nil, caster:GetAbsOrigin(), false)
	ParticleManager:SetParticleControlEnt(projDummy.projParticle, 6, projDummy, 5, nil, projDummy:GetAbsOrigin(), false)
	ParticleManager:SetParticleControlEnt(projDummy.projParticle, 1, projDummy, 5, nil, projDummy:GetAbsOrigin(), false)
	projDummy:EmitSound("Hero_Rattletrap.Hookshot.Fire")
	projDummy.onProjectileCollision = function( collided )
		projDummy:Trigger(collided)
	end
	function projDummy:Remove()
		ParticleManager:DestroyParticle(self.projParticle, true)
		Banjoball:DestroyProjectile(projDummy)
		projDummy = nil
		caster.hookDummy = nil
	end
	function projDummy:Collided(collided)
		local ccc = 0
		projDummy.target = collided
		projDummy.pulling = true
		if ball.controller == caster then
			ball.controller = nil
		end
		local bcd = caster:AddNewModifier(caster,hookshot,"modifier_ball_catching_disable", {duration=99}) -- returns CDOTA_Buff type
		local selfRoot = caster:AddNewModifier(caster,hookshot,"modifier_root_full", {duration=99})
		local enemeyRoot
		if caster:GetTeam() ~= collided:GetTeam() then
			enemeyRoot = collided:AddNewModifier(collided,hookshot,"modifier_root_full", {duration=99}) -- returns CDOTA_Buff type
		end
		local pullStartTime = GameRules:GetGameTime()
		Timers:CreateTimer(0, function()
			local casterPos = caster:GetAbsOrigin()
			local collidedPos = collided:GetAbsOrigin()
			local moveDir = (collidedPos-casterPos):Normalized()
			if (collidedPos-casterPos):Length() < (collided:GetAbsOrigin().z > GROUND_Z and 225 or 150) or collided.goalie then
				projDummy:Remove()
				bcd:Destroy()
				selfRoot:Destroy()
				if enemeyRoot then
					enemeyRoot:Destroy()
				end
				Timers:CreateTimer(0.06,function()
					caster:StopSound("Hero_Rattletrap.Hookshot.Retract")
				end)
				return
			end
			local resultPos = casterPos + (moveDir * HOOKSHOT_PULL_SPEED)
			caster:SetAbsOrigin(resultPos)
			return FRAME_TIME
		end)
	end

	function projDummy:Trigger(collided)
		if not Banjoball:IsProjectileActive(projDummy) then
			return
		end
		if collided then
			if collided.goalie then return end
			projDummy:SetPhysicsVelocity(Vector(0,0,0))
			projDummy:Collided(collided)
			projDummy:StopSound("Hero_Rattletrap.Hookshot.Fire")
			caster:EmitSound("Hero_Rattletrap.Hookshot.Impact")
		else
			projDummy.retracting = true
		end
		Banjoball:DisableProjectile(projDummy)
		caster:EmitSound("Hero_Rattletrap.Hookshot.Retract")
	end

	Timers:CreateTimer(HOOKSHOT_DURATION, function()
		if not projDummy then return end
		projDummy:Trigger()
	end)
	Timers:CreateTimer(0,function()
		if not projDummy then
			return
		end
		if projDummy.pulling == true and projDummy.target then
			projDummy:SetAbsOrigin(projDummy.target:GetAbsOrigin())
		elseif projDummy.retracting then
			if (caster:GetAbsOrigin() - projDummy:GetAbsOrigin()):Length() < 150 then
				projDummy:Remove()
				Timers:CreateTimer(0.06,function()
					caster:StopSound("Hero_Rattletrap.Hookshot.Retract")
				end)
				return
				
			end
			projDummy:SetPhysicsVelocity ( (caster:GetAbsOrigin() - projDummy:GetAbsOrigin()):Normalized()*SWAP_PROJ_VELOCITY )
		end
		return FRAME_TIME
	end)
end

