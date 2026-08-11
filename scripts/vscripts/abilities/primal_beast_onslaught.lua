primal_beast_onslaught_custom = class({})

LinkLuaModifier("modifier_primal_beast_onslaught_charge", "abilities/primal_beast_onslaught", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_primal_beast_onslaught_run", "abilities/primal_beast_onslaught", LUA_MODIFIER_MOTION_NONE)

function primal_beast_onslaught_custom:OnSpellStart()
	local caster = self:GetCaster()
	local target_point = self:GetCursorPosition()

	-- Инициализируем флаги и направление
	self.direction = (target_point - caster:GetAbsOrigin()):Normalized()
	self.direction.z = 0
	self.start_charge_time = GameRules:GetGameTime()
	self.has_kicked_ball = false

	caster.isUsingOnslaught = true
	caster.isOnslaughtCharging = true
	caster.isOnslaughtRunning = false
	caster.onslaught_target_point = target_point
	caster.onslaught_stop_run = false

	-- Поворачиваем героя в сторону разбега
	caster:SetForwardVector(self.direction)

	-- Проигрываем звук начала зарядки
	caster:EmitSound("Hero_PrimalBeast.Onslaught.Channel")

	-- Накладываем модификатор зарядки, который переопределит анимацию на подготовку Onslaught
	caster:AddNewModifier(caster, self, "modifier_primal_beast_onslaught_charge", {})

	-- Подменяем способность на Release, чтобы повторное нажатие Q запускало разбег
	caster:SwapAbilities("primal_beast_onslaught_custom", "primal_beast_onslaught_release", false, true)

	-- Создаем партикл стрелки индикатора дальности (виден только союзникам)
	self.range_indicator = ParticleManager:CreateParticleForTeam("particles/units/heroes/hero_primal_beast/primal_beast_onslaught_range_finder.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster, caster:GetTeam())
	ParticleManager:SetParticleControl(self.range_indicator, 0, caster:GetAbsOrigin())
	ParticleManager:SetParticleControl(self.range_indicator, 1, caster:GetAbsOrigin() + self.direction * 300)

	-- Запускаем таймер для обновления длины стрелки и плавного поворота во время зарядки
	local time_passed = 0
	local max_run_distance = self:GetSpecialValueFor("max_run_distance")
	if max_run_distance <= 0 then max_run_distance = 1200 end

	Timers:CreateTimer(function()
		if not caster or caster:IsNull() or not caster:IsAlive() or not self.range_indicator then
			return nil
		end

		time_passed = time_passed + 0.03
		local max_charge_time = self:GetSpecialValueFor("max_charge_time")
		if max_charge_time <= 0 then max_charge_time = 1.2 end
		local charge_pct = math.min(time_passed / max_charge_time, 1.0)
		local current_dist = 300 + (max_run_distance - 300) * charge_pct

		-- Плавный поворот в сторону onslaught_target_point (задан при кликах ходьбы)
		if caster.onslaught_target_point then
			local desired_dir = (caster.onslaught_target_point - caster:GetAbsOrigin()):Normalized()
			desired_dir.z = 0
			if desired_dir:Length2D() > 0 then
				local current_angle = math.atan2(self.direction.y, self.direction.x)
				local desired_angle = math.atan2(desired_dir.y, desired_dir.x)
				
				local angle_diff = desired_angle - current_angle
				while angle_diff > math.pi do angle_diff = angle_diff - 2 * math.pi end
				while angle_diff < -math.pi do angle_diff = angle_diff + 2 * math.pi end
				
				-- Скорость поворота на месте: 0.03 радиан (~1.75 градусов) за 0.03с
				local max_turn = 0.03
				if math.abs(angle_diff) > max_turn then
					angle_diff = (angle_diff > 0 and max_turn) or -max_turn
				end
				
				current_angle = current_angle + angle_diff
				self.direction = Vector(math.cos(current_angle), math.sin(current_angle), 0):Normalized()
				caster:SetForwardVector(self.direction)
			end
		end

		local end_point = caster:GetAbsOrigin() + self.direction * current_dist
		ParticleManager:SetParticleControl(self.range_indicator, 0, caster:GetAbsOrigin())
		ParticleManager:SetParticleControl(self.range_indicator, 1, end_point)

		return 0.03
	end)
end

function primal_beast_onslaught_custom:OnChannelFinish(bInterrupted)
	local caster = self:GetCaster()
	
	caster.isOnslaughtCharging = false
	caster.isOnslaughtRunning = true

	-- Возвращаем основную способность обратно
	if caster:HasAbility("primal_beast_onslaught_release") then
		caster:SwapAbilities("primal_beast_onslaught_release", "primal_beast_onslaught_custom", false, true)
	end

	-- Снимаем модификатор зарядки и останавливаем звук
	caster:RemoveModifierByName("modifier_primal_beast_onslaught_charge")
	caster:StopSound("Hero_PrimalBeast.Onslaught.Channel")

	-- Уничтожаем партикл стрелки-индикатора мгновенно
	if self.range_indicator then
		ParticleManager:DestroyParticle(self.range_indicator, true)
		ParticleManager:ReleaseParticleIndex(self.range_indicator)
		self.range_indicator = nil
	end

	local charge_duration = GameRules:GetGameTime() - self.start_charge_time
	local max_charge_time = self:GetSpecialValueFor("max_charge_time")
	if max_charge_time <= 0 then max_charge_time = 1.2 end
	local charge_pct = math.min(charge_duration / max_charge_time, 1.0)
	if charge_pct < 0.15 then
		charge_pct = 0.15
	end

	-- Читаем значения из конфига способности
	local max_run_distance = self:GetSpecialValueFor("max_run_distance")
	if max_run_distance <= 0 then max_run_distance = 1200 end
	local speed = self:GetSpecialValueFor("charge_speed")
	if speed <= 0 then speed = 1400 end
	local knockback_distance = self:GetSpecialValueFor("knockback_distance")
	if knockback_distance <= 0 then knockback_distance = 1000 end

	local run_distance = 300 + (max_run_distance - 300) * charge_pct

	-- Проигрываем звук бега
	caster:EmitSound("Hero_PrimalBeast.Onslaught.Run")

	-- Накладываем модификатор бега, который переопределит анимацию бега на Onslaught (на четвереньках)
	caster:AddNewModifier(caster, self, "modifier_primal_beast_onslaught_run", {})

	-- Временно отключаем коллизии с игроками
	caster.collisionEnabled = false

	local tick_rate = 0.03
	local dist_per_tick = speed * tick_rate
	local traveled_distance = 0

	-- Таблица для отслеживания задетых за этот разбег врагов (чтобы не бить их каждый тик)
	local hit_enemies = {}

	Timers:CreateTimer(function()
		if not caster or caster:IsNull() or not caster:IsAlive() or caster.onslaught_stop_run or traveled_distance >= run_distance then
			-- Завершаем бег
			if caster and not caster:IsNull() then
				caster.collisionEnabled = true
				caster.isUsingOnslaught = false
				caster.isOnslaughtCharging = false
				caster.isOnslaughtRunning = false
				caster.onslaught_target_point = nil
				caster.onslaught_stop_run = false
				caster:StopSound("Hero_PrimalBeast.Onslaught.Run")
				caster:RemoveModifierByName("modifier_primal_beast_onslaught_run")
				if not caster.onslaught_interrupted_by_jump then
					caster:SetPhysicsVelocity(Vector(0, 0, 0))
				else
					caster.onslaught_interrupted_by_jump = nil
				end
			end
			return nil
		end

		-- Плавный поворот в движении в сторону onslaught_target_point (задан при кликах ходьбы)
		if caster.onslaught_target_point then
			local desired_dir = (caster.onslaught_target_point - caster:GetAbsOrigin()):Normalized()
			desired_dir.z = 0
			if desired_dir:Length2D() > 0 then
				local current_angle = math.atan2(self.direction.y, self.direction.x)
				local desired_angle = math.atan2(desired_dir.y, desired_dir.x)
				
				local angle_diff = desired_angle - current_angle
				while angle_diff > math.pi do angle_diff = angle_diff - 2 * math.pi end
				while angle_diff < -math.pi do angle_diff = angle_diff + 2 * math.pi end
				
				-- Скорость поворота в бегу: 0.025 радиан (~1.5 градусов) за 0.03с
				local max_turn = 0.025
				if math.abs(angle_diff) > max_turn then
					angle_diff = (angle_diff > 0 and max_turn) or -max_turn
				end
				
				current_angle = current_angle + angle_diff
				self.direction = Vector(math.cos(current_angle), math.sin(current_angle), 0):Normalized()
				caster:SetForwardVector(self.direction)
			end
		end

		local pos = caster:GetAbsOrigin()
		local next_pos = pos + self.direction * dist_per_tick

		-- Проверяем границы поля
		if not IsPointOnField(next_pos) then
			caster.collisionEnabled = true
			caster.isUsingOnslaught = false
			caster.isOnslaughtCharging = false
			caster.isOnslaughtRunning = false
			caster.onslaught_target_point = nil
			caster.onslaught_stop_run = false
			caster:StopSound("Hero_PrimalBeast.Onslaught.Run")
			caster:RemoveModifierByName("modifier_primal_beast_onslaught_run")
			caster:SetPhysicsVelocity(Vector(0, 0, 0))
			return nil
		end

		-- Перемещаем героя
		caster:SetAbsOrigin(next_pos)
		caster:SetForwardVector(self.direction)
		traveled_distance = traveled_distance + dist_per_tick

		-- Проверяем столкновения с героями (и врагами, и союзниками, урон полностью отсутствует)
		local team = caster:GetTeam()
		local targets = FindUnitsInRadius(
			team,
			next_pos,
			nil,
			150,
			DOTA_UNIT_TARGET_TEAM_BOTH,
			DOTA_UNIT_TARGET_HERO,
			DOTA_UNIT_TARGET_FLAG_NONE,
			FIND_ANY_ORDER,
			false
		)

		for _, target in ipairs(targets) do
			if target and not target:IsNull() and target:IsAlive() and target ~= caster and not hit_enemies[target:GetEntityIndex()] then
				hit_enemies[target:GetEntityIndex()] = true

				-- Отталкиваем цель
				target:EmitSound("Hero_PrimalBeast.Onslaught.Hit")
				local push_dir = (target:GetAbsOrigin() - next_pos):Normalized()
				push_dir.z = 0
				if push_dir:Length2D() == 0 then
					push_dir = self.direction
				end
				target:AddPhysicsVelocity(push_dir * knockback_distance)
			end
		end

		-- Проверяем столкновение с мячом
		local ball = Ball.unit
		if ball and not ball:IsNull() then
			local dist_to_ball = (ball:GetAbsOrigin() - next_pos):Length2D()
			if dist_to_ball <= 160 and not ball.controller then
				local time = GameRules:GetGameTime()
				if not self.last_kick_time or (time - self.last_kick_time) >= 0.15 then
					self.last_kick_time = time
					
					-- Пинаем мяч вперед
					local kick_dir = self.direction
					caster:EmitSound("Hero_PrimalBeast.Onslaught.Hit")

					KickBall({
						hero = caster,
						xy_velocity = 2200, -- Чуть быстрее скорости бега (которая 2100)
						z_velocity = 50, -- Почти по земле
						direction = kick_dir,
						type = 3,
						keys = { target_points = { ball:GetAbsOrigin() + kick_dir * 100 } }
					})

					-- Создаем визуальный эффект удара
					local hit_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_primal_beast/primal_beast_onslaught_impact.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball)
					ParticleManager:ReleaseParticleIndex(hit_pfx)
				end
			end
		end

		return tick_rate
	end)
end

--------------------------------------------------------------------------------

modifier_primal_beast_onslaught_charge = class({})

function modifier_primal_beast_onslaught_charge:IsHidden() return true end
function modifier_primal_beast_onslaught_charge:IsDebuff() return false end
function modifier_primal_beast_onslaught_charge:IsPurgable() return false end

function modifier_primal_beast_onslaught_charge:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
	}
end

function modifier_primal_beast_onslaught_charge:GetOverrideAnimation()
	return ACT_DOTA_CAST_ABILITY_1
end

function modifier_primal_beast_onslaught_charge:GetActivityTranslationModifiers()
	return "onslaught_charge"
end

--------------------------------------------------------------------------------

modifier_primal_beast_onslaught_run = class({})

function modifier_primal_beast_onslaught_run:IsHidden() return true end
function modifier_primal_beast_onslaught_run:IsDebuff() return false end
function modifier_primal_beast_onslaught_run:IsPurgable() return false end

function modifier_primal_beast_onslaught_run:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
	}
end

function modifier_primal_beast_onslaught_run:GetOverrideAnimation()
	return ACT_DOTA_RUN
end

function modifier_primal_beast_onslaught_run:GetActivityTranslationModifiers()
	return "onslaught_run"
end

--------------------------------------------------------------------------------

primal_beast_onslaught_release = class({})

function primal_beast_onslaught_release:OnSpellStart()
	local caster = self:GetCaster()
	local main_ability = caster:FindAbilityByName("primal_beast_onslaught_custom")
	if main_ability then
		caster:Interrupt()
	end
end
