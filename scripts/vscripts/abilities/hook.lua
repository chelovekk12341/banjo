function Banjoball:hook( keys )
	local caster = keys.caster
	local point = keys.target_points[1]
	local ball = Ball.unit
	
	Timers:CreateTimer(HOOK_DELAY, function()
		PlayAnimation("act_dota_idle", caster)
		if caster:HasModifier("modifier_hook_animation") then
			caster:RemoveModifierByName("modifier_hook_animation")
		end
		
		local dir = (point-caster:GetAbsOrigin())
		if dir:Length() == 0 then dir = caster:GetForwardVector() end
		dir = dir:Normalized()
		local vel = dir*HOOK_VELOCITY
		local hookDummy = Banjoball:CreateProjectile(PROJECTILE_INDEX_HOOK, caster, HOOK_COLLISION_RADIUS, vel, NO_FRICTION, nil, true)
		caster.hookDummy = hookDummy
      Banjoball:DisableProjectile(hookDummy)
		
		hookDummy.retracting = false
		hookDummy.finishedHook = false
		hookDummy.hookedObject = nil
		hookDummy.lastHooked = nil
		
		-- Remove Pudge's hook (visuals)
		local weapon_hook = caster:GetTogglableWearable( DOTA_LOADOUT_TYPE_WEAPON )
		if weapon_hook then
			weapon_hook:AddEffects( EF_NODRAW )
		end
		
		-- Create an offset hook dummy for the particles ( so they float )
		local hookParticleDummy = CreateUnitByName("dummy", hookDummy:GetAbsOrigin() + HOOK_HEIGHT, false, nil, nil, caster:GetTeam())
		hookDummy.hookParticleDummy = hookParticleDummy
		hookDummy.hookParticle = ParticleManager:CreateParticle("particles/pudge_hook/pudge_meathook_chain.vpcf", PATTACH_RENDERORIGIN_FOLLOW, caster)
		ParticleManager:SetParticleControlEnt(hookDummy.hookParticle, 0, caster, 5, "attach_hook", caster:GetAbsOrigin(), false)
		ParticleManager:SetParticleControlEnt(hookDummy.hookParticle, 6, hookParticleDummy, 5, "attach_hitloc", hookParticleDummy:GetAbsOrigin(), false)
		
		caster:EmitSound("Hero_Pudge.AttackHookExtend")
		
		SwapAbilities( caster, "hook_retract", "hook", ABILITY_SLOT_Q )
		local hookAbility = caster:FindAbilityByName("hook_retract")
		hookAbility:StartCooldown(HOOK_RETRACT_COOLDOWN)

		-- Drops the object and removes disables
		function hookDummy:drop()
			local target = self.hookedObject
			
			if target then
				target.hookedBy = nil
				
				if target ~= ball then
					target.collisionEnabled = true
					-- Remove the hook disables
					if target:HasModifier("modifier_root_and_silence") then
						target:RemoveModifierByName("modifier_root_and_silence")
					elseif target:HasAbility("hook_root") then
						target:RemoveAbility("hook_root")
						target:RemoveModifierByName("modifier_hook_root")
					end
				else
					caster.spellAssistTimer = GameRules:GetGameTime()
					if (caster:GetAbsOrigin() - ball:GetAbsOrigin()):Length() < BALL_COLLISION_DIST then
						ball.controller = caster
					end
				end
				
				Banjoball:ActivateProjectile(hookDummy)
				
				SwapAbilities( self.caster, "hook", "hook_drop", ABILITY_SLOT_Q )
				hookAbility = self.caster:FindAbilityByName("hook")
				hookAbility:StartCooldown(HOOK_COOLDOWN) -- Just to gray it out for now
			end
			
			self.hookedObject = nil
		end
		
		
		-- Call this when the projectile reaches Pudge / times out because it couldn't reach Pudge
		function hookDummy:destroyHook()
			if hookDummy.hookedObject == ball then
				ball.controller = caster
				if ball.affectedByPowershot == true then
					Banjoball:PowerStop()
				end
			end
			caster.BallCollRadius = 0
			Timers:CreateTimer(0.09, function()
				caster.BallCollRadius = caster.originalBallCollRadius or BALL_COLLISION_DIST
			end)

			ParticleManager:DestroyParticle(self.hookParticle, false)
			self.caster:StopSound("Hero_Pudge.AttackHookRetract")
			self.caster:EmitSound("Hero_Pudge.AttackHookRetractStop")
			
			-- Give back the caster's hook
			if weapon_hook then
				weapon_hook:RemoveEffects( EF_NODRAW )
			end
			
			self:drop()
			hookAbility = self.caster:FindAbilityByName("hook")
			hookAbility:EndCooldown()
			if caster.HookBall then
				--caster.HookBall = false
				hookAbility:StartCooldown(HOOKBALL_COOLDOWN)
			else
				hookAbility:StartCooldown(HOOK_COOLDOWN)
			end

			self.finishedHook = true
			self.hookParticleDummy:ForceKill(true)
			Banjoball:DestroyProjectile(hookDummy)
		end
		
		
		-- Call this as soon as the hook successfully hooks something / duration is maxed
		function hookDummy:retract()
			if not self.retracting then
				self.caster:StopSound("Hero_Pudge.AttackHookExtend")
				self.caster:EmitSound("Hero_Pudge.AttackHookRetract")
				self.retracting = true
				
				if self.hookedObject then
					SwapAbilities( self.caster, "hook_drop", "hook_retract", ABILITY_SLOT_Q )
					hookAbility = self.caster:FindAbilityByName("hook_drop")
				else
					SwapAbilities( self.caster, "hook", "hook_retract", ABILITY_SLOT_Q )
					hookAbility = self.caster:FindAbilityByName("hook")
					hookAbility:StartCooldown(HOOK_COOLDOWN) -- Just to gray it out for now
				end
				
				Timers:CreateTimer(HOOK_TIMEOUT, function()
					if not hookDummy.finishedHook then
						hookDummy:destroyHook()
					end
				end)
			end
		end
		
		
		-- Hooks an object
		function hookDummy:hookObject( target )
			-- Protection against rehooking something you dropped
			if self.lastHooked ~= target then
				if caster.HookBall and target ~= ball then
					return
				end
				if target.hookedBy then
					target.hookedBy.hookDummy:drop()
				end
				target.hookedBy = self.caster
				Banjoball:DisableProjectile(hookDummy)
				self.hookedObject = target
				self.lastHooked = target
				target:EmitSound("Hero_Pudge.AttackHookImpact")
				
				if target ~= ball and target.isBanjoHero then
					ParticleManager:CreateParticle("particles/units/heroes/hero_pudge/pudge_meathook_impact.vpcf", PATTACH_RENDERORIGIN_FOLLOW, target)
					target.collisionEnabled = false
					SafeBreakChannels(target, caster:GetTeam() == target:GetTeam())
					-- Disable hero you've hooked (root for enemy/ally + silence for enemy
					if caster:GetTeam() ~= target:GetTeam() then
						target:AddNewModifier(target, nil, "modifier_root_and_silence", {duration=99999})
					else
						if not target:HasAbility("hook_root") then
							target:AddAbility("hook_root")
							target:FindAbilityByName("hook_root"):SetLevel(1)
						end
					end
				elseif (ball.controller and self.caster:GetTeam() ~= ball.controller:GetTeam()) then
					ball.controller.turnovers = ball.controller.turnovers + 1
					self.caster.steals = self.caster.steals + 1
					Banjoball:text_particle( {caster=self.caster, stolen=true} )
				end
				
				if self.retracting then
					SwapAbilities( self.caster, "hook_drop", "hook", ABILITY_SLOT_Q )
					hookAbility = self.caster:FindAbilityByName("hook_drop")
				else
					self:retract()
				end
			end
		end
		
		
		-- Hook Movement Logic
		caster.hookTimer = Timers:CreateTimer(function()
			if hookDummy.finishedHook then
				hookDummy:destroyHook()
				return nil
			end
			-- Set hook particle dummy to correct location
			hookParticleDummy:SetAbsOrigin(hookDummy:GetAbsOrigin() + HOOK_HEIGHT)
			
			-- Ball hook logic
			if Banjoball:IsProjectileActive(hookDummy) and caster ~= ball.controller and (hookDummy:GetAbsOrigin() - ball:GetAbsOrigin()):Length() < HOOK_COLLISION_RADIUS then
				if not GetGoalPointIsWithin(ball:GetAbsOrigin()) then
					hookDummy:hookObject(ball)
					hookAbility:StartCooldown(HOOK_RETRACT_COOLDOWN)
				end
			end
			
			if hookDummy.retracting then
				local dist = (caster:GetAbsOrigin() - hookDummy:GetAbsOrigin()):Length()
				local carryingPlayer = not (hookDummy.hookedObject == nil or hookDummy.hookedObject == ball)
				
				-- Within range of the Pudge -> end hook
				if (not carryingPlayer and dist < HOOK_RETURN_RADIUS) or (carryingPlayer and dist < HOOK_CARRY_RETURN_RADIUS) then
					hookDummy:destroyHook()
					return nil
				end
				
				-- Ball hooked
				if hookDummy.hookedObject == ball then
					ball.controller = nil
				end
				
				-- If carrying an object, set the carried object's position onto the hook
				if hookDummy.hookedObject then
					hookDummy.hookedObject:SetPhysicsVelocity(Vector(0,0,0))
					hookDummy.hookedObject:SetAbsOrigin(hookDummy:GetAbsOrigin())
				end
				
				dir = (caster:GetAbsOrigin() - hookDummy:GetAbsOrigin()):Normalized()
				-- Slow down hook if it's carrying something other than the ball
				if carryingPlayer then
					vel = dir*HOOK_CARRY_VELOCITY
				else
					vel = dir*HOOK_VELOCITY
				end
				hookDummy:SetPhysicsVelocity(vel)
			end
			
			return .03
		end)
		
		
		-- Hook collision code
		hookDummy.onProjectileCollision = function( collided )
			if collided:HasModifier("modifier_goalie") then return end

			hookDummy:hookObject(collided)
			hookAbility:StartCooldown(HOOK_RETRACT_COOLDOWN)
			return false
		end
		
		
      -- Hook activation -> to avoid hooking people right behind you on cast
      Timers:CreateTimer(HOOK_ACTIVATION_DELAY, function()
         Banjoball:ActivateProjectile(hookDummy)
      end)
      
		-- Hook Duration -> retracts the hook
		Timers:CreateTimer(HOOK_DURATION, function()
			if not hookDummy.retracting then
				hookDummy:retract()
			end
		end)
		
	end)
end

function Banjoball:hook_cancel( keys )
	local hookDummy = keys.caster.hookDummy
	local abilname = keys.ability:GetAbilityName()
	-- if not type(abilname) == string then
		-- abilname = abilname:GetAbilityName()
	-- end
	
	if abilname == "hook_retract" then
		hookDummy:retract()
	elseif abilname == "hook_drop" then
		hookDummy:drop()
	end
end

--[[function Banjoball:hook_ball( keys )
	local hookDummy = keys.caster.hookDummy
	local abilname = keys.ability:GetAbilityName()
	-- if not type(abilname) == string then
		-- abilname = abilname:GetAbilityName()
	-- end
	keys.caster.HookBall = true
end]]

