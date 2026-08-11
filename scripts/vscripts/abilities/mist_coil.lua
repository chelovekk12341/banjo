mist_coil = class({})

-- Предварительный кэш ресурсов для способности
function mist_coil:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_abaddon/abaddon_death_coil.vpcf", context)
end

-- Вызывается при старте заклинания (теперь это NO_TARGET способность)
function mist_coil:OnSpellStart()
	local caster = self:GetCaster()
	
	-- Воспроизводим звук запуска
	caster:EmitSound("Hero_Abaddon.DeathCoil.Cast")

	-- Списываем или восстанавливаем ману у себя
	local current_mana = caster:GetMana()
	if caster:HasModifier("modifier_borrow_time") then
		-- Восстанавливаем 70 маны
		caster:SetMana(math.min(caster:GetMaxMana(), current_mana + 70))
	else
		-- Списываем 70 маны (но не ниже 0)
		caster:SetMana(math.max(0, current_mana - 70))
	end

	-- Находим всех союзных героев в радиусе 900
	local allies = GetUnitsInTrueRadius(caster:GetAbsOrigin(), 900)
	for _, ally in ipairs(allies) do
		if ally ~= caster and ally:GetTeam() == caster:GetTeam() and ally:IsAlive() then
			-- Создаем следящий снаряд, летящий к союзнику
			local projectile_info = {
				Target = ally,
				Source = caster,
				Ability = self,	
				EffectName = "particles/units/heroes/hero_abaddon/abaddon_death_coil.vpcf",
				iMoveSpeed = 1600,
				vSourceLoc = caster:GetAbsOrigin(),
				bDrawTriggerAreas = false,
				bDodgeable = false,
				bIsAttack = false,
				bVisibleToEnemies = true,
				bReplaceExisting = false,
				flExpireTime = GameRules:GetGameTime() + 10.0,
				bProvidesVision = false,
			}
			ProjectileManager:CreateTrackingProjectile(projectile_info)
		end
	end
end

-- Вызывается при попадании снаряда в цель
function mist_coil:OnProjectileHit(target, location)
	if target and target:IsAlive() then
		local caster = self:GetCaster()
		
		-- Воспроизводим звук попадания
		target:EmitSound("Hero_Abaddon.DeathCoil.Target")

		if target:GetTeam() == caster:GetTeam() then
			-- Союзник: даем 70 маны
			local target_max_mana = target:GetMaxMana()
			local target_current_mana = target:GetMana()
			local mana_transfer = self:GetSpecialValueFor("mana_transfer")
			if mana_transfer == 0 then mana_transfer = 70 end

			target:SetMana(math.min(target_max_mana, target_current_mana + mana_transfer))
		end
	end
	return true
end
