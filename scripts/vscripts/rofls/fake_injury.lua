function Banjoball:fake_injury( keys )
	local caster = keys.caster
	local ball = Ball.unit
	
	if caster ~= ball.controller then
		PlayAnimation("act_dota_die", caster)
		
		caster.isFakingInjury = true
		local freezeTimer = caster.fakeInjuryFreezeTimer
		if freezeTimer == 0.0 then
			caster.isFakingInjury = false
		end
		
		-- Play proper particles for certain heroes and set animation freeze times (if necessary)
		if caster.isPull then
			caster.deathParticle = ParticleManager:CreateParticle("particles/units/heroes/hero_lina/lina_death.vpcf", PATTACH_ABSORIGIN, caster)
		elseif caster.isPowershot then
			caster.deathParticle = ParticleManager:CreateParticle("particles/units/heroes/hero_invoker/invoker_death.vpcf", PATTACH_ABSORIGIN, caster)
		end
		
		Timers:CreateTimer(freezeTimer, function()
			if not caster.isFakingInjury then return end
			GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, caster, "modifier_fake_injury_freeze", {})
			return
		end)
	end
end

function Banjoball:endFakeInjury( caster )
	caster.isFakingInjury = false
	if caster:HasModifier("modifier_fake_injury_freeze") then
		caster:RemoveModifierByName("modifier_fake_injury_freeze")
	end
end