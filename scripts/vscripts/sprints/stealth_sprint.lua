function Banjoball:stealth_sprint( keys )
	local caster = keys.caster
	local ball = Ball.unit
	if ball.controller == caster then Banjoball:stealth_sprint_break( keys ) return end

	caster.pritaica = true
	
	SwapAbilities( caster, "ninja_invis_sprint_break", "ninja_invis", ABILITY_SLOT_R )

	if caster.surgeOn then caster:CastAbilityNoTarget(caster:FindAbilityByName(caster.sprintBreak), 0) end

	caster:EmitSound("Hero_BountyHunter.WindWalk")
	Timers:CreateTimer(INVIS_DELAY_TIME, function()
		if caster.pritaica then
		caster:AddNewModifier(caster,caster,"modifier_ninjainvis", {duration = 999})
		end
	end)

	if caster.dust_particle then
		ParticleManager:DestroyParticle(caster.dust_particle, false)
		caster.dust_particle = nil
	end

	-- we need neutral particle so enemies can see the dust too.
	caster.dust_particle = CreateNeutralParticle( "particles/units/heroes/hero_bounty_hunter/bounty_hunter_windwalk.vpcf", caster:GetAbsOrigin(), PATTACH_ABSORIGIN, 2 )
	
end

function Banjoball:stealth_sprint_break( keys )
	local caster = keys.caster

	if caster.pritaica then SwapAbilities( caster, "ninja_invis", "ninja_invis_sprint_break", ABILITY_SLOT_R ) end

	caster.pritaica = false

	if caster:HasModifier("modifier_ninja_fade") then
		caster:RemoveModifierByName("modifier_ninja_fade")
	end

	if caster:HasModifier("modifier_ninjainvis") then
		caster:RemoveModifierByName("modifier_ninjainvis")
	end

	if caster:HasModifier("modifier_ninja_invis") then
		caster:RemoveModifierByName("modifier_ninja_invis")
	end
end