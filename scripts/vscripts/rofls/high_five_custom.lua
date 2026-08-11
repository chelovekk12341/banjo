
--  Original Dota
--	"DOTA_HighFive_Completed"	"%s1 and %s2 just High Fived."
--	"DOTA_HighFive_LeftHanging"	"%s1 tried to High Five but was left hanging."

HIGH_FIVE_PAIRS = {
	{
		name = "fall_2021",
		overhead = "particles/high_five/fall_2021/high_five_fall_2021_overhead.vpcf",
		travel   = "particles/high_five/fall_2021/high_five_fall_2021_travel.vpcf",
		impact   = "particles/high_five/fall_2021/high_five_fall_2021_impact.vpcf"
	},
	{
		name = "mug",
		overhead = "particles/high_five/mug/high_five_mug_overhead.vpcf",
		travel   = "particles/high_five/mug/high_five_mug_travel.vpcf",
		impact   = "particles/high_five/mug/high_five_mug_impact.vpcf"
	},
	{
		name = "agh_2021",
		overhead = "particles/high_five/agh_2021/high_five_agh_2021_overhead.vpcf",
		travel   = "particles/high_five/agh_2021/high_five_agh_2021_travel.vpcf",
		impact   = "particles/high_five/agh_2021/high_five_agh_2021_impact.vpcf"
	},
	{
		name = "crownfall",
		overhead = "particles/high_five/crownfall/high_five_crownfall_overhead.vpcf",
		travel   = "particles/high_five/crownfall/high_five_crownfall_travel.vpcf",
		impact   = "particles/high_five/crownfall/high_five_crownfall_impact.vpcf"
	},
	{
		name = "newbloom_dragon",
		overhead = "particles/high_five/newbloom_dragon/high_five_newbloom_dragon_overhead.vpcf",
		travel   = "particles/high_five/newbloom_dragon/high_five_newbloom_dragon_travel.vpcf",
		impact   = "particles/high_five/fall_2021/high_five_fall_2021_impact.vpcf"
	},
	{
		name = "poogie",
		overhead = "particles/high_five/poogie/high_five_poogie_overhead.vpcf",
		travel   = "particles/high_five/poogie/high_five_poogie_travel.vpcf",
		impact   = "particles/high_five/poogie/high_five_poogie_impact.vpcf"
	},
	{
		name = "dark_carnival",
		overhead = "particles/high_five/dark_carnival/high_five_dark_carnival_overhead.vpcf",
		travel   = "particles/high_five/dark_carnival/high_five_dark_carnival_travel.vpcf",
		impact   = "particles/high_five/dark_carnival/high_five_dark_carnival_impact.vpcf"
	},
	{
		name = "zombie",
		overhead = "particles/high_five/zombie/high_five_lvl1_overhead.vpcf",
		travel   = "particles/high_five/zombie/high_five_lvl1_travel.vpcf",
		impact   = "particles/high_five/fall_2021/high_five_fall_2021_impact.vpcf"
	},
	{
		name = "soap",
		overhead = "particles/high_five/soap/high_five_lvl1_overhead.vpcf",
		travel   = "particles/high_five/soap/high_five_lvl1_travel.vpcf",
		impact   = "particles/high_five/mug/high_five_mug_impact.vpcf"
	},
	{
		name = "cat_paw",
		overhead = "particles/high_five/cat_paw/high_five_lvl3_overhead.vpcf",
		travel   = "particles/high_five/cat_paw/high_five_lvl3_travel.vpcf",
		impact   = "particles/high_five/cat_paw/high_five_lvl3_hearts_impact.vpcf"
	},
	{
		name = "midas",
		overhead = "particles/high_five/midas/high_five_lvl3_overhead.vpcf",
		travel   = "particles/high_five/midas/high_five_lvl3_travel.vpcf",
		impact = "particles/econ/events/battlepass_ti10/high_five_ti10_impact.vpcf"
	},
	{
		name = "mitten",
		overhead = "particles/high_five/mitten/high_five_lvl2_overhead_2019.vpcf",
		travel   = "particles/high_five/mitten/high_five_lvl2_travel_2019.vpcf",
		impact   = "particles/high_five/mitten/high_five_impact_snow.vpcf"
	},
}

item_hf = item_hf or class({})
LinkLuaModifier("modifier_high_five_custom_search", "rofls/high_five_custom", LUA_MODIFIER_MOTION_NONE)


function item_hf:GetHero()
	local caster = self:GetCaster()
	local player_id = caster:GetPlayerOwnerID()
	local hero = PlayerResource:GetSelectedHeroEntity(player_id)
	return hero or caster
end

local HF_COOLDOWN = 20
local hf_last_cast = {}
function GetHighFiveIndexByName(name)
	if not name then return 1 end
	if type(name) == "number" then
		if name < 1 or name > #HIGH_FIVE_PAIRS then return 1 end
		return name
	end
	local num = tonumber(name)
	if num then
		if num < 1 or num > #HIGH_FIVE_PAIRS then return 1 end
		return num
	end
	for i, pair in ipairs(HIGH_FIVE_PAIRS) do
		if pair.name == name then
			return i
		end
	end
	return 1
end

function GetHighFiveNameByIndex(index)
	local i = tonumber(index) or 1
	if i < 1 or i > #HIGH_FIVE_PAIRS then i = 1 end
	return HIGH_FIVE_PAIRS[i].name
end

_G.HF_PlayerChoices = _G.HF_PlayerChoices or {}  -- Глобальная таблица для сохранения выбора между reload

-- Вызывается из addon_game_mode после инициализации игры
function InitHighFiveEvents()
	-- Избегаем повторной регистрации при ручном вызове
	if _G.HF_SelectListenerRegistered then return end
	_G.HF_SelectListenerRegistered = true

	CustomGameEventManager:RegisterListener("hf_select", function(_, data)
		local playerID = tonumber(data.PlayerID or data.playerid or data.playerID)
		if not playerID then 
			print("[HF_DEBUG] Received hf_select but playerID is nil")
			return 
		end
		
		local skinName = data.index
		local index = GetHighFiveIndexByName(skinName)
		skinName = HIGH_FIVE_PAIRS[index].name -- нормализуем до строки
		
		_G.HF_PlayerChoices[playerID] = skinName
		print("[HF_DEBUG] Player " .. tostring(playerID) .. " selected skin: " .. tostring(skinName))

		-- По умолчанию открыты все пятюни
		local default_open = _G.ALL_HIGH_FIVES

		-- Обновляем инвентарь локально
		local inventory = { shards = 0, open_high_fives = default_open, chosen_high_five = skinName }
		if GameRules.Banjoball and GameRules.Banjoball.vFullinfo then
			local ply_info = GameRules.Banjoball.vFullinfo[playerID]
			if ply_info then
				if type(ply_info["inventory"]) ~= "table" then
					ply_info["inventory"] = { shards = 0, open_high_fives = default_open }
				end
				ply_info["inventory"]["chosen_high_five"] = skinName
				ply_info["inventory"]["open_high_fives"] = default_open -- Гарантированно перезаписываем в инвентаре
				inventory = ply_info["inventory"]
			end
		end

		-- Отправляем обновление в Supabase
		local steam_id = tostring(PlayerResource:GetSteamAccountID(playerID))
		if steam_id and steam_id ~= "0" then
			local url = SUPABASE_URL .. "/rest/v1/players"
			local req = CreateHTTPRequestScriptVM("POST", url)
			if not req then
				print("[Supabase] Warning: CreateHTTPRequestScriptVM returned nil. Probably in local offline mode.")
				return
			end
			req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
			req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
			req:SetHTTPRequestHeaderValue("Content-Type", "application/json")
			req:SetHTTPRequestHeaderValue("Prefer", "resolution=merge-duplicates")
			req:SetHTTPRequestHeaderValue("x-custom-auth", SUPABASE_AUTH_KEY)
			
			local body = json.encode({
				steam_id = steam_id,
				inventory = inventory
			})
			req:SetHTTPRequestRawPostBody("application/json", body)
			req:SetHTTPRequestAbsoluteTimeoutMS(100000)
			
			req:Send(function(res)
				if res.StatusCode == 200 or res.StatusCode == 204 then
					print("[Supabase] Updated player inventory successfully for SteamID: " .. steam_id .. " skinName: " .. skinName)
				else
					print("[Supabase] Failed to update inventory: status=" .. tostring(res.StatusCode) .. " body=" .. tostring(res.Body))
				end
			end)
		end

		-- Синхронизируем UI с новыми данными
		local ply_ent = PlayerResource:GetPlayer(playerID)
		if ply_ent then
			CustomGameEventManager:Send_ServerToPlayer(ply_ent, "hf_state", {
				playerID = playerID,
				chosen = skinName,
				open_high_fives = inventory.open_high_fives,
				shards = tonumber(inventory.shards) or 0
			})
		end
	end)
end

-- Авто-инициализация при перезагрузке файла в процессе игры
if CustomGameEventManager then
	InitHighFiveEvents()
end

function item_hf:OnSpellStart()
	if not IsServer() then return end
	local hero = self:GetHero()
	local playerID = hero:GetPlayerOwnerID()
	local now = GameRules:GetGameTime()
	local last = hf_last_cast[playerID] or -999
	local remaining = HF_COOLDOWN - (now - last)

	if remaining > 0 then
		DisplayErrorWithValue(playerID, "Перезарядка ##time## сек.", { time = string.format("%.1f", remaining) })
		return
	end

	hf_last_cast[playerID] = now

	local choice = _G.HF_PlayerChoices[tonumber(playerID)] or "fall_2021"
	local choiceIndex = GetHighFiveIndexByName(choice)
	print("[HF_DEBUG] OnSpellStart: PlayerID " .. tostring(playerID) .. " choice " .. tostring(choice) .. " index " .. tostring(choiceIndex))
	local pair = HIGH_FIVE_PAIRS[choiceIndex]
	self.current_high_five_particle = pair.overhead
	self.current_high_five_travel_particle = pair.travel
	self.current_high_five_impact_particle = pair.impact
	print("[HF_DEBUG] Setting current_high_five_particle to " .. tostring(self.current_high_five_particle))

	hero:AddNewModifier(hero, self, "modifier_high_five_custom_search", {duration = 10})
	EmitSoundOn("high_five.cast", hero)

	self:UseResources(false, false, false, true)
end


function item_hf:OnProjectileHit(target, location)
	if not IsServer() then return end

	local hero = self:GetHero()

	local impact_particle = self.current_high_five_impact_particle or "particles/high_five/fall_2021/high_five_fall_2021_impact.vpcf"

	local impact_p_id = ParticleManager:CreateParticle(impact_particle, PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControl(impact_p_id, 0, location)
	ParticleManager:SetParticleControl(impact_p_id, 3, location)
	ParticleManager:ReleaseParticleIndex(impact_p_id)

	EmitSoundOnLocationWithCaster(location, "high_five.impact", hero)
end



modifier_high_five_custom_search = modifier_high_five_custom_search or class({})


function modifier_high_five_custom_search:IsPurgable() return false end
function modifier_high_five_custom_search:IsHidden() return true end


function modifier_high_five_custom_search:OnCreated()
	self.parent = self:GetParent()
	self.ability = self:GetAbility()

	self.search_radius = 700--self.ability:GetSpecialValueFor("acknowledge_range")
	self.base_velocity = 700--self.ability:GetSpecialValueFor("high_five_speed")
	self.interval = 0.1--self.ability:GetSpecialValueFor("think_interval")

	if not IsServer() then return end

	self:StartIntervalThink(self.interval)
	self.wave_particle_path = "particles/high_five/fall_2021/high_five_fall_2021_overhead.vpcf"
	if self.ability and self.ability.current_high_five_particle then
		self.wave_particle_path = self.ability.current_high_five_particle
	end
	self.travel_particle_path = "particles/high_five/fall_2021/high_five_fall_2021_travel.vpcf"
	if self.ability and self.ability.current_high_five_travel_particle then
		self.travel_particle_path = self.ability.current_high_five_travel_particle
	end
	print("[HF_DEBUG] Modifier Server OnCreated: wave=" .. tostring(self.wave_particle_path) .. " travel=" .. tostring(self.travel_particle_path))

	-- Создаем партикль над головой вручную на сервере
	self.overhead_particle_id = ParticleManager:CreateParticle(self.wave_particle_path, PATTACH_OVERHEAD_FOLLOW, self.parent)
end


function modifier_high_five_custom_search:LaunchTowards(target)
	if self._proc then return end
	self._proc = true

	local travel_particle = self.travel_particle_path or "particles/high_five/fall_2021/high_five_fall_2021_travela.vpcf"

	local origin = self.parent:GetAbsOrigin()
	local center = (target:GetAbsOrigin() + origin) / 2
	local distance_vector = center - origin

	ProjectileManager:CreateLinearProjectile({
		Source = self.parent,
		Ability = self.ability,
		vSpawnOrigin = self.parent:GetAbsOrigin(),

	    EffectName = travel_particle,
	    fDistance = distance_vector:Length2D(),
	    fStartRadius = 10,
	    fEndRadius = 10,
		vVelocity = distance_vector:Normalized() * self.base_velocity,
	})

	self:Destroy()
end


function modifier_high_five_custom_search:OnIntervalThink()
	local units = FindUnitsInRadius(
		self.parent:GetTeamNumber(),
		self.parent:GetOrigin(),
		self.parent,
		self.search_radius,
		DOTA_UNIT_TARGET_TEAM_BOTH,
		DOTA_UNIT_TARGET_HERO,
		DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		FIND_CLOSEST,
		false
	)

	for _, unit in pairs(units) do
		if IsValidEntity(unit) and unit ~= self.parent then
			local high_five_modifier = unit:FindModifierByName("modifier_high_five_custom_search")

			if high_five_modifier and not high_five_modifier._proc then
				high_five_modifier:LaunchTowards(self.parent)
				self:LaunchTowards(unit)

				local player_1 = self.parent:GetPlayerOwnerID()
				local team_1 = self.parent:GetTeam()

				local player_2 = unit:GetPlayerOwnerID()
				local team_2 = unit:GetTeam()

				local is_ally = team_1 == team_2

				if is_ally then
					CustomGameEventManager:Send_ServerToTeam(team_1, "custom_hive_five", {
						player_1 = player_1,
						player_2 = player_2,
						is_ally = true
					})
				else
					CustomGameEventManager:Send_ServerToAllClients("custom_hive_five", {
						player_1 = player_1,
						player_2 = player_2,
						is_ally = false
					})
				end

				return
			end
		end
	end
end


function modifier_high_five_custom_search:OnDestroy()
	if not IsServer() then return end

	if self.overhead_particle_id then
		ParticleManager:DestroyParticle(self.overhead_particle_id, false)
		ParticleManager:ReleaseParticleIndex(self.overhead_particle_id)
		self.overhead_particle_id = nil
	end

	if self._proc then return end
	local parent = self:GetParent()
	if not parent or not IsValidEntity(parent) then return end
	local playerID = parent:GetPlayerOwnerID()
	if playerID < 0 then return end
	GameRules:SendCustomMessage("#DOTA_HighFive_LeftHanging", playerID, 0)
end
