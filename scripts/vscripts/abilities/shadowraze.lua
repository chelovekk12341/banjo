function Banjoball:shadowraze( keys )
	local caster = keys.caster
	local ball = Ball.unit

	Timers:CreateTimer(SHADOWRAZE_DELAY, function()
		local casterPos = caster:GetAbsOrigin()
		local dir = caster:GetForwardVector()
		local perp = Vector(-dir.y, dir.x, 0):Normalized()
		local corners = {}
		local range = keys.ability:GetSpecialValueFor( "range" )
		
		local shadowrazeParticle = ParticleManager:CreateParticle("particles/nevermore_shadowraze.vpcf", PATTACH_CUSTOMORIGIN, caster)
		ParticleManager:SetParticleControl(shadowrazeParticle, 0, casterPos + (dir*range))
		caster:EmitSound("Hero_Nevermore.Shadowraze")
		
		local targets = GetUnitsInRadius(casterPos + (dir * range), SHADOWRAZE_AOE)
		local ballPos = ball:GetAbsOrigin()

		caster:AddNewModifier(caster, nil, "modifier_night_speed", {duration = SHADOWRAZE_SPEED_DURATION})
		caster:SetMana(99.99)
		if caster.SFTimer then Timers:RemoveTimer(caster.SFTimer) end
		caster.manaReg = SHADOWRAZE_MANA_INDICATOR
		caster.SFTimer = Timers:CreateTimer(SHADOWRAZE_SPEED_DURATION, function() caster.manaReg = 0 end)
		
		if #targets > 0 then
			for _, target in ipairs(targets) do
				if not Banjoball:IsProjectile(target) and caster:GetTeam() ~= target:GetTeam() and target ~= ball and not target:HasModifier("modifier_goalie") then
					keys.ability:ApplyDataDrivenModifier(caster, target, "modifier_shadowraze_root", {})
					local surge_break = target:GetAbilityByIndex(2)
					local abilName = surge_break:GetAbilityName()
					if string.ends(abilName, "lightning") then
						target:CastAbilityNoTarget(surge_break, 0)
					end
				end
			end
		end
	end)
end