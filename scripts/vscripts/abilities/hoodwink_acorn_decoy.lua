hoodwink_acorn_decoy = class({})

function hoodwink_acorn_decoy:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tree_burst.vpcf", context)
end

function hoodwink_acorn_decoy:OnSpellStart()
	if not IsServer() then return end
	local caster = self:GetCaster()
	local target_point = self:GetCursorPosition()
	local duration = self:GetSpecialValueFor("duration")
	local move_speed = self:GetSpecialValueFor("move_speed")
	if duration <= 0 then duration = 2.0 end
	if move_speed <= 0 then move_speed = 400 end

	-- Создаём иллюзию рядом с кастером
	local spawn_pos = caster:GetAbsOrigin()
	local decoy = CreateUnitByName(caster:GetUnitName(), spawn_pos, true, caster, caster, caster:GetTeamNumber())
	if not decoy or decoy:IsNull() then return end

	-- Иллюзия неконтролируема
	decoy:SetControllableByPlayer(caster:GetPlayerOwnerID(), false)
	decoy:SetCanSellItems(false)
	decoy:SetHasInventory(false)
	decoy.noball = true
	decoy.isDecoy = true

	-- Синеватый оттенок как у иллюзии
	decoy:SetRenderColor(100, 180, 255)

	-- Не участвует в физических коллизиях мяча
	Banjoball:SetupPhysicsSettings(decoy)
	decoy:SetPhysicsVelocity(Vector(0, 0, 0))

	local pfx_spawn = ParticleManager:CreateParticle("particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tree_burst.vpcf", PATTACH_ABSORIGIN, decoy)
	ParticleManager:ReleaseParticleIndex(pfx_spawn)

	-- Движение к точке каждый фрейм
	local flat_target = Vector(target_point.x, target_point.y, spawn_pos.z)
	local arrived = false

	Timers:CreateTimer(0, function()
		if not decoy or decoy:IsNull() or not decoy:IsAlive() then return end
		if arrived then return end

		local pos = decoy:GetAbsOrigin()
		local to_target = flat_target - pos
		local dist = to_target:Length2D()

		if dist <= 20 then
			arrived = true
			decoy:SetPhysicsVelocity(Vector(0, 0, 0))
			decoy:SetAbsOrigin(flat_target)

			-- Стоим 2 секунды и исчезаем
			Timers:CreateTimer(duration, function()
				if decoy and not decoy:IsNull() and decoy:IsAlive() then
					local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_tree_burst.vpcf", PATTACH_ABSORIGIN, decoy)
					ParticleManager:ReleaseParticleIndex(pfx)
					decoy:ForceKill(true)
				end
			end)
			return
		end

		local step = to_target:Normalized() * math.min(move_speed * FrameTime(), dist)
		local new_pos = pos + step
		new_pos.z = spawn_pos.z
		decoy:SetAbsOrigin(new_pos)

		-- Поворачиваем лицом по направлению движения
		decoy:SetForwardVector(to_target:Normalized())

		return FrameTime()
	end)
end
