ringmaster_souvenir_select = class({})

function ringmaster_souvenir_select:GetAbilityTextureName()
	return "ringmaster_dark_carnival_souvenirs"
end

function ringmaster_souvenir_select:OnSpellStart()
	local caster = self:GetCaster()
	
	local force = caster:FindAbilityByName("ringmaster_force_staff")
	local box = caster:FindAbilityByName("ringmaster_box")
	local unicycle = caster:FindAbilityByName("ringmaster_unicycle")
	
	local current_ability = nil
	local next_ability = nil
	
	if force and not force:IsHidden() then
		current_ability = "ringmaster_force_staff"
		next_ability = "ringmaster_box"
	elseif box and not box:IsHidden() then
		current_ability = "ringmaster_box"
		next_ability = "ringmaster_unicycle"
	elseif unicycle and not unicycle:IsHidden() then
		current_ability = "ringmaster_unicycle"
		next_ability = "ringmaster_force_staff"
	end
	
	if current_ability and next_ability then
		caster:SwapAbilities(next_ability, current_ability, true, false)
		
		-- Звук переключения
		EmitSoundOn("Hero_Ringmaster.Whoop", caster)
	end
end
