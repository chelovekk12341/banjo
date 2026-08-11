drinking_buddies = class({})

function drinking_buddies:Precache(context)
end

function drinking_buddies:CastFilterResultTarget(hTarget)
	if hTarget == self:GetCaster() then
		return UF_FAIL_CUSTOM
	end

	local nResult = UnitFilter(
		hTarget,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_NONE,
		self:GetCaster():GetTeamNumber()
	)
	
	if nResult ~= UF_SUCCESS then
		return nResult
	end

	return UF_SUCCESS
end

function drinking_buddies:GetCustomCastErrorTarget(hTarget)
	if hTarget == self:GetCaster() then
		return "Нельзя применять на себя"
	end

	local nResult = UnitFilter(
		hTarget,
		DOTA_UNIT_TARGET_TEAM_FRIENDLY,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_NONE,
		self:GetCaster():GetTeamNumber()
	)
	
	if nResult ~= UF_SUCCESS then
		if nResult == UF_FAIL_ENEMY then
			return "Нельзя применять на врагов"
		elseif nResult == UF_FAIL_HERO then
			return "Можно применять только на героев"
		end
		return "Неверная цель"
	end

	return ""
end

function drinking_buddies:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()

	if not target or target:IsNull() or not target:IsAlive() or target == caster then return end

	local duration = self:GetSpecialValueFor("duration")
	if duration <= 0 then duration = 0.5 end

	-- Отключаем коллизии и навигационную сетку для пролета сквозь осколки
	caster.collisionEnabled = false
	caster:SetNavCollisionType(PHYSICS_NAV_NOTHING)
	caster:SetPhysicsVelocity(Vector(0,0,0))

	-- Запускаем анимацию скольжения/полета (FLAIL)
	pcall(function() caster:StartGesture(ACT_DOTA_FLAIL) end)

	-- Звук притягивания
	caster:EmitSound("Hero_Tusk.DrinkingBuddies.Cast")

	local tick = FRAME_TIME -- 0.03
	local steps = math.ceil(duration / tick)
	local current_step = 0

	Timers:CreateTimer(function()
		local caster_pos = caster:GetAbsOrigin()
		local target_pos = target:GetAbsOrigin()
		local dir = (target_pos - caster_pos)
		local dist = dir:Length()

		-- Завершаем, если цель мертва, вышло время или мы уже на расстоянии 150
		if not target or target:IsNull() or not target:IsAlive() or not caster:IsAlive() or current_step >= steps or dist <= 150 then
			-- Завершаем перемещение
			caster.collisionEnabled = true
			caster:SetNavCollisionType(PHYSICS_NAV_BOUNCE)
			caster:SetPhysicsVelocity(Vector(0,0,0))
			pcall(function()
				caster:FadeGesture(ACT_DOTA_FLAIL)
			end)
			return nil
		end

		current_step = current_step + 1
		local remaining_steps = steps - current_step + 1

		-- Целевая точка на расстоянии 150 от союзника по направлению к кастеру
		local target_point = target_pos - dir:Normalized() * 150
		local move_vec = target_point - caster_pos
		local move_dist = move_vec:Length()

		local new_pos = caster_pos
		if move_dist > 10 then
			new_pos = caster_pos + move_vec:Normalized() * (move_dist / remaining_steps)
		else
			new_pos = target_point
		end

		-- Поворачиваем героя в сторону движения
		if dir:Length2D() > 10 then
			caster:SetForwardVector(dir:Normalized())
		end

		-- Ограничиваем рамками поля
		if not IsPointOnField(new_pos) then
			new_pos = ClosestPointOnField(new_pos)
		end

		caster:SetAbsOrigin(new_pos)

		return tick
	end)
end
