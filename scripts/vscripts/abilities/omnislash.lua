omnislash = class({})

function omnislash:OnSpellStart()
	local caster = self:GetCaster()
	local ball = Ball.unit

	-- Preventing the hero from dashing while rooted or if not on the ground.
	if caster:HasModifier("modifier_shadowraze_root") then
		self:EndCooldown()
		return
	end

	caster.omnicount = 0
	caster:EmitSound("Hero_Juggernaut.HealingWard.Cast")
	SwapAbilities(caster, "omnislash_stop", "omnislash", ABILITY_SLOT_Q)
	caster:FindAbilityByName("omnislash_stop"):StartCooldown(OMNISLASH_INITIAL_DELAY)
	Timers:CreateTimer(OMNISLASH_INITIAL_DELAY, function()
		if caster:HasModifier("modifier_shadowraze_root") then
			caster.omnicount = 0
			caster.shouldStopOmnislash = false
			SwapAbilities(caster, "omnislash", "omnislash_stop", ABILITY_SLOT_Q)
			return
		elseif caster.omnicount < OMNISLASH_AMOUNT and not caster.shouldStopOmnislash then
			caster.omnicount = caster.omnicount + 1

			local fv = caster:GetForwardVector()
			local range = OMNISLASH_DISTANCE * (1 + OMNISLASH_DECREASE - OMNISLASH_DECREASE*caster.omnicount)
			local newPos = caster:GetAbsOrigin() + BLINK_DISTANCE * range
			local checkPos = newPos
			local enemyTeam = GetHeroEnemy(caster)
			if (not IsPointOnField(checkPos)) or GetGoalPointIsWithin(checkPos) == enemyTeam then -- If it's nil the points in the field
				local distTraveled = 0
				newPos = caster:GetAbsOrigin()
				while (distTraveled < range) do
					checkPos = newPos + 10*fv
					if IsPointOnField(checkPos) and not (GetGoalPointIsWithin(checkPos) == enemyTeam) then
						newPos = checkPos
						distTraveled = distTraveled + 10 
					else
						break
					end
				end
			end
			caster:EmitSound("Hero_Juggernaut.OmniSlash")
			caster.Omnislashparticle = ParticleManager:CreateParticle('particles/econ/items/juggernaut/jugg_arcana/juggernaut_arcana_omni_slash_trail_dust_l.vpcf', PATTACH_ABSORIGIN, caster)
			ParticleManager:SetParticleControlEnt(caster.Omnislashparticle, 1, caster, 1, "follow_origin", caster:GetAbsOrigin(), true)
			caster:SetAbsOrigin(newPos)
			caster:AddNewModifier(caster,nil,"modifier_force_normal_ball_collision", {duration=FRAME_TIME * 2})

			if ball.controller == caster then
				return OMNISLASH_DELAY_WITH_BALL
			else
				return OMNISLASH_DELAY_WITHOUT_BALL
			end
		else
			caster.omnicount = 0
			caster.shouldStopOmnislash = false
			SwapAbilities(caster, "omnislash", "omnislash_stop", ABILITY_SLOT_Q)
			return
		end
	end)
end

omnislash_stop = class({})

function omnislash_stop:OnSpellStart()
	local caster = self:GetCaster()

	if caster.omnicount == 0 then return end
	caster.shouldStopOmnislash = true
	SwapAbilities(caster, "omnislash", "omnislash_stop", ABILITY_SLOT_Q)
end