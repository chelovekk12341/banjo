function Banjoball:demonic_endurance( keys )
	local caster = keys.caster
	local ball = Ball.unit
	caster.SprintMult = 1
	caster:AddNewModifier(caster,nil,"modifier_demonic_sprint", {duration = 99999})
	
	SwapAbilities( caster, "demonic_endurance_sprint_break", "demonic_endurance_sprint", ABILITY_SLOT_E )
	
	caster.surgeParticle = ParticleManager:CreateParticle("particles/items2_fx/phase_boots.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
end

function Banjoball:demonic_endurance_break( keys )
	local caster = keys.caster
	local ball = Ball.unit
	caster.SprintMult = 0

	SwapAbilities( caster, "demonic_endurance_sprint", "demonic_endurance_sprint_break", ABILITY_SLOT_E )
	
	if caster:HasModifier("modifier_demonic_endurance") then
		caster:RemoveModifierByName("modifier_demonic_endurance")
	end
	if caster:HasModifier("modifier_demonic_sprint") then
		caster:RemoveModifierByName("modifier_demonic_sprint")
	end
end