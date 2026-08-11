swap = class({})

function swap:GetCastRange(vLocation, hTarget)
	return 3100
end

function swap:OnSpellStart()
    local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	local ball = Ball.unit

	-- if caster:HasModifier("modifier_shadowraze_root") then 
	-- 	self:EndCooldown()
	-- 	return
	-- end

	local dir = (point-caster:GetAbsOrigin())
	if dir:Length() == 0 then dir = caster:GetForwardVector() end
	dir = dir:Normalized()
	local vel = dir*SWAP_PROJ_VELOCITY
	local swapDummy = Banjoball:CreateProjectile(PROJECTILE_INDEX_SWAP, caster, SWAP_COLLISION_RADIUS, vel, NO_FRICTION, caster:GetAbsOrigin() + 150*dir, true)
	caster.swapDummy = swapDummy
	
	swapDummy.swapParticle = ParticleManager:CreateParticle("particles/heroes/puck/illusory_orb/puck_illusory_orb.vpcf", PATTACH_RENDERORIGIN_FOLLOW, swapDummy)
	
	swapDummy:EmitSound("Hero_Puck.Illusory_Orb")
	SwapAbilities(caster, "swap_stop", "swap", ABILITY_SLOT_Q)

	swapDummy.onProjectileCollision = function( collided )
		caster.swapDummy:DS_Stop(caster, true)
	end

	function swapDummy:SwapHeroes(caster, collided)
		local casterVel = caster:GetPhysicsVelocity()
		local casterPos = caster:GetAbsOrigin()
		local collidedVel = collided:GetPhysicsVelocity()
		local collidedPos = collided:GetAbsOrigin()
		
		if not caster:HasModifier("modifier_shadowraze_root") then 
			caster.collisionEnabled = false
			caster:SetPhysicsVelocity(collidedVel)
			caster:SetAbsOrigin(collidedPos)
			caster:AddNewModifier(caster,nil,"modifier_force_normal_ball_collision", {duration=FRAME_TIME * 2})
			ParticleManager:CreateParticle("particles/items_fx/blink_dagger_start.vpcf", PATTACH_ABSORIGIN, collided)
		end
		
		collided.collisionEnabled = false
		collided:SetPhysicsVelocity(casterVel)
		collided:SetAbsOrigin(casterPos)
		collided:AddNewModifier(collided,nil,"modifier_force_normal_ball_collision", {duration=FRAME_TIME * 2})
		
		Timers:CreateTimer(.03, function()
			caster.collisionEnabled = true
			collided.collisionEnabled = true
		end)
		
		local ball_controller = nil
		local newPos = collidedPos
		if caster == ball.controller then
			ball_controller = caster
		elseif collided == ball.controller then
			ball_controller = collided
			newPos = casterPos
		end
		if ball.controller == collided or ball.controller == caster then
			ball:SetAbsOrigin(newPos+ball.controller:GetForwardVector()*20)
		end

		local casterHooked = caster.hookedBy
		local collidedHooked = collided.hookedBy
		
		if casterHooked then
			casterHooked.hookDummy:drop()
			casterHooked.hookDummy:hookObject( collided )
		end
		if collidedHooked then
			collidedHooked.hookDummy:drop()
			collidedHooked.hookDummy:hookObject( caster )
		end
	end

	function swapDummy:DS_Stop(caster, shouldSwap)
		SwapAbilities(caster, "swap", "swap_stop", ABILITY_SLOT_Q)
		if not Banjoball:IsProjectileActive(swapDummy) then
			return
		end

		if shouldSwap then
			local swapWith = {
				hero = nil,
				distToDummy = nil
			}
			for _,hero in ipairs(Banjoball.vHeroes) do
				local dist = (hero:GetAbsOrigin() - swapDummy:GetAbsOrigin()):Length()

				if hero ~= swapDummy.caster and (not hero:HasModifier("modifier_goalie")) and swapDummy.__projectileCollisionRadius >= dist then
					if swapWith.hero == nil or dist < swapWith.dist then
					swapWith.hero = hero
					swapWith.dist = dist
					end
				end
			end
			if swapWith.hero ~= nil then
				swapDummy:SwapHeroes(caster, swapWith.hero)
			elseif not caster:HasModifier("modifier_shadowraze_root") then 
				caster:SetAbsOrigin( ClosestPointOnField( swapDummy:GetAbsOrigin() ) )
				caster:AddNewModifier(caster,nil,"modifier_force_normal_ball_collision", {duration=FRAME_TIME * 2})
			end
			caster:EmitSound("Hero_Puck.EtherealJaunt")
			ParticleManager:CreateParticle("particles/items_fx/blink_dagger_start.vpcf", PATTACH_ABSORIGIN, caster)
		end

		ParticleManager:DestroyParticle(self.swapParticle, true)
		Timers:CreateTimer(0.06, function() 
			self:StopSound("Hero_Puck.Illusory_Orb")
		end)
		
		Banjoball:DestroyProjectile(swapDummy)
	end

	Timers:CreateTimer(SWAP_DURATION, function()
		swapDummy:DS_Stop(caster, false)
	end)
	
end

swap_stop = class({})

function swap_stop:OnSpellStart()
    local caster = self:GetCaster()
	caster.swapDummy:DS_Stop(caster, true)
end