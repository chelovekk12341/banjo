ringmaster_force_staff = class({})

function ringmaster_force_staff:GetAbilityTextureName()
	return "ringmaster_whoopee_cushion"
end

function ringmaster_force_staff:OnSpellStart()
	local caster = self:GetCaster()
	local dir = caster:GetForwardVector()
	dir.z = 0
	dir = dir:Normalized()
	
	-- Звук Force Staff
	EmitSoundOn("DOTA_Item.ForceStaff.Activate", caster)
	
	-- Партикль Force Staff
	local pfx = ParticleManager:CreateParticle("particles/items_fx/force_staff.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	
	-- Читаем дальность из KV (по умолчанию 350)
	local distance = self:GetSpecialValueFor("force_staff_distance") or 350
	
	local has_unicycle = caster:HasModifier("modifier_ringmaster_unicycle_buff")
	if has_unicycle then
		distance = distance * 1.6 -- Форсается на 60% сильнее на моноколесе
	end
	
	-- Устанавливаем физическую скорость
	caster:SetPhysicsVelocity(dir * (distance / 0.3))
	-- Через 0.3 секунды плавно останавливаем героя и удаляем партикл
	Timers:CreateTimer(0.3, function()
		if caster and not caster:IsNull() and caster:IsAlive() then
			-- Если герой на колесе, не останавливаем его в 0, чтобы сохранить инерцию
			if not caster:HasModifier("modifier_ringmaster_unicycle_buff") then
				caster:SetPhysicsVelocity(Vector(0, 0, 0))
			end
		end
		if pfx then
			ParticleManager:DestroyParticle(pfx, false)
			ParticleManager:ReleaseParticleIndex(pfx)
		end
		return nil
	end)
end
