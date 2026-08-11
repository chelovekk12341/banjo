ice_snows = class({})

function ice_snows:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_tusk/tusk_ice_snows_base.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tusk.vsndevts", context)
	PrecacheResource("model", "models/particle/ice_shards.vmdl", context)
end

function ice_snows:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	
	if not target or target:IsNull() then return end
	
	local duration = self:GetSpecialValueFor("duration")
	if duration <= 0 then duration = 5.0 end
	
	local P1 = caster:GetAbsOrigin()
	local P2 = target:GetAbsOrigin()
	local R = 350 -- радиус овала вокруг героев
	
	local dir = (P2 - P1)
	local dist = dir:Length2D()
	if dist == 0 then
		dir = caster:GetForwardVector()
	else
		dir = dir:Normalized()
	end
	local perp = Vector(-dir.y, dir.x, 0):Normalized()
	
	-- Воспроизводим звук на кастере
	caster:EmitSound("Hero_Tusk.IceShards")
	
	local points = {}
	local step = 150 -- шаг распределения точек (уменьшено в 2 раза по запросу пользователя)
	
	-- 1. Полукруг позади кастера (P1)
	-- Распределяем точки по дуге от -pi/2 до pi/2
	local num_arc_points = math.ceil((math.pi * R) / step) + 1
	local d_theta = math.pi / (num_arc_points - 1)
	
	for j = 0, num_arc_points - 1 do
		local theta = -math.pi/2 + j * d_theta
		local offset = -dir * math.cos(theta) + perp * math.sin(theta)
		local pos = P1 + offset * R
		table.insert(points, pos)
	end
	
	-- 2. Полукруг позади цели (P2)
	-- Точки идут от P2 + perp * R до P2 - perp * R
	for j = 0, num_arc_points - 1 do
		local theta = -math.pi/2 + j * d_theta
		local offset = dir * math.cos(theta) - perp * math.sin(theta)
		local pos = P2 + offset * R
		table.insert(points, pos)
	end
	
	-- 3. Продольные боковые линии
	-- Левая боковая линия: от P1 + perp * R до P2 + perp * R
	-- Правая боковая линия: от P1 - perp * R до P2 - perp * R
	-- Исключаем крайние точки, чтобы не дублировать концы полукругов
	local num_side_points = math.ceil(dist / step) - 1
	if num_side_points > 0 then
		local d_dist = dist / (num_side_points + 1)
		for k = 1, num_side_points do
			local t = k * d_dist
			table.insert(points, P1 + dir * t + perp * R)
			table.insert(points, P1 + dir * t - perp * R)
		end
	end
	
	local shards = {}
	
	for _, shard_pos in ipairs(points) do
		shard_pos = GetGroundPosition(shard_pos, nil)
		
		-- Спавним dummy-юнит через CreateProjectile под землей с маленьким масштабом
		local start_pos = Vector(shard_pos.x, shard_pos.y, shard_pos.z - 150)
		local shard = Banjoball:CreateProjectile(PROJECTILE_INDEX_SWAP, caster, 100, Vector(0,0,0), 0.05, start_pos, true)
		shard:StopPhysicsSimulation()
		
		shard:SetOriginalModel("models/particle/ice_shards.vmdl")
		shard:SetModel("models/particle/ice_shards.vmdl")
		shard:SetModelScale(0.05)
		
		-- Анимация вырастания (0.24 секунды, 8 шагов с интервалом 0.03)
		local anim_duration = 0.24
		local interval = 0.03
		local steps = math.ceil(anim_duration / interval)
		local current_step = 0
		
		Timers:CreateTimer(function()
			if shard and not shard:IsNull() then
				current_step = current_step + 1
				local t = current_step / steps
				
				-- Плавная интерполяция масштаба от 0.05 до 0.8 (ease-out с синусом)
				local smooth_t = math.sin(t * math.pi / 2)
				local current_scale = 0.05 + (0.8 - 0.05) * smooth_t
				shard:SetModelScale(current_scale)
				
				-- Плавная интерполяция Z от (shard_pos.z - 150) до shard_pos.z
				local current_z = (shard_pos.z - 150) + 150 * smooth_t
				shard:SetAbsOrigin(Vector(shard_pos.x, shard_pos.y, current_z))
				
				if current_step < steps then
					return interval
				end
			end
		end)
		
		-- Добавляем коллайдер 'circlenom'
		local collider = shard:AddColliderFromProfile('circlenom')
		collider.radius = 100
		collider.multiplier = 0.5
		collider.skipFrames = 2 -- Проверка коллизии раз в 3 кадра физики для сильной оптимизации
		collider.filter = Banjoball.colliderFilter
		
		-- Проверка коллизии: мяч на высоте (навесом) перелетает осколок
		collider.test = function(self, colder, unit)
			if unit and unit.isBall then
				local ball_pos = unit:GetAbsOrigin()
				local height = ball_pos.z - GroundZ
				if height > 40 then
					return false
				end
			end
			return true
		end
		
		-- Блокируем движение героев с помощью point_simple_obstruction
		local obstacle = SpawnEntityFromTableSynchronous("point_simple_obstruction", {
			origin = shard_pos,
			block_fow = 0,
			StartDisabled = 0
		})
		
		table.insert(shards, {
			unit = shard,
			obstacle = obstacle
		})
	end
	
	-- Удаляем осколки по истечении времени
	Timers:CreateTimer(duration, function()
		for _, shard_data in ipairs(shards) do
			if shard_data.obstacle and not shard_data.obstacle:IsNull() then
				shard_data.obstacle:RemoveSelf()
			end
			
			if shard_data.unit and not shard_data.unit:IsNull() then
				local shard_unit = shard_data.unit
				
				-- Отключаем коллизию с мячом мгновенно перед анимацией исчезновения
				if shard_unit.colliderID then
					Banjoball.colliderFilter[shard_unit.colliderID] = nil
				end
				
				local start_pos = shard_unit:GetAbsOrigin()
				
				-- Анимация ухода под землю (0.24 секунды)
				local anim_duration = 0.24
				local interval = 0.03
				local steps = math.ceil(anim_duration / interval)
				local current_step = 0
				
				Timers:CreateTimer(function()
					if shard_unit and not shard_unit:IsNull() then
						current_step = current_step + 1
						local t = current_step / steps
						
						-- Плавная интерполяция удаления (ease-in: t^2)
						local smooth_t = t * t
						
						-- Интерполяция масштаба от 0.8 до 0.05
						local current_scale = 0.8 - (0.8 - 0.05) * smooth_t
						shard_unit:SetModelScale(math.max(0.01, current_scale))
						
						-- Интерполяция Z вниз на 150 единиц
						local current_z = start_pos.z - 150 * smooth_t
						shard_unit:SetAbsOrigin(Vector(start_pos.x, start_pos.y, current_z))
						
						if current_step >= steps then
							Banjoball:DestroyProjectile(shard_unit)
							return nil
						end
						return interval
					end
				end)
			end
		end
	end)
end
