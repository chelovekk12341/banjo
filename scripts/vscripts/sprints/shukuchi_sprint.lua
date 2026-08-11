function Banjoball:shukuchi_sprint( keys )
	local caster = keys.caster

	caster.sprintedAt = GameRules:GetGameTime()

	caster:AddNewModifier(caster,nil,"modifier_shukuchi", {duration = 99999})
	
	SwapAbilities( caster, "shukuchi_sprint_break", "shukuchi_sprint", ABILITY_SLOT_E )

	caster.surgeParticle = ParticleManager:CreateParticle("particles/ninja_invis_sprint/dark_seer_surge.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)

	caster:EmitSound("Hero_BountyHunter.WindWalk")
	
	
	Timers:CreateTimer(INVIS_DELAY_TIME_WEAVER, function()
		if caster.surgeOn then
		caster:AddNewModifier(caster,caster,"modifier_ninjainvis", {duration = 999})
		end
	end)
end

function Banjoball:shukuchi_sprint_break( keys )
	local caster = keys.caster
	
	caster.SprintMult = 0

	SwapAbilities( caster, "shukuchi_sprint", "shukuchi_sprint_break", ABILITY_SLOT_E )

	if caster:HasModifier("modifier_shukuchi_fade") then
		caster:RemoveModifierByName("modifier_shukuchi_fade")
	end

	if caster:HasModifier("modifier_shukuchi_invis") then
		caster:RemoveModifierByName("modifier_shukuchi_invis")
	end
	
	if caster:HasModifier("modifier_ninjainvis") then
		caster:RemoveModifierByName("modifier_ninjainvis")
	end

	if caster:HasModifier("modifier_shukuchi") then
		caster:RemoveModifierByName("modifier_shukuchi")
	end
end