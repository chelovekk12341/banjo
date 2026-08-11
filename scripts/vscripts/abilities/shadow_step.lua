shadow_step = class({})


LinkLuaModifier("modifier_shadow_step_trail_thinker", "abilities/shadow_step.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_root_full", "modifiers/root_full.lua", LUA_MODIFIER_MOTION_NONE)

function shadow_step:EndShadowStep()
	self:ClearTrail()
	self.teleported_this_cast = true
end

function shadow_step:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	local origin = caster:GetAbsOrigin()

	local dir = (point - origin)
	dir.z = 0
	if dir:Length2D() == 0 then
		dir = caster:GetForwardVector()
	else
		dir = dir:Normalized()
	end

	local speed = self:GetSpecialValueFor("speed")
	local width = self:GetSpecialValueFor("width")
	local range = self:GetSpecialValueFor("range")
	local trail_duration = self:GetSpecialValueFor("trail_duration")

	self.teleported_this_cast = false
	self.active_thinkers = {}

	-- Проигрываем звук броска
	caster:EmitSound("Hero_Spectre.DaggerCast")

	-- Создаем линейный снаряд кинжала (с нашим кастомным эффектом без авто-следа)
	local info = {
		Source = caster,
		Ability = self,
		vSpawnOrigin = origin,
		
		EffectName = "particles/units/heroes/hero_spectre/spectre_spectral_dagger.vpcf",
		fDistance = range,
		fStartRadius = width,
		fEndRadius = width,
		vVelocity = dir * speed,
		
		bHasFrontalCone = false,
		bReplaceExisting = false,
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
		iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
		iUnitTargetType = DOTA_UNIT_TARGET_HERO,
	}

	ProjectileManager:CreateLinearProjectile(info)



	-- Автовозврат способности через максимальное время жизни следа
	local total_trail_time = (range / speed) + trail_duration
	Timers:CreateTimer(total_trail_time, function()
		if not self.teleported_this_cast then
			self:EndShadowStep()
		end
	end)

	-- Запускаем таймер спавна мыслителей следа вдоль пути снаряда
	local time_step = 0.05
	local elapsed_time = 0
	local max_time = range / speed

	Timers:CreateTimer(function()
		if self.teleported_this_cast or elapsed_time > max_time then
			return nil
		end

		local current_pos = origin + dir * (speed * elapsed_time)
		if IsPointOnField(current_pos) then
			local thinker = CreateModifierThinker(
				caster,
				self,
				"modifier_shadow_step_trail_thinker",
				{ duration = trail_duration },
				current_pos,
				caster:GetTeamNumber(),
				false
			)
			if thinker then
				table.insert(self.active_thinkers, thinker)

				-- Таймер для автоматического удаления мыслителя
				Timers:CreateTimer(trail_duration, function()
					for i, t in ipairs(self.active_thinkers) do
						if t == thinker then
							if thinker and not thinker:IsNull() then
								thinker:RemoveModifierByName("modifier_shadow_step_trail_thinker")
								UTIL_Remove(thinker)
							end
							table.remove(self.active_thinkers, i)
							break
						end
					end
				end)
			end
		end

		elapsed_time = elapsed_time + time_step
		return time_step
	end)
end

function shadow_step:ClearTrail()
	-- Удаляем оцепенеющие мыслители с пути
	if self.active_thinkers then
		for _, thinker in ipairs(self.active_thinkers) do
			if thinker and not thinker:IsNull() then
				thinker:RemoveModifierByName("modifier_shadow_step_trail_thinker")
				UTIL_Remove(thinker)
			end
		end
		self.active_thinkers = {}
	end
end

function shadow_step:OnProjectileHit(hTarget, vLocation)
	if not hTarget then return true end -- Снаряд долетел до конца диапазона без попадания

	local caster = self:GetCaster()
	if hTarget == caster then return false end -- Игнорируем самого себя при вылете снаряда

	-- Игнорируем вратаря
	if hTarget.goalie or (hTarget.HasModifier and hTarget:HasModifier("modifier_goalie")) then
		return false
	end

	if self.teleported_this_cast then return true end
	
	-- Возвращаем способность и очищаем след
	self:EndShadowStep()

	local target_pos = hTarget:GetAbsOrigin()

	-- Проигрываем звук телепортации
	hTarget:EmitSound("Hero_Spectre.Reality")

	-- Визуальный эффект блинка на старом месте
	local pfx = ParticleManager:CreateParticle("particles/items_fx/blink_dagger_start.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:ReleaseParticleIndex(pfx)

	-- Выключаем коллизию перед перемещением
	caster.collisionEnabled = false

	-- Телепортируем Спектру к герою
	FindClearSpaceForUnit(caster, target_pos, true)
	caster.collisionEnabled = true

	-- Если Спектра контролирует мяч, телепортируем мяч вместе с ней
	local ball = Ball.unit
	if ball and ball.controller == caster then
		local new_ball_pos = target_pos + caster:GetForwardVector() * 20
		ball:SetAbsOrigin(ClosestPointOnField(new_ball_pos))
	end

	-- Эффект блинка на новом месте
	local pfx2 = ParticleManager:CreateParticle("particles/items_fx/blink_dagger_end.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:ReleaseParticleIndex(pfx2)

	-- Применяем оцепенение на 1.5 сек
	hTarget:AddNewModifier(caster, self, "modifier_root_full", { duration = 1.5 })

	-- Возвращаем true, чтобы уничтожить снаряд (впивается только в первую цель)
	return true
end

--------------------------------------------------------------------------------

modifier_shadow_step_trail_thinker = class({})

function modifier_shadow_step_trail_thinker:OnCreated()
	if not IsServer() then return end
	self.trail_radius = self:GetAbility():GetSpecialValueFor("trail_radius")
	self:StartIntervalThink(0.1)

	-- Отрисовываем тень следа
	self.pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_spectre/spectre_shadow_path.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
	ParticleManager:SetParticleControl(self.pfx, 0, self:GetParent():GetAbsOrigin())
end

function modifier_shadow_step_trail_thinker:OnDestroy()
	if not IsServer() then return end
	if self.pfx then
		ParticleManager:DestroyParticle(self.pfx, true)
		ParticleManager:ReleaseParticleIndex(self.pfx)
	end
end

function modifier_shadow_step_trail_thinker:OnIntervalThink()
	local ability = self:GetAbility()
	if not ability or ability:IsNull() or ability.teleported_this_cast then
		return
	end

	local caster = self:GetCaster()
	if not caster or caster:IsNull() or not caster:IsAlive() then
		return
	end

	local parent = self:GetParent()
	local parent_pos = parent:GetAbsOrigin()
	local team = caster:GetTeamNumber()

	-- Ищем вражеских героев на следу
	local enemies = FindUnitsInRadius(
		team,
		parent_pos,
		nil,
		self.trail_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, enemy in ipairs(enemies) do
		if enemy and not enemy:IsNull() and enemy:IsAlive() and not ability.teleported_this_cast then
			-- Игнорируем вратаря
			if not (enemy.goalie or (enemy.HasModifier and enemy:HasModifier("modifier_goalie"))) then
				-- Возвращаем способность и очищаем след
				ability:EndShadowStep()

				local target_pos = enemy:GetAbsOrigin()
				
				-- Звук телепортации
				enemy:EmitSound("Hero_Spectre.Reality")

				-- Визуальный эффект блинка
				local pfx = ParticleManager:CreateParticle("particles/items_fx/blink_dagger_start.vpcf", PATTACH_ABSORIGIN, caster)
				ParticleManager:ReleaseParticleIndex(pfx)

				caster.collisionEnabled = false
				FindClearSpaceForUnit(caster, target_pos, true)
				caster.collisionEnabled = true

				local ball = Ball.unit
				if ball and ball.controller == caster then
					local new_ball_pos = target_pos + caster:GetForwardVector() * 20
					ball:SetAbsOrigin(ClosestPointOnField(new_ball_pos))
				end

				local pfx2 = ParticleManager:CreateParticle("particles/items_fx/blink_dagger_end.vpcf", PATTACH_ABSORIGIN, caster)
				ParticleManager:ReleaseParticleIndex(pfx2)

				enemy:AddNewModifier(caster, ability, "modifier_root_full", { duration = 1.5 })

				break
			end
		end
	end
end


