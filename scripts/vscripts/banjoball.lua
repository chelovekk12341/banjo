print ('[BANJOBALL] banjoball.lua' )

RoundsCompleted = 0

-- define classes
Ball = {}

DummyNames =
{
	[1] = "Arhowk",
	[2] = "Londar",
	[3] = "Ordinator",
	[4] = "MadWhiskas",
	[5] = "Drunk",
	[6] = "KingFisher",
	[7] = "Amynes",
	[8] = "Chris",
	[9] = "Jim",
	[10] = "Dan",
	[11] = "Ludicrous",
}

-- Generated from template
if Banjoball == nil then
	--print ( '[BANJOBALL] creating banjoball game mode' )
	Banjoball = class({})
end

function Banjoball:PostLoadPrecache()
	--print("[BANJOBALL] Performing Post-Load precache")

	PrecacheUnitByNameAsync("npc_precache_everything", function(...) end)
end

--[[
  This function is called once and only once as soon as the first player (almost certain to be the server in local lobbies) loads in.
  It can be used to initialize state that isn't initializeable in InitBanjoball() but needs to be done before everyone loads in.
]]
function Banjoball:OnFirstPlayerLoaded()
	--print("[BANJOBALL] First Player has loaded")
end

function Banjoball:SetMatchStatusAbandoned(match_id)
	if not match_id then return end
	local url = SUPABASE_URL .. "/rest/v1/matches?match_id=eq." .. match_id
	local req = CreateHTTPRequestScriptVM("PATCH", url)
	req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Content-Type", "application/json")
	req:SetHTTPRequestHeaderValue("x-custom-auth", SUPABASE_AUTH_KEY)

	local body = json.encode({
		status = "abandoned",
		finished_at_msc = Banjoball:GetMSKTimeISO()
	})

	req:SetHTTPRequestRawPostBody("application/json", body)
	req:Send(function(res)
		if res.StatusCode == 204 or res.StatusCode == 200 then
			print("[Supabase] Match status set to abandoned successfully: " .. match_id)
		else
			print("[Supabase] Failed to set match status to abandoned: " .. tostring(res.StatusCode) .. " body: " .. tostring(res.Body))
		end
	end)
end

--[[
  This function is called once and only once after all players have loaded into the game, right as the hero selection time begins.
  It can be used to initialize non-hero player state or adjust the hero selection (i.e. force random etc)
]]
function Banjoball:OnAllPlayersLoaded()
	local ball = Ball.unit

	PlayerCount = 0
	if true then
		Playerstrist = ""
		for i,v in pairs(Banjoball.vFullinfo) do
			if v["Steam"] ~= nil then
				local manys = ""
				if Playerstrist ~= "" then
					manys = ","
				end
				Playerstrist = Playerstrist..manys..tostring(v["Steam"])
			end
		end
		print("[Supabase] Requesting Steam IDs: " .. tostring(Playerstrist))
		if not NOMMR then
			Banjoball:GetInfo({Playerstrist}, function(res) 
				if res then
					local decoded = json.decode(res.Body)
					if decoded then
						for _, jse in pairs(decoded) do
							local plyid = self.vSteamIds[tonumber(jse.steam_id)]
							local fullply = self.vFullinfo[plyid]
							if fullply and fullply["Ply"]:GetTeam() ~= DOTA_TEAM_CUSTOM_1 then
								fullply["MMR"] = tonumber(jse.mmr) or 1000
								fullply["WINS"] = tonumber(jse.wins) or 0
								fullply["LOSE"] = tonumber(jse.lose) or 0
								fullply["Banned"] = jse.banned or false
								fullply["last_double_down_at"] = jse.last_double_down_at
								fullply["last_double_down_unix"] = ParseISO8601(jse.last_double_down_at)
								print(string.format("[DoubleDown] Loaded from DB: steam_id=%s, last_double_down_at=%s, parsed_unix=%s", 
									tostring(jse.steam_id), tostring(jse.last_double_down_at), tostring(fullply["last_double_down_unix"])))
								fullply["cam_distance"] = tonumber(jse.camera_distance) or 2000
								if jse.camera_locked ~= nil then
									fullply["cam_locked"] = (jse.camera_locked == true or jse.camera_locked == 1)
								else
									fullply["cam_locked"] = false
								end

								-- Загружаем инвентарь игрока
								local default_open = {"fall_2021", "mug", "agh_2021", "crownfall", "newbloom_dragon"}
								local default_open_ranges = {
									"custom_range_display_green",
									"custom_range_display_purple",
									"custom_range_display_red",
									"custom_range_display_yellow",
									"custom_range_display_orange"
								}
								
								local raw_inventory = fullply["inventory"] or jse.inventory or {}
								if type(raw_inventory) == "string" then
									local success, decoded_inv = pcall(json.decode, raw_inventory)
									if success and type(decoded_inv) == "table" then
										raw_inventory = decoded_inv
									end
								end
								
								fullply["inventory"] = raw_inventory
								if type(fullply["inventory"]) ~= "table" then
									fullply["inventory"] = {}
								end
								
								fullply["inventory"]["shards"] = fullply["inventory"]["shards"] or 0
								fullply["inventory"]["open_high_fives"] = _G.ALL_HIGH_FIVES
								fullply["inventory"]["chosen_high_five"] = fullply["inventory"]["chosen_high_five"] or "fall_2021"
								fullply["inventory"]["chosen_range"] = fullply["inventory"]["chosen_range"] or "custom_range_display_green"
								fullply["inventory"]["open_ball_effects"] = fullply["inventory"]["open_ball_effects"] or {"ball_hot", "snowy_vortex"}
								fullply["inventory"]["chosen_ball_effect"] = fullply["inventory"]["chosen_ball_effect"] or "ball_hot"
								
								local valid_range = false
								for _, name in ipairs(default_open_ranges) do
									if name == fullply["inventory"]["chosen_range"] then
										valid_range = true
										break
									end
								end
								if not valid_range then
									fullply["inventory"]["chosen_range"] = "custom_range_display_green"
								end
								
								fullply["inventory"]["open_ranges"] = fullply["inventory"]["open_ranges"] or default_open_ranges
								
								local skinChoice = fullply["inventory"]["chosen_high_five"]
								local idx = GetHighFiveIndexByName(skinChoice)
								skinChoice = HIGH_FIVE_PAIRS[idx].name
								
								_G.HF_PlayerChoices = _G.HF_PlayerChoices or {}
								_G.HF_PlayerChoices[plyid] = skinChoice
								
								local rangeChoice = fullply["inventory"]["chosen_range"]
								_G.Range_PlayerChoices = _G.Range_PlayerChoices or {}
								_G.Range_PlayerChoices[plyid] = rangeChoice

								local ballEffectChoice = fullply["inventory"]["chosen_ball_effect"]
								_G.Ball_PlayerChoices = _G.Ball_PlayerChoices or {}
								_G.Ball_PlayerChoices[plyid] = ballEffectChoice
								
								-- Отправляем скин на клиент для инициализации UI
								local ply_ent = PlayerResource:GetPlayer(plyid)
								if ply_ent then
									local shardsVal = tonumber(fullply["inventory"]["shards"]) or 0
									local openFives = fullply["inventory"]["open_high_fives"]
									local openRanges = fullply["inventory"]["open_ranges"]
									local openBallEffects = fullply["inventory"]["open_ball_effects"]
									
									Timers:CreateTimer(2.0, function()
										CustomGameEventManager:Send_ServerToPlayer(ply_ent, "hf_state", {
											playerID = plyid,
											chosen = skinChoice,
											open_high_fives = openFives,
											shards = shardsVal
										})
										
										CustomGameEventManager:Send_ServerToPlayer(ply_ent, "range_state", {
											playerID = plyid,
											chosen = rangeChoice,
											open_ranges = openRanges
										})

										CustomGameEventManager:Send_ServerToPlayer(ply_ent, "ball_effects_state", {
											playerID = plyid,
											chosen = ballEffectChoice,
											open_ball_effects = openBallEffects
										})
									end)
								end
								
								if jse.clicker_active ~= nil then
									fullply["clicker_active"] = (jse.clicker_active == true or jse.clicker_active == 1)
								else
									fullply["clicker_active"] = true
								end
								
								if jse.spells_hidden ~= nil then
									fullply["spells_hidden"] = (jse.spells_hidden == true or jse.spells_hidden == 1)
								else
									fullply["spells_hidden"] = false
								end
								
								if jse.ally_abilities_hidden ~= nil then
									fullply["ally_abilities_hidden"] = (jse.ally_abilities_hidden == true or jse.ally_abilities_hidden == 1)
								else
									fullply["ally_abilities_hidden"] = false
								end
							end
						end
						MMROK = true
					else
						MMROK = false
						print("[Supabase] Failed to decode JSON")
					end
				else
					MMROK = false
					print("[Supabase] GetInfo failed (res is false/nil)")
				end
				SITEOK = true
			end)
		else
			SITEOK=true
		end
	end
	for i=0,9 do
		if PlayerResource:IsValidPlayerID(i) then
			local ply = PlayerResource:GetPlayer(i)
			if ply and ply:GetTeam() ~= DOTA_TEAM_CUSTOM_1 then
				PlayerCount = PlayerCount + 1
				self.vPlayers[i] = ply
			end
		end
	end

	Timers:CreateTimer(.06, function()
		print("OnAllPlayersLoaded")
	end)

	Timers:CreateTimer(function()
		if not HeroSelectionOver or not AllPlayersSelectedHeroes then
			if not LastHeroSelectionNotification or GameRules:GetGameTime() - LastHeroSelectionNotification > 2.5 then
				ShowCenterMsg("WAITING ON PLAYERS TO SELECT HEROES", 2.5)
				LastHeroSelectionNotification = GameRules:GetGameTime()
			end
			return .1
		end
		if not SITEOK then--not GameRules:IsCheatMode() then
			return 0.1
		end
		
		for i,v in pairs(self.vFullinfo) do
			if v["Hero"] then
				if v["Banned"] ~= true and v["Banned"] ~= 1 then
					if PlayerResource:IsFakeClient(i) then
						self:InitializeBotHero(v["Hero"], v["Hero"]:GetTeam())
					else
						self:OnHeroInGameFirstTime(v["Hero"])
					end
					print('Firstly first')
				else
					v["Hero"]:AddNoDraw()
					v["Hero"]:ForceKill(true)
					v["Hero"]:SetTimeUntilRespawn( 99999 )
				end
			end
		end
		
		
		Ball.unit:SpawnParticle()

		HUMAN_GAME_TIME = GameRules:GetGameTime()
		CustomNetTables:SetTableValue("game_state", "timer", { stime = HUMAN_GAME_TIME })
		CustomNetTables:SetTableValue("game_state", "scoring_multipliers", {
			goal = SCORE_GOAL_POINTS,
			assist = SCORE_ASSIST_POINTS,
			steal = SCORE_STEAL_POINTS,
			turnover = math.abs(SCORE_TURNOVER_POINTS),
			pickup = SCORE_PICKUP_POINTS,
			pass = SCORE_PASS_POINTS,
			save = SCORE_SAVE_POINTS
		})
		CustomGameEventManager:Send_ServerToAllClients("gametime_counter_start", {stime = HUMAN_GAME_TIME})

		if not INTOOLS then
			local linesEng = 
			{
				[1] = ColorIt("Welcome in ", "yellow") .. ColorIt("Banjoball", "green") .. ColorIt("!", "yellow"),
				[2] = ColorIt("Score ", "yellow") .. ColorIt(SCORE_TO_WIN, "red") .. ColorIt(" goals to win the game!", "yellow"),
				-- [3] = ColorIt("Banjoball: Remastered", "green") .. ColorIt(" is originally based on ", "yellow") .. ColorIt("Banjoball: Alpha", "green"),
				-- [4] = ColorIt("Current (dead) developer is ", "yellow") .. ColorIt("LUDICROUS", "blue"),
				[5] = ColorIt("Good Luck!", "pink") .. ColorIt(" and Have Fun!!", "cyan"),
			}
			ShowQuickMessages( linesEng, 2 )

			local linesRus = 
			{
				[1] = ColorIt("Приветствуем в ", "yellow") .. ColorIt("Banjoball", "green") .. ColorIt("!", "yellow"),
				[2] = ColorIt("Забейте", "yellow") .. ColorIt(SCORE_TO_WIN, "red") .. ColorIt(" голов, чтобы победить!", "yellow"),
				-- [3] = ColorIt("Banjoball: Remastered", "green") .. ColorIt(" основан на ", "yellow") .. ColorIt("Banjoball: Alpha", "green"),
				-- [4] = ColorIt("Текущий (мёртвый) разработчик - ", "yellow") .. ColorIt("ЛУДИК", "blue"),
				[5] = ColorIt("Удачи!", "pink") .. ColorIt(" и весёлой игры!!", "cyan"),
			}
			ShowQuickMessages( linesRus, 2.05 )

			local lines = 
			{
				[1] = "10...",
				[2] = "8...",
				[3] = "6...",
				[4] = "4...",
				[5] = "2... ",
			}
			ShowQuickMessages( lines, 2.1 )
			
			
			local roundCountdownSet = RandomInt(1, #RoundCountdownSounds)
			local count = PRE_FIRSTROUND_START
			Timers:CreateTimer(function()
				if count == 0 then
					GameRules:SendCustomMessage("PLAY!", 0, 0)
					EmitGlobalSound("Round_Start" .. RandomInt(1, NumRoundStartSounds))
					return
				end

				EmitGlobalSound("RoundCountdown" .. roundCountdownSet .. "_" .. RandomInt(1, roundCountdownSet))
				count = count - 2

				return 2
			end)
		end

		ParticleManager:CreateParticle("particles/econ/events/ti5/blink_dagger_end_ti5.vpcf", PATTACH_ABSORIGIN, Ball.unit.particleDummy)

		Timers:CreateTimer(PRE_FIRSTROUND_START, function()
			for _,hero in ipairs(Banjoball.vHeroes) do
				RemoveEndgameRoot(hero)
				RemoveSilence(hero)
			end

			print("RoundInProgress")

			RoundInProgress = true
		end)
	end)
end

function Banjoball:OnPreGameState(  )

end

-- Debug: spawn 9 hero units to visualize all 10 spawn positions.
-- Reads info_player_start_goodguys / badguys entities from the map.
-- Prints each unit's name and coordinates to console.
function Banjoball:SpawnDebugBots()
	if not DEBUG_SPAWN_BOTS then return end

	print("[DEBUG] SpawnDebugBots started")

	-- Collect spawn point entities from map
	local ggSpawns = Entities:FindAllByClassname("info_player_start_goodguys")
	local bgSpawns = Entities:FindAllByClassname("info_player_start_badguys")

	print(string.format("[DEBUG] Map has %d Goodguys spawn points, %d Badguys spawn points",
		#ggSpawns, #bgSpawns))

	-- Print all existing map spawn positions
	for i, ent in ipairs(ggSpawns) do
		local pos = ent:GetAbsOrigin()
		print(string.format("[MAP_SPAWN] GoodGuys #%d  X=%.1f  Y=%.1f  Z=%.1f", i, pos.x, pos.y, pos.z))
	end
	for i, ent in ipairs(bgSpawns) do
		local pos = ent:GetAbsOrigin()
		print(string.format("[MAP_SPAWN] BadGuys  #%d  X=%.1f  Y=%.1f  Z=%.1f", i, pos.x, pos.y, pos.z))
	end

	-- Combine all spawn points: goodguys first, then badguys
	local allSpawns = {}
	for _, ent in ipairs(ggSpawns) do table.insert(allSpawns, {pos = ent:GetAbsOrigin(), team = DOTA_TEAM_GOODGUYS}) end
	for _, ent in ipairs(bgSpawns) do table.insert(allSpawns, {pos = ent:GetAbsOrigin(), team = DOTA_TEAM_BADGUYS}) end

	-- Spawn 9 debug bots (skip slot 0 — that's the real player)
	local botIndex = 1
	for slotNum = 1, 9 do
		local heroName = DEBUG_BOT_HEROES[botIndex] or "npc_dota_hero_antimage"
		local spawnData = allSpawns[slotNum + 1] -- +1 because slot 0 (real player) is already on spawn 1

		local pos
		if spawnData then
			pos = spawnData.pos
		else
			-- No map spawn for this slot — use a fallback offset so the bot is visible
			pos = Vector(0, slotNum * 150, 256)
			print(string.format("[DEBUG] Slot %d has NO map spawn point! Using fallback pos.", slotNum))
		end

		local team = (slotNum <= 4) and DOTA_TEAM_GOODGUYS or DOTA_TEAM_BADGUYS
		local unit = CreateUnitByName(heroName, pos, true, nil, nil, team)

		if unit then
			local realPos = unit:GetAbsOrigin()
			print(string.format("[BOT] Slot %d | %-45s | Team %d | X=%.1f  Y=%.1f  Z=%.1f",
				slotNum, heroName, team, realPos.x, realPos.y, realPos.z))
		else
			print(string.format("[BOT] Slot %d | FAILED to create %s", slotNum, heroName))
		end

		botIndex = botIndex + 1
	end

	print("[DEBUG] SpawnDebugBots done. Check [MAP_SPAWN] lines for real spawn coords,")
	print("[DEBUG] and [BOT] lines for where each unit actually appeared.")
end


--[[
	This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
	gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
	is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function Banjoball:OnGameInProgress()
	-- Если это выделенный сервер, ждем получения реального Match ID от Valve
	if IsDedicatedServer() then
		local retries = 0
		Timers:CreateTimer("wait_for_match_id", {
			useGameTime = false,
			endTime = 1.0,
			callback = function()
				local match_id = "0"
				if GameRules and GameRules.Script_GetMatchID then
					match_id = tostring(GameRules:Script_GetMatchID()):gsub("ULL", "")
				end
				
				if match_id ~= "0" and match_id ~= "nil" and match_id ~= "local" then
					print("[Supabase] Match ID obtained: " .. match_id)
					Banjoball:CreateMatchRecord()
					return nil
				end
				
				retries = retries + 1
				if retries >= 10 then
					-- Тайм-аут: Match ID не появился за 10 секунд, создаем временную локальную запись
					print("[Supabase] Match ID timeout on Dedicated Server. Creating local match record.")
					Banjoball:CreateMatchRecord()

					-- Продолжаем следить за реальным Match ID и мигрируем запись когда он появится
					local migrate_retries = 0
					Timers:CreateTimer("migrate_match_id", {
						useGameTime = false,
						endTime = 5.0,
						callback = function()
							local real_id = "0"
							if GameRules and GameRules.Script_GetMatchID then
								real_id = tostring(GameRules:Script_GetMatchID()):gsub("ULL", "")
							end

							if real_id ~= "0" and real_id ~= "nil" and real_id ~= "local" then
								local old_id = Banjoball.current_match_record_id
								if old_id and string.match(old_id, "^local_") then
									print("[Supabase] Got real Match ID after timeout: " .. real_id .. ". Migrating from " .. old_id)
									Banjoball:UpdateMatchID(old_id, real_id)
								end
								return nil
							end

							migrate_retries = migrate_retries + 1
							if migrate_retries >= 60 then
								-- Ждали 5 минут — это точно локалка, прекращаем
								print("[Supabase] migrate_match_id: gave up after 5 min.")
								return nil
							end
							return 5.0
						end
					})

					return nil
				end
				
				return 1.0
			end
		})
	else
		Banjoball:CreateMatchRecord()
	end

end






function Banjoball:OnStoreRequestState(event)
	local pID = event.PlayerID
	if not pID then return end

	local ply_ent = PlayerResource:GetPlayer(pID)
	if not ply_ent then return end

	local default_open = {"fall_2021", "mug", "agh_2021", "crownfall", "newbloom_dragon"}
	local default_open_ranges = {
		"custom_range_display_green",
		"custom_range_display_purple",
		"custom_range_display_red",
		"custom_range_display_yellow",
		"custom_range_display_orange"
	}

	local shardsVal = 0
	local openFives = default_open
	local skinChoice = "fall_2021"
	local rangeChoice = "custom_range_display_green"
	local openRanges = default_open_ranges
	local ballEffectChoice = "ball_hot"
	local openBallEffects = {"ball_hot", "snowy_vortex"}

	if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
		local fullply = Banjoball.vFullinfo[pID]
		if fullply["inventory"] then
			local inv = fullply["inventory"]
			shardsVal = tonumber(inv["shards"]) or 0
			openFives = _G.ALL_HIGH_FIVES
			skinChoice = inv["chosen_high_five"] or "fall_2021"
			rangeChoice = inv["chosen_range"] or "custom_range_display_green"
			openRanges = inv["open_ranges"] or default_open_ranges
			ballEffectChoice = inv["chosen_ball_effect"] or "ball_hot"
			openBallEffects = inv["open_ball_effects"] or {"ball_hot"}
		end
	end

	_G.HF_PlayerChoices = _G.HF_PlayerChoices or {}
	if not _G.HF_PlayerChoices[pID] then
		local idx = GetHighFiveIndexByName(skinChoice)
		_G.HF_PlayerChoices[pID] = HIGH_FIVE_PAIRS[idx].name
	end

	_G.Range_PlayerChoices = _G.Range_PlayerChoices or {}
	if not _G.Range_PlayerChoices[pID] then
		_G.Range_PlayerChoices[pID] = rangeChoice
	end

	_G.Ball_PlayerChoices = _G.Ball_PlayerChoices or {}
	if not _G.Ball_PlayerChoices[pID] then
		_G.Ball_PlayerChoices[pID] = ballEffectChoice
	end

	CustomGameEventManager:Send_ServerToPlayer(ply_ent, "hf_state", {
		playerID = pID,
		chosen = _G.HF_PlayerChoices[pID] or skinChoice,
		open_high_fives = openFives,
		shards = shardsVal
	})

	CustomGameEventManager:Send_ServerToPlayer(ply_ent, "range_state", {
		playerID = pID,
		chosen = _G.Range_PlayerChoices[pID] or rangeChoice,
		open_ranges = openRanges
	})

	CustomGameEventManager:Send_ServerToPlayer(ply_ent, "ball_effects_state", {
		playerID = pID,
		chosen = _G.Ball_PlayerChoices[pID] or ballEffectChoice,
		open_ball_effects = openBallEffects
	})
end

-- Cleanup a player when they leave
function Banjoball:OnDisconnect(keys)
	local name = keys.name
	local networkid = keys.networkid
	local reason = keys.reason
	local userid = keys.userid

	-- Запускаем таймер на 2 секунды для отправки LIVE-обновления с disconnected = true в Supabase
	Timers:CreateTimer(2.0, function()
		Banjoball:SendLiveMatchUpdate()
	end)

	-- Проверяем, остались ли подключенные реальные игроки
	local has_connected_players = false
	for pID = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsFakeClient(pID) and not PlayerResource:IsBroadcaster(pID) then
			local state = PlayerResource:GetConnectionState(pID)
			if state == DOTA_CONNECTION_STATE_CONNECTED or state == DOTA_CONNECTION_STATE_LOADING then
				has_connected_players = true
				break
			end
		end
	end

	-- Если подключенных игроков нет, закрываем матч в Supabase немедленно
	if not has_connected_players then
		print("[BANJOBALL] No active players left. Closing match in Supabase immediately...")
		self.is_match_abandoned = true
		self:SetMatchStatusAbandoned(self.current_match_record_id)
		
		-- Завершаем игру через 1.5 секунды, чтобы дать HTTP-запросу гарантированно уйти в сеть
		Timers:CreateTimer(1.5, function()
			GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
		end)
	end
end

-- The overall game state has changed
function Banjoball:OnGameRulesStateChange(keys)

	if INTOOLS then
		SendToConsole("bind t dota_teleport")
		SendToConsole("bind ` dota_hero_refresh")
		SendToConsole("bind = bb_pos")
		PRE_FIRSTROUND_START = 1
		TIME_TILL_NEXT_ROUND = 3 -- сразу 3-секундный отсчёт после гола, без доп. задержки
		-- GameRules:EnableCustomGameSetupAutoLaunch(true)
    	-- GameRules:SetCustomGameSetupAutoLaunchDelay(0)
	end
	
	local newState = GameRules:State_Get()
	if newState == DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD then
		-- load the game rules, help, etc
		self.bSeenWaitForPlayers = true
	elseif newState == DOTA_GAMERULES_STATE_INIT then
		Timers:RemoveTimer("alljointimer")
	elseif newState == DOTA_GAMERULES_STATE_HERO_SELECTION then
		print("DOTA_GAMERULES_STATE_HERO_SELECTION")
		if DraftManager and DraftManager.phase ~= DRAFT_PHASE_FINISHED then
			print("[DRAFT_DEBUG] Engine transitioned to HERO_SELECTION, but DraftManager phase is not finished! Forcing FinishDraftDirectly.")
			DraftManager:FinishDraftDirectly()
		end
		if GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION then
        	HeroSelection:Start()
        end
		-- Spawn debug bots after a short delay so the map is fully initialized
		if DEBUG_SPAWN_BOTS then
			Timers:CreateTimer(1.0, function()
				Banjoball:SpawnDebugBots()
			end)
		end
		local et = 1
		if self.bSeenWaitForPlayers then
			et = .01
		end
		local startTime = GameRules:GetGameTime()
		Timers:CreateTimer("alljointimer", {
			useGameTime = true,
			endTime = et,
			callback = function()
				local allJoined = PlayerResource:HaveAllPlayersJoined()
				local elapsed = GameRules:GetGameTime() - startTime
				if allJoined or elapsed > 10.0 or (IsInToolsMode() and elapsed > 2.0) then
					print(string.format("[DRAFT] alljointimer finished. allJoined: %s, elapsed: %.2f", tostring(allJoined), elapsed))
					Banjoball:PostLoadPrecache()
					Banjoball:OnAllPlayersLoaded()
					return nil
				end
				return .1 -- Check again later in case more players spawn
			end})
	elseif newState == DOTA_GAMERULES_STATE_STRATEGY_TIME then 
		HeroSelectionOver = true
	elseif newState == DOTA_GAMERULES_STATE_TEAM_SHOWCASE then
		-- GameRules:SetSameHeroSelectionEnabled( false )
		for i=0, DOTA_MAX_TEAM_PLAYERS do
			if PlayerResource:IsValidPlayer(i) then
					-- PlayerResource:GetPlayer(i):MakeRandomHeroSelection()
				if PlayerResource:HasSelectedHero(i) == false then
					PlayerResource:GetPlayer(i):MakeRandomHeroSelection()
				end
			end
		end
		HeroSelectionOver = true
	elseif newState == DOTA_GAMERULES_STATE_PRE_GAME then
		HeroSelectionOver = true
		self:OnPreGameState()
		if SPAWN_BOTS and not self.bots_spawned then
			self.bots_spawned = true
			Timers:CreateTimer(1.0, function()
				local radiant_bots = {
					"npc_dota_hero_antimage",
					"npc_dota_hero_bloodseeker",
					"npc_dota_hero_earthshaker"
				}
				local dire_bots = {
					"npc_dota_hero_invoker",
					"npc_dota_hero_lina",
					"npc_dota_hero_juggernaut"
				}
				for _, hero in ipairs(radiant_bots) do
					Tutorial:AddBot(hero, "radiant", "", true)
				end
				for _, hero in ipairs(dire_bots) do
					Tutorial:AddBot(hero, "dire", "", true)
				end
				print("[BOTS] Spawned 6 bots in PRE_GAME. Waiting to assign teams...")
			end)

			-- Forcibly assign teams to bots after they connect (at 2.5 seconds)
			Timers:CreateTimer(2.5, function()
				local botCount = 0
				for playerID = 0, 9 do
					if PlayerResource:IsValidPlayerID(playerID) and PlayerResource:IsFakeClient(playerID) then
						botCount = botCount + 1
						if botCount <= 3 then
							-- PlayerResource:SetCustomTeamAssignment(playerID, DOTA_TEAM_GOODGUYS)
							print(string.format("[BOTS] Moved Bot %d (PlayerID %d) to GOODGUYS", botCount, playerID))
						else
							-- PlayerResource:SetCustomTeamAssignment(playerID, DOTA_TEAM_BADGUYS)
							print(string.format("[BOTS] Moved Bot %d (PlayerID %d) to BADGUYS", botCount, playerID))
						end
					end
				end
				print("[BOTS] Finished assigning teams to bots in PRE_GAME.")
			end)
		end
	elseif newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		Banjoball:OnGameInProgress()
	elseif newState == DOTA_GAME_UI_STATE_LOADING_SCREEN then
		print("Entered DOTA_GAME_UI_STATE_LOADING_SCREEN")
	elseif newState == DOTA_GAME_UI_DOTA_INGAME then
		print("Entered DOTA_GAME_UI_DOTA_INGAME")
	elseif newState == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		print("Entered DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP")
		print("[BOTS] IsCheatMode=" .. tostring(GameRules:IsCheatMode()) .. " IsInToolsMode=" .. tostring(IsInToolsMode()) .. " BOTS_IN_LOCAL_LOBBY=" .. tostring(BOTS_IN_LOCAL_LOBBY))
		if not IsDedicatedServer() or IsInToolsMode() then
			local count = 0
			for pID = 0, DOTA_MAX_PLAYERS - 1 do
				if PlayerResource:IsValidPlayerID(pID) then
					count = count + 1
				end
			end
			print("[BOTS] Human players in lobby: " .. count)
			local bots_to_add = 10 - count
			if bots_to_add > 0 and BOTS_IN_LOCAL_LOBBY then
				print("[DRAFT] Adding " .. bots_to_add .. " bots for testing")
				local bot_heroes = DEBUG_BOT_HEROES or {
					"npc_dota_hero_antimage", "npc_dota_hero_bloodseeker", "npc_dota_hero_earthshaker",
					"npc_dota_hero_invoker", "npc_dota_hero_lina", "npc_dota_hero_juggernaut",
					"npc_dota_hero_sven", "npc_dota_hero_crystal_maiden", "npc_dota_hero_pudge"
				}
				local bot_teams = {"radiant", "radiant", "radiant", "radiant", "radiant",
					"dire", "dire", "dire", "dire", "dire"}
				for i = 1, bots_to_add do
					local hero_name = bot_heroes[i] or "npc_dota_hero_antimage"
					local team_name = bot_teams[count + i] or "dire"
					print(string.format("[DRAFT] Adding bot %d: %s on %s", i, hero_name, team_name))
					local ok, err = pcall(function()
						Tutorial:AddBot(hero_name, team_name, "", false)
					end)
					if not ok then
						print("[DRAFT] Tutorial:AddBot FAILED: " .. tostring(err))
					end
				end
			else
				print("[BOTS] Skipping bots: bots_to_add=" .. bots_to_add .. " BOTS_IN_LOCAL_LOBBY=" .. tostring(BOTS_IN_LOCAL_LOBBY))
			end
			Timers:CreateTimer(2.0, function()
				DraftManager:Start()
			end)
		else
			print("[BOTS] Cheat mode is OFF and not in ToolsMode — skipping bot creation, starting draft normally")
			DraftManager:Start()
		end
	end
end

-- An NPC has spawned somewhere in game.  This includes heroes
function Banjoball:OnNPCSpawned(keys)
	local npc = EntIndexToHScript(keys.entindex)
	if not npc or npc:IsNull() then return end
	if npc:GetName() == "npc_dota_thinker" then return end

	local ply = npc:GetPlayerOwner()
	local plyId = npc:GetPlayerOwnerID()
	if (not ply or ply:IsNull()) and (plyId and plyId ~= -1) then
		ply = PlayerResource:GetPlayer(plyId)
	end

	local correct_team = npc:GetTeam()
	if npc:IsRealHero() and not _G.SpawningDebugHeroName then
		-- Если plyId не определен или равен -1, пытаемся найти его по имени героя в пиках драфта
		if not plyId or plyId == -1 then
			if HeroSelection and HeroSelection.playerPicks then
				for pID, chosenHero in pairs(HeroSelection.playerPicks) do
					if chosenHero == npc:GetUnitName() then
						plyId = pID
						npc:SetPlayerID(pID)
						break
					end
				end
			end
		end

		if plyId and plyId ~= -1 then
			correct_team = PlayerResource:GetTeam(plyId)
			if npc:GetTeam() ~= correct_team then
				npc:SetTeam(correct_team)
			end
		end

		-- Выводим отладочную информацию о спавне в чат игры
		--  local chat_msg = string.format("[SPAWN] Hero: %s | PlayerID: %s | Team: %d | Correct: %d", 
		-- 	npc:GetUnitName(), tostring(plyId), npc:GetTeam(), correct_team)
		-- GameRules:SendCustomMessage(chat_msg, 0, 0)
	end

	if npc:IsRealHero() then
		local hero_name = npc:GetUnitName()
		if _G.SpawningDebugHeroName == hero_name then
			_G.SpawningDebugHeroName = nil
			local target_team = _G.SpawningDebugHeroTeam
			_G.SpawningDebugHeroTeam = nil
			local target_pos = _G.SpawningDebugHeroPos
			_G.SpawningDebugHeroPos = nil
			
			local realTargetHero = _G.TargetDebugHeroName
			_G.TargetDebugHeroName = nil

			npc:SetTeam(target_team)
			local botPlayerID = npc:GetPlayerOwnerID()
			if botPlayerID and botPlayerID ~= -1 then
				PlayerResource:SetCustomTeamAssignment(botPlayerID, target_team)
				if realTargetHero and realTargetHero ~= hero_name then
					Timers:CreateTimer(0.03, function()
						local newHero = PlayerResource:ReplaceHeroWith(botPlayerID, realTargetHero, 0, 0)
						if newHero then
							if target_pos then
								newHero:SetAbsOrigin(target_pos)
								FindClearSpaceForUnit(newHero, target_pos, true)
							end
							newHero:SetTeam(target_team)
							self:InitializeBotHero(newHero, target_team, botPlayerID)
						end
						if npc and not npc:IsNull() then
							UTIL_Remove(npc)
						end
					end)
					return
				end
			end

			if target_pos then
				npc:SetAbsOrigin(target_pos)
				FindClearSpaceForUnit(npc, target_pos, true)
			end
			self:InitializeBotHero(npc, target_team, botPlayerID)
			print("[SPAWN] Initialized Debug Bot from console command:", hero_name)
			return
		end

		-- Обновляем хитбары всех героев с учетом спавна нового
		UpdateAllHeroesHealthBars()
	end

	-- Если для этого игрока уже инициализирован основной герой, игнорируем любые копии
	if plyId ~= nil and plyId ~= -1 then
		local fullply = self.vFullinfo[plyId]
		if fullply and fullply["Hero"] and fullply["Hero"] ~= npc then
			print("[SPAWN] Ignoring clone/illusion/tempest of player", plyId)
			return
		end
	end

	if npc:IsRealHero() and ply == nil then
		local already_init = false
		for _, h in ipairs(self.vHeroes) do
			if h == npc then already_init = true break end
		end
		if not already_init then
			local target_team = npc:GetTeam()
			local ownerID = npc:GetPlayerOwnerID()
			if ownerID and ownerID ~= -1 then
				target_team = PlayerResource:GetTeam(ownerID)
			end
			if npc:GetTeam() ~= target_team then
				npc:SetTeam(target_team)
			end
			self:InitializeBotHero(npc, target_team)
		end
	end

	--[[
	if npc:IsRealHero() and PlayerResource:IsFakeClient(plyId) then
		local bot_team_assignments = {
			["npc_dota_hero_antimage"] = DOTA_TEAM_GOODGUYS,
			["npc_dota_hero_bloodseeker"] = DOTA_TEAM_GOODGUYS,
			["npc_dota_hero_earthshaker"] = DOTA_TEAM_GOODGUYS,
			["npc_dota_hero_invoker"] = DOTA_TEAM_BADGUYS,
			["npc_dota_hero_lina"] = DOTA_TEAM_BADGUYS,
			["npc_dota_hero_juggernaut"] = DOTA_TEAM_BADGUYS,
			["npc_dota_hero_ogre_magi"] = DOTA_TEAM_BADGUYS,
		}
		local hero_name = npc:GetUnitName()
		local target_team = bot_team_assignments[hero_name]
		if target_team and npc:GetTeam() ~= target_team then
			-- PlayerResource:SetCustomTeamAssignment(plyId, target_team)
			npc:SetTeam(target_team)
			print(string.format("[BOTS] OnNPCSpawned: Forcibly assigned Bot %s (PlayerID %d) to team %d", hero_name, plyId, target_team))
			-- Refresh Player and Owner reference after team assignment change
			ply = npc:GetPlayerOwner()
		end
	end
	]]

	if ply ~= nil then
		if (ply:GetTeam() == DOTA_TEAM_GOODGUYS or ply:GetTeam() == DOTA_TEAM_BADGUYS) then
			if npc:IsRealHero() then
				local hero = npc
				local heroName = hero:GetUnitName()

				if HeroSelection and HeroSelection.playerPicks then
					-- Если игрок не выбирал героя и он зарандомился движком доты,
					-- фиксируем этого героя как его выбор, чтобы избежать двойного спавна.
					if HeroSelection.playerPicks[plyId] == nil then
						HeroSelection.playerPicks[plyId] = heroName
						print(string.format("[DRAFT] Player %d did not select a hero. Registering spawned random hero %s", plyId, heroName))
					end

					local chosenHeroName = HeroSelection.playerPicks[plyId]
					if heroName ~= chosenHeroName then
						print(string.format("[DRAFT] Temporary hero %s spawned for player %d. Replacing with %s...", heroName, plyId, chosenHeroName))

						PrecacheUnitByNameAsync(chosenHeroName, function()
							PlayerResource:ReplaceHeroWith(plyId, chosenHeroName, 0, 0)
						end, plyId)

						return
					end
				end

				if not PlayerResource:IsFakeClient(plyId) then
					local fullply = self.vFullinfo[plyId]
					if fullply then
						Timers:CreateTimer(1.0, function()
							CustomGameEventManager:Send_ServerToPlayer(ply, "apply_player_settings", {
								distance = fullply["cam_distance"] or 2000,
								locked = fullply["cam_locked"] == true,
								clicker_active = fullply["clicker_active"] == true,
								spells_hidden = fullply["spells_hidden"] == true
							})
							CustomGameEventManager:Send_ServerToPlayer(ply, "apply_ally_abilities_setting", {
								hidden = fullply["ally_abilities_hidden"] == true
							})
						end)
						

					end
				end

				for i,v in pairs( self.vHeroes ) do
					if v == hero then return end
				end
				self.HeroesSpawned = self.HeroesSpawned + 1
				if PlayerCount and self.HeroesSpawned >= PlayerCount then
					AllPlayersSelectedHeroes = true
					print("AllPlayersSelectedHeroes")

				end
				if not self.vFullinfo[plyId] then
					self.vFullinfo[plyId] = {
						Steam = PlayerResource:GetSteamAccountID(plyId),
						MMR = 1000,
						WINS = 0,
						LOSE = 0,
						Ply = ply,
						Hero = hero,
						Team = hero:GetTeam(),
						Banned = -1
					}
				else
					if not self.vFullinfo[plyId]["Hero"] then
						self.vFullinfo[plyId]["Hero"] = hero
						self.vFullinfo[plyId]["Team"] = hero:GetTeam()
					end
				end
				if not self.greetPlayers then
					-- if true or not GameRules:IsCheatMode() then
						-- Playerstrist = ""
						-- for i,v in pairs(Banjoball.vFullinfo) do
							-- if v["Steam"] ~= nil then
								-- local manys = ""
								-- if Playerstrist ~= "" then
									-- manys = ","
								-- end
								-- Playerstrist = Playerstrist..manys..tostring(v["Steam"])
							-- end
						-- end
						-- Banjoball:GetInfo({Playerstrist}, function(res) 
							-- local rest = mysplit(res.Body, " ")
							-- for i,v in pairs(rest) do 
								-- local jse = json.decode(v)
								-- local plyid = self.vSteamIds[jse.ID]
								-- local fullply = self.vFullinfo[plyid]
								-- if fullply and fullply["Ply"]:GetTeam() ~= DOTA_TEAM_CUSTOM_1 then
									-- fullply["MMR"] = jse.MMR
									-- fullply["WINS"] = jse.WINS
									-- fullply["LOSE"] = jse.LOSE
									-- fullply["Banned"] = jse.Banned
								-- end
							-- end
							-- SITEOK = true
						-- end)
					-- end
					Banjoball:InitScoreboard()
					self.greetPlayers = true
				end
				if not RoundInProgress then
					AddEndgameRoot(hero)
					AddSilence(hero)
				elseif true then
					print('Secondly second')
					if PlayerResource:IsFakeClient(plyId) then
						self:InitializeBotHero(hero, correct_team)
					else
						self:OnHeroInGameFirstTime(hero)
					end
				end
			end
		elseif ply:GetTeam() == DOTA_TEAM_CUSTOM_1 then
			if npc:IsRealHero() then
				-- To Do: Place the observer hero in the stands.
				npc:AddNoDraw()
				npc.gem = CreateItem("item_gem", npc, npc)
				npc:AddItem(npc.gem)
				print(1)
				npc:SetAbsOrigin(Vector(9999,0,9999))
				npc:ForceKill(true)
				InitAbilities(npc)
				AddStun(npc)
			end
		end
	end
end

-- function Banjoball:OnGameEnd(keys)
	-- print(keys.winning_team, "yay")
	-- for i,v in pairs(Banjoball.vHeroes) do
		-- print(i,v,v:GetPlayerOwner())
	-- end
	-- for i,v in pairs(keys) do
		-- print(i,v)
	-- end
-- end

function Banjoball:Lua(keys)
	-- SPLYID = keys.userid
	-- SPLY = PlayerResource:GetPlayer(keys.userid)
	-- SHERO = SPLY:GetAssignedHero()
	loadstring(keys.text:sub(4))()
	
	--print( '*********************************************' )
end

function mysplit (inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		table.insert(t, str)
	end
	return t
end

function Banjoball:AssignTeamSpawns(team)
	-- Gather all heroes of this team
	local teamHeroes = {}
	for _, h in ipairs(self.vHeroes) do
		if h:GetTeam() == team then
			table.insert(teamHeroes, h)
		end
	end

	if #teamHeroes == 0 then return end

	-- Find goalie by priority: terrorblade, invoker, arc_warden, pudge
	local goalie = nil
	local goaliePriorities = {
		"npc_dota_hero_terrorblade",
		"npc_dota_hero_invoker",
		"npc_dota_hero_furion"
	}

	for _, className in ipairs(goaliePriorities) do
		for _, h in ipairs(teamHeroes) do
			if h:GetClassname() == className then
				goalie = h
				break
			end
		end
		if goalie then break end
	end

	-- If not found, select goalie randomly
	if not goalie then
		local randomIndex = RandomInt(1, #teamHeroes)
		goalie = teamHeroes[randomIndex]
	end

	-- Collect field players (everyone except goalie)
	local fieldPlayers = {}
	for _, h in ipairs(teamHeroes) do
		if h ~= goalie then
			table.insert(fieldPlayers, h)
		end
	end

	local spawnTable = (team == DOTA_TEAM_GOODGUYS) and SPAWN_GOODGUYS or SPAWN_BADGUYS

	-- Assign goalie to slot 5 (index 5)
	if spawnTable[5] then
		goalie.spawn_pos = spawnTable[5]
		goalie:SetAbsOrigin(spawnTable[5])
		goalie.trackedPosition[1] = spawnTable[5]
		print(string.format("[SPAWN] Goalie %d (%s) -> slot 5: %.0f, %.0f, %.0f",
			goalie.plyID, goalie:GetClassname(), spawnTable[5].x, spawnTable[5].y, spawnTable[5].z))
	end

	-- Shuffle field spawns (slots 1 to 4)
	local fieldSpawns = {}
	for i = 1, 4 do
		if spawnTable[i] then
			table.insert(fieldSpawns, spawnTable[i])
		end
	end

	for i = #fieldSpawns, 2, -1 do
		local j = RandomInt(1, i)
		fieldSpawns[i], fieldSpawns[j] = fieldSpawns[j], fieldSpawns[i]
	end

	-- Assign field players to shuffled slots
	for i, h in ipairs(fieldPlayers) do
		local spawnPos = fieldSpawns[i]
		if spawnPos then
			h.spawn_pos = spawnPos
			h:SetAbsOrigin(spawnPos)
			h.trackedPosition[1] = spawnPos
			print(string.format("[SPAWN] Field player %d (%s) -> slot %d: %.0f, %.0f, %.0f",
				h.plyID, h:GetClassname(), i, spawnPos.x, spawnPos.y, spawnPos.z))
		end
	end
end





function Banjoball:LoadHeroes(...)
	local args = {...}
	--local player
	--player = PlayerResource:GetPlayer(tonumber(args[1]))
	--local text = table.concat(args, "")
	for i=0,9 do
		local player = PlayerResource:GetPlayer(tonumber(i))
		if player then
			local playerID = player:GetPlayerID()
			local hero = player:GetAssignedHero()
			local playernick = PlayerResource:GetPlayerName(playerID)
			if playerID ~= nil and playerID ~= -1 then
				SHEROES[playerID] = {playernick, hero, player}
				GameRules:SendCustomMessage(tostring(playernick).." "..tostring(playerID), 0, 0)
			end
		end
	end
	
	--print( '*********************************************' )
end

-- Дубликат OnPlayerChat удален, логика объединена в основном методе выше.




function Banjoball:OnHeroRespawn( hero )
	
end



-- An entity somewhere has been hurt.  This event fires very often with many units so don't do too many expensive
-- operations here
function Banjoball:OnEntityHurt(keys)
	--print("[BANJOBALL] Entity Hurt")
	--PrintTable(keys)
	--local attacker = EntIndexToHScript(keys.entindex_attacker)
	--local victim = EntIndexToHScript(keys.entindex_killed)
end

-- An item was picked up off the ground
function Banjoball:OnItemPickedUp(keys)
	--print ( '[BANJOBALL] OnItemPurchased' )
	--PrintTable(keys)

	--[[local heroEntity = EntIndexToHScript(keys.HeroEntityIndex)
	local itemEntity = EntIndexToHScript(keys.ItemEntityIndex)
	local player = PlayerResource:GetPlayer(keys.PlayerID)
	local itemname = keys.itemname]]--
end

-- A player has reconnected to the game.  This function can be used to repaint Player-based particles or change
-- state as necessary
function Banjoball:OnPlayerReconnect(keys)
	print ( '[BANJOBALL] OnPlayerReconnect' )
	PrintTable(keys)
	local plyID = keys.PlayerID
	local ply = PlayerResource:GetPlayer(plyID)
	print("P" .. plyID .. " reconnected.")

	-- Сбрасываем таймер автозакрытия матча
	if self.abandonMatchTimer then
		print("[BANJOBALL] Player reconnected. Stopping abandon timer...")
		Timers:RemoveTimer(self.abandonMatchTimer)
		self.abandonMatchTimer = nil
	end

	-- Отправляем LIVE-обновление с disconnected = false в Supabase
	Timers:CreateTimer(2.0, function()
		Banjoball:SendLiveMatchUpdate()
	end)

	local plyhero = nil
	if ply then
		plyhero = ply:GetAssignedHero()
		ply.disconnected = false
	end

	local fullply = self.vFullinfo[plyID]
	if fullply and (fullply["cam_distance"] or fullply["cam_locked"] ~= nil) then
		Timers:CreateTimer(1.5, function()
			CustomGameEventManager:Send_ServerToPlayer(ply, "apply_camera_settings", {
				distance = fullply["cam_distance"],
				locked = fullply["cam_locked"]
			})
		end)
	end

	local ball = Ball.unit

	Timers:CreateTimer(1, function()
		if ball.ballParticle then
			ParticleManager:DestroyParticle(ball.ballParticle, true)
			ball.ballParticle = ParticleManager:CreateParticle("particles/ball/ball.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
			ball.trailColor = COLOR_ARR_WHITE[COLOR_INDEX_BASE]
			ParticleManager:SetParticleControl(ball.ballParticle, 5, ball.trailColor)
		end
		
		for _,hero in ipairs(Banjoball.vHeroes) do
			local part = ParticleManager:CreateParticleForPlayer("particles/generic_gameplay/team_glow.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero, ply)
			if hero:GetTeam() == DOTA_TEAM_GOODGUYS then
				ParticleManager:SetParticleControl(part, 1, COLOR_ARR_BLUE[COLOR_INDEX_BASE])
			else
				ParticleManager:SetParticleControl(part, 1, COLOR_ARR_RED[COLOR_INDEX_BASE])
			end
			ParticleManager:CreateParticle("particles/generic_gameplay/shadow.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)
		end
		
		if plyhero.trackedParticle then
			ParticleManager:DestroyParticle(plyhero.trackedParticle, true)
			plyhero.trackedParticle = ParticleManager:CreateParticleForTeam("particles/generic_gameplay/moveto_arrow.vpcf", PATTACH_ABSORIGIN, plyhero, plyhero:GetTeam())
			ParticleManager:SetParticleControl(plyhero.trackedParticle, 1, TIME_LAPSE_ARROW_COLOR)

			local arrowPos = Vector(plyhero.trackedPosition[plyhero.trackedEndSafe].x, plyhero.trackedPosition[plyhero.trackedEndSafe].y, plyhero.trackedPosition[plyhero.trackedEndSafe].z + TRACKER_ARROW_Z_OFFSET)
			ParticleManager:SetParticleControl(plyhero.trackedParticle, 0, arrowPos)
		end
		return
	end)
end

-- An item was purchased by a player
function Banjoball:OnItemPurchased( keys )
	--print ( '[BANJOBALL] OnItemPurchased' )
	--PrintTable(keys)

	-- The playerID of the hero who is buying something
	--[[local plyID = keys.PlayerID
	if not plyID then return end

	-- The name of the item purchased
	local itemName = keys.itemname

	-- The cost of the item purchased
	local itemcost = keys.itemcost
	]]--
end

-- An ability was used by a player
function Banjoball:OnAbilityUsedProxy(keys)
	--self:OnAbilityUsed(keys)
end

-- A non-player entity (necro-book, chen creep, etc) used an ability
function Banjoball:OnNonPlayerUsedAbility(keys)
	--print('[BANJOBALL] OnNonPlayerUsedAbility')
	--PrintTable(keys)

	--local abilityname=  keys.abilityname
end

-- A player changed their name
function Banjoball:OnPlayerChangedName(keys)
	--print('[BANJOBALL] OnPlayerChangedName')
	--PrintTable(keys)

	--[[local newName = keys.newname
	local oldName = keys.oldName]]--
end

-- A player leveled up an ability
function Banjoball:OnPlayerLearnedAbility( keys)
	--print ('[BANJOBALL] OnPlayerLearnedAbility')
	--PrintTable(keys)

	--[[local player = EntIndexToHScript(keys.player)
	local abilityname = keys.abilityname]]--
end

-- A channelled ability finished by either completing or being interrupted
function Banjoball:OnAbilityChannelFinished(keys)
	--print ('[BANJOBALL] OnAbilityChannelFinished')
	--PrintTable(keys)

	--[[local abilityname = keys.abilityname
	local interrupted = keys.interrupted == 1]]--
end

-- A player leveled up
function Banjoball:OnPlayerLevelUp(keys)
	--print ('[BANJOBALL] OnPlayerLevelUp')
	--PrintTable(keys)

	--[[local player = EntIndexToHScript(keys.player)
	local level = keys.level]]--
end

-- A player last hit a creep, a tower, or a hero
function Banjoball:OnLastHit(keys)
	--print ('[BANJOBALL] OnLastHit')
	--PrintTable(keys)

	--[[local isFirstBlood = keys.FirstBlood == 1
	local isHeroKill = keys.HeroKill == 1
	local isTowerKill = keys.TowerKill == 1
	local player = PlayerResource:GetPlayer(keys.PlayerID)]]--
end

-- A tree was cut down by tango, quelling blade, etc
function Banjoball:OnTreeCut(keys)
	--print ('[BANJOBALL] OnTreeCut')
	--PrintTable(keys)

	--[[local treeX = keys.tree_x
	local treeY = keys.tree_y]]--
end

-- A rune was activated by a player
function Banjoball:OnRuneActivated (keys)
	--print ('[BANJOBALL] OnRuneActivated')
	--PrintTable(keys)
	
	--[[local player = PlayerResource:GetPlayer(keys.PlayerID)
	local rune = keys.rune]]--

	--[[ Rune Can be one of the following types
	DOTA_RUNE_DOUBLEDAMAGE
	DOTA_RUNE_HASTE
	DOTA_RUNE_HAUNTED
	DOTA_RUNE_ILLUSION
	DOTA_RUNE_INVISIBILITY
	DOTA_RUNE_MYSTERY
	DOTA_RUNE_RAPIER
	DOTA_RUNE_REGENERATION
	DOTA_RUNE_SPOOKY
	DOTA_RUNE_TURBO
	]]
end

-- A player took damage from a tower
function Banjoball:OnPlayerTakeTowerDamage(keys)
	--print ('[BANJOBALL] OnPlayerTakeTowerDamage')
	--PrintTable(keys)

	--[[local player = PlayerResource:GetPlayer(keys.PlayerID)
	local damage = keys.damage]]--
end

-- A player picked a hero
function Banjoball:OnPlayerPickHero(keys)
	--print ('[BANJOBALL] OnPlayerPickHero')
	--PrintTable(keys)

	--[[local heroClass = keys.hero
	local heroEntity = EntIndexToHScript(keys.heroindex)
	local player = EntIndexToHScript(keys.player)]]--
end

-- A player killed another player in a multi-team context
function Banjoball:OnTeamKillCredit(keys)
	--print ('[BANJOBALL] OnTeamKillCredit')
	--PrintTable(keys)

	--[[local killerPlayer = PlayerResource:GetPlayer(keys.killer_userid)
	local victimPlayer = PlayerResource:GetPlayer(keys.victim_userid)
	local numKills = keys.herokills
	local killerTeamNumber = keys.teamnumber]]--
end

-- An entity died
function Banjoball:OnEntityKilled( keys )
	--print( '[BANJOBALL] OnEntityKilled Called' )
	--PrintTable( keys )

	-- The Unit that was Killed
	--[[local killedUnit = EntIndexToHScript( keys.entindex_killed )
	-- The Killing entity
	local killerEntity = nil

	if keys.entindex_attacker ~= nil then
		killerEntity = EntIndexToHScript( keys.entindex_attacker )
	end

	if killedUnit:IsRealHero() then
		--print ("KILLEDKILLER: " .. killedUnit:GetName() .. " -- " .. killerEntity:GetName())
		
	end
	]]--
end


-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function Banjoball:InitBanjoball()
	Banjoball = self
	_G.GameOver = false
	print('[BANJOBALL] Starting to load Banjoball gamemode...')

	-- Setup rules
	GameRules:SetCustomGameSetupTimeout( 9999.0 )
	GameRules:EnableCustomGameSetupAutoLaunch(false)
	GameRules:SetCustomGameSetupAutoLaunchDelay(9999.0)
	GameRules:SetHeroRespawnEnabled( true )
	GameRules:SetUseUniversalShopMode( true )
	GameRules:SetSameHeroSelectionEnabled( true )
	GameRules:SetHeroSelectionTime( HERO_SELECT_TIME )
	GameRules:SetStrategyTime( 0.0 )
	GameRules:SetShowcaseTime( 0.0 )
	GameRules:SetPreGameTime( PRE_GAME_TIME )
	GameRules:SetPostGameTime( POST_GAME_TIME )
	GameRules:SetUseBaseGoldBountyOnHeroes(false)
	GameRules:SetHeroMinimapIconScale( 1.2 )
	GameRules:SetCreepMinimapIconScale( 2.5 )
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, 5)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 5)
	GameRules:SetStartingGold(0)
	GameRules:SetGoldPerTick(0)
	GameRules:SetTimeOfDay(0.5)
	GameRules:GetGameModeEntity():SetDaynightCycleDisabled(true)
	GameRules:GetGameModeEntity():SetSelectionGoldPenaltyEnabled(false)

	if OBSERVERS_ENABLED then
		GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_CUSTOM_1, 2)
	end
	--print('[BANJOBALL] GameRules set')

	InitLogFile( "log/banjoball.txt","")

	-- Event Hooks
	ListenToGameEvent('dota_player_gained_level', Dynamic_Wrap(Banjoball, 'OnPlayerLevelUp'), self)
	ListenToGameEvent('dota_ability_channel_finished', Dynamic_Wrap(Banjoball, 'OnAbilityChannelFinished'), self)
	ListenToGameEvent('dota_player_learned_ability', Dynamic_Wrap(Banjoball, 'OnPlayerLearnedAbility'), self)
	ListenToGameEvent('entity_killed', Dynamic_Wrap(Banjoball, 'OnEntityKilled'), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(Banjoball, 'OnConnectFull'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(Banjoball, 'OnDisconnect'), self)
	ListenToGameEvent('dota_item_purchased', Dynamic_Wrap(Banjoball, 'OnItemPurchased'), self)
	ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(Banjoball, 'OnItemPickedUp'), self)
	ListenToGameEvent('last_hit', Dynamic_Wrap(Banjoball, 'OnLastHit'), self)
	ListenToGameEvent('dota_non_player_used_ability', Dynamic_Wrap(Banjoball, 'OnNonPlayerUsedAbility'), self)
	ListenToGameEvent('player_changename', Dynamic_Wrap(Banjoball, 'OnPlayerChangedName'), self)
	--ListenToGameEvent('dota_rune_activated_server', Dynamic_Wrap(Banjoball, 'OnRuneActivated'), self)
	ListenToGameEvent('dota_player_take_tower_damage', Dynamic_Wrap(Banjoball, 'OnPlayerTakeTowerDamage'), self)
	ListenToGameEvent('tree_cut', Dynamic_Wrap(Banjoball, 'OnTreeCut'), self)
	ListenToGameEvent('entity_hurt', Dynamic_Wrap(Banjoball, 'OnEntityHurt'), self)
	ListenToGameEvent('player_connect', Dynamic_Wrap(Banjoball, 'PlayerConnect'), self)
	ListenToGameEvent('dota_player_used_ability', Dynamic_Wrap(Banjoball, 'OnAbilityUsedProxy'), self)
	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(Banjoball, 'OnGameRulesStateChange'), self)
	ListenToGameEvent('npc_spawned', Dynamic_Wrap(Banjoball, 'OnNPCSpawned'), self)
	-- ListenToGameEvent('game_end', Dynamic_Wrap(Banjoball, 'OnGameEnd'), self)
	ListenToGameEvent('dota_player_pick_hero', Dynamic_Wrap(Banjoball, 'OnPlayerPickHero'), self)
	ListenToGameEvent('dota_team_kill_credit', Dynamic_Wrap(Banjoball, 'OnTeamKillCredit'), self)
	ListenToGameEvent("player_reconnected", Dynamic_Wrap(Banjoball, 'OnPlayerReconnect'), self)
	ListenToGameEvent("player_chat", Dynamic_Wrap(Banjoball, 'OnPlayerChat'), self)
	CustomGameEventManager:RegisterListener("player_settings_changed", Dynamic_Wrap(Banjoball, "OnPlayerSettingsChanged"))
	CustomGameEventManager:RegisterListener("store_request_state", Dynamic_Wrap(Banjoball, "OnStoreRequestState"))
	
	-- Filter Execute Order
    GameRules:GetGameModeEntity():SetExecuteOrderFilter( Dynamic_Wrap( Banjoball, "FilterExecuteOrder" ), self )

	-- Commands can be registered for debugging purposes or as functions that can be called by the custom Scaleform UI
	-- Convars:RegisterCommand( "command_example", Dynamic_Wrap(Banjoball, 'ExampleConsoleCommand'), "A console command example", 0 )
	-- Convars:RegisterCommand( "changehero", Dynamic_Wrap(Banjoball, 'ConsoleChangeHero'), "ConsoleChangeHero", 0 )
	-- Convars:RegisterCommand( "lua", Dynamic_Wrap(Banjoball, 'Consolelua'), "lua", 0 )
	-- Convars:RegisterCommand( "getinfo", Dynamic_Wrap(Banjoball, 'ConsoleGetInfo'), "getinfo", 0 )
	-- Convars:RegisterCommand( "loadheroes", Dynamic_Wrap(Banjoball, 'ConsoleLoadHeroes'), "Load Heroes in variable", 0 )
	-- Convars:RegisterCommand( "whoiam", Dynamic_Wrap(Banjoball, 'ConsoleWhoIAM'), "ConsoleWhoIAM", 0 )
	Convars:RegisterCommand('player_say', function(...)
		local arg = {...}
		
		-- Если первый аргумент равен имени команды "player_say", удаляем его
		if arg[1] and string.lower(tostring(arg[1])) == "player_say" then
			table.remove(arg, 1)
		end
		
		-- Теперь первым аргументом идет sayType
		local sayTypeVal = arg[1]
		table.remove(arg, 1)

		local cmdPlayer = Convars:GetCommandClient()
		local keys = {}
		keys.ply = cmdPlayer
		keys.teamOnly = (tonumber(sayTypeVal) == 2)
		keys.text = table.concat(arg, " ")

		print("[BANJOBALL] player_say caught: sayType = " .. tostring(sayTypeVal) .. ", text = " .. tostring(keys.text))
		self:PlayerSay(keys)
	end, 'player say', 0)

	Convars:RegisterCommand('play_sound', function(...)
		local arg = {...}
		table.remove(arg,1)

		local soundStr = arg[1]

		local cmdPlayer = Convars:GetCommandClient()

		--print("play_sound " .. soundStr)
		EmitSoundOnClient(soundStr, cmdPlayer)

	end, 'play_sound', 0)

	-- Change random seed
	local timeTxt = string.gsub(string.gsub(GetSystemTime(), ':', ''), '0','')
	math.randomseed(tonumber(timeTxt))

	--DeepPrintTable(LoadKeyValues("scripts/npc/npc_abilities_custom.txt"))

	-- PLAYER COLORS in RGB
	self.m_TeamColors = {}
	self.m_TeamColors[0] = { 50, 100, 220 } -- 49:100:218
	self.m_TeamColors[1] = { 90, 225, 155 } -- 87:224:154
	self.m_TeamColors[2] = { 170, 0, 160 } -- 171:0:156
	self.m_TeamColors[3] = { 210, 200, 20 } -- 211:203:16
	self.m_TeamColors[4] = { 215, 90, 5 } -- 214:87:8
	self.m_TeamColors[5] = { 210, 100, 150 } -- 210:97:153
	self.m_TeamColors[6] = { 130, 150, 80 } -- 130:154:80
	self.m_TeamColors[7] = { 100, 190, 200 } -- 99:188:206
	self.m_TeamColors[8] = { 5, 110, 50 } -- 7:109:44
	self.m_TeamColors[9] = { 130, 80, 5 } -- 124:75:6
	
	SetTeamCustomHealthbarColor(DOTA_TEAM_GOODGUYS, 0, 0, 255)
	SetTeamCustomHealthbarColor(DOTA_TEAM_BADGUYS, 255, 0, 0)
	

	GlobalDummy = CreateUnitByName("global_dummy", Vector(0,0,0), true, nil, nil, DOTA_TEAM_GOODGUYS)
	GlobalDummy.rooted_passive = GlobalDummy:FindAbilityByName("rooted_passive")
	GlobalDummy.dummy_passive = GlobalDummy:FindAbilityByName("global_dummy_passive")

	GroundZ = GetGroundPosition(GlobalDummy:GetAbsOrigin(), GlobalDummy).z
	print("GroundZ: " .. GroundZ)

	EndRoundDummy = CreateUnitByName("endround_dummy", Vector(-4000,-4000,0), false, nil, nil, DOTA_TEAM_GOODGUYS)
	EndRoundDummy.endround_passive = EndRoundDummy:FindAbilityByName("endround_passive")

	self:InitCreeps() -- creep spectators

	RefereeSpawnPos = Entities:FindByName(nil, "referee_spawn"):GetAbsOrigin()
	RefereeSpawnPos = Vector(RefereeSpawnPos.x, RefereeSpawnPos.y, 305)
	Referee = CreateUnitByName("referee", RefereeSpawnPos, true, nil, nil, DOTA_TEAM_NEUTRALS)
	--RefereeSpawnPos = GetGroundPosition(RefereeSpawnPos, Referee)

	-- helps avoid runtime errors down the road.
	-- SetupStats(Referee)

	Timers:CreateTimer(.06, function()
		Referee:SetAbsOrigin(RefereeSpawnPos)
		AddEndgameRoot(Referee)
		AddDisarmed(Referee)

		Referee:FindAbilityByName("referee_passive"):SetLevel(1)
		--Referee:SetCustomHealthLabel( "Referee", 255, 0, 0 )

		-- constantly make the ref look at the ball, for aesthetics
		--[[Referee.referee_timer = Timers:CreateTimer(function()
			if Referee:HasModifier("modifier_disarmed_on") then
				Referee:SetForwardVector((Ball.unit:GetAbsOrigin()-Referee:GetAbsOrigin()):Normalized())
			end
			return .06
		end)]]--

		Banjoball:InitMap()
		--print("initmap")
	end)

	self.lastGoalTime = 0

	VisionDummies = {GoodGuys = {}, BadGuys = {}, Observers = {}}
	local timeOffset = .03
	-- CREATE vision dummies
	local offset = 1800 --528
	for y=8192, -5632, -1*offset do
		for x=-8192, 8192, offset do
			Timers:CreateTimer(timeOffset, function()
				--if GridNav:IsTraversable(Vector(x,y,GlobalDummy.z)) and not GridNav:IsBlocked(Vector(x,y,GlobalDummy.z)) then
				local goodguy = CreateUnitByName("vision_dummy", Vector(x,y,GlobalDummy.z), false, nil, nil, DOTA_TEAM_GOODGUYS)
				local badguy = CreateUnitByName("vision_dummy", Vector(x,y,GlobalDummy.z), false, nil, nil, DOTA_TEAM_BADGUYS)
				local observer = CreateUnitByName("vision_dummy", Vector(x,y,GlobalDummy.z), false, nil, nil, DOTA_TEAM_CUSTOM_1)

				--modifier_vision_dummy
				GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, goodguy, "modifier_vision_dummy", {})
				GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, badguy, "modifier_vision_dummy", {})
				GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, observer, "modifier_vision_dummy", {})

				goodguy.isVisionDummy = true
				badguy.isVisionDummy = true
				observer.isVisionDummy = true
				
				table.insert(VisionDummies.GoodGuys, goodguy)
				table.insert(VisionDummies.BadGuys, badguy)
				table.insert(VisionDummies.Observers, observer)
				--print("vision_dummy")
				--DebugDrawCircle(Vector(x,y,GlobalDummy.z), Vector(0,0,255), 10, 1800, true, 4000)
				--end
			end)
			timeOffset = timeOffset + .03
		end
	end

	-- Show the ending scoreboard immediately
	--GameRules:SetCustomGameEndDelay( 0 )
	--GameRules:SetCustomVictoryMessageDuration( 0 )

	self.HeroesKV = LoadKeyValues("scripts/npc/npc_heroes_custom.txt")
	self.AbilitiesKV = LoadKeyValues("scripts/npc/npc_abilities_custom.txt")
	--self.UnitsKV = LoadKeyValues("scripts/npc/npc_units_custom.txt")
	--DeepPrintTable(self.AbilitiesKV)

	-- Initialized tables for tracking state
	self.vUserIds = {}
	self.vSteamIds = {}
	self.vFullinfo = {}
	self.vBots = {}
	self.vBroadcasters = {}

	self.vPlayers = {}
	self.vHeroes = {}
	self.vRadiant = {}
	self.vDire = {}
	
	self.HeroesSpawned = 0

	self.radiantScore = 0
	self.direScore = 0

	-- Next variables can be found in goal.lua and goalspeed.lua 
	self.forSFRadiant = 1 -- in order for SF goalspeed to work, we have to declare a global variable
	self.forSFDire = 1 -- it is needed to make a custom score for SF for goalspeed to change if difference in SCORE is BIG

	self.bSeenWaitForPlayers = false
	self.colliderFilter = {}

	Ball:Init()


	-- Main thinker
	LastHeroThinkerTime = GameRules:GetGameTime()
	Timers:CreateTimer(function()
		local currTime = GameRules:GetGameTime()
		for i,hero in ipairs(self.vHeroes) do
			hero:OnThink()

			if hero.goalie then
				hero.time_as_goalie = hero.time_as_goalie + (currTime - LastHeroThinkerTime)
			end
			if Ball.unit and Ball.unit.controller == hero then
				hero.possession_time = hero.possession_time + (currTime - LastHeroThinkerTime)
			end

			Banjoball:UpdateMana(hero)
		end
		LastHeroThinkerTime = currTime
		
		return FRAME_TIME
	end)

	local herolist = LoadKeyValues("scripts/npc/herolist.txt")
	if herolist then
		local list = herolist.CustomHeroList or herolist
		CustomNetTables:SetTableValue("game_state", "herolist", list)
	end
end

mode = nil

-- This function is called as the first player loads and sets up the Banjoball parameters
function Banjoball:CaptureBanjoball()
	if mode == nil then
		mode = GameRules:GetGameModeEntity()
		mode:SetRecommendedItemsDisabled( true )
		mode:SetBuybackEnabled( false )
		mode:SetTopBarTeamValuesOverride ( true )
		mode:SetTopBarTeamValuesVisible( true )
		mode:SetGoldSoundDisabled( true )
		--mode:SetRemoveIllusionsOnDeath( true )

		self:OnFirstPlayerLoaded()
	end
end

-- This function is called 1 to 2 times as the player connects initially but before they
-- have completely connected
function Banjoball:PlayerConnect(keys)
	--print('[BANJOBALL] PlayerConnect')
	--PrintTable(keys)

	if keys.bot == 1 then
		-- This user is a Bot, so add it to the bots table
		self.vBots[keys.userid] = 1
	end
end

-- This function is called once when the player fully connects and becomes "Ready" during Loading
function Banjoball:OnConnectFull(keys)
	--print ('[BANJOBALL] OnConnectFull')
	--PrintTable(keys)
	Banjoball:CaptureBanjoball()
	-- print("AAAAAAAAAFFFFFFFFFF")
	-- for i,v in pairs(keys) do
		-- print(i,v)
	-- end
	local entIndex = keys.index+1
	-- The Player entity of the joining user
	--EntIndexToHScript(entIndex)

	-- The Player ID of the joining player
	local playerID = keys.PlayerID

	local ply = PlayerResource:GetPlayer(playerID)

	-- Update the user ID table with this user
	self.vUserIds[playerID] = ply

	-- Update the Steam ID table
	-- GameRules:SendCustomMessage("Ch 1"..tostring(playerID),0,0)
	self.vSteamIds[PlayerResource:GetSteamAccountID(playerID)] = playerID
	self:CreatePlayer(playerID)
	self:FetchSteamProfile(playerID)
	if not self.vFullinfo[playerID] then
		local preinf = {}
		preinf["Steam"] = PlayerResource:GetSteamAccountID(playerID)
		preinf["MMR"] = 1000
		preinf["WINS"] = 0
		preinf["LOSE"] = 0
		preinf["Ply"] = ply
		preinf["Hero"] = nil
		preinf["Team"] = ply:GetTeam()
		preinf["Banned"] = -1
		preinf["cam_distance"] = 2000
		preinf["cam_locked"] = false
		preinf["clicker_active"] = true
		preinf["spells_hidden"] = false
		preinf["ally_abilities_hidden"] = false
		self.vFullinfo[playerID] = preinf
	else
		self.vFullinfo[playerID]["Ply"] = ply
	end
	-- GameRules:SendCustomMessage("Ch 3",0,0)
	-- print(playerID)
	-- print(ply)
	-- print(PlayerResource:GetSteamID(playerID))
	-- If the player is a broadcaster flag it in the Broadcasters table
	if PlayerResource:IsBroadcaster(playerID) then
		self.vBroadcasters[keys.userid] = 1
		return
	end
end

-- This is an example console command
function Banjoball:ExampleConsoleCommand()
	--print( '******* Example Console Command ***************' )
	local cmdPlayer = Convars:GetCommandClient()
	if cmdPlayer then
		local playerID = cmdPlayer:GetPlayerID()
		if playerID ~= nil and playerID ~= -1 then
			-- Do something here for the player who called this command
			PlayerResource:ReplaceHeroWith(playerID, "npc_dota_hero_viper", 1000, 1000)
		end
	end
	--print( '*********************************************' )
end

function RemoveWearables(hero)
	print('#RemoveWearables')
	local wearables = {} -- объявление локального массива на удаление
	local cur = hero:FirstMoveChild() -- получаем первый указатель над подобъект объекта hero ()

	while cur ~= nil do --пока наш текущий указатель не равен nil(пустота/пустой указатель)
		cur = cur:NextMovePeer() -- выбираем следующий указатель на подобъект нашего обьекта
		if cur ~= nil and cur:GetClassname() ~= "" and cur:GetClassname() == "dota_item_wearable" then -- проверяем, елси текущий указатель не пуст, название класса не пустое, и если этот класс есть класс "dota_item_wearable", то есть надеваемые косметические предметы
			table.insert(wearables, cur) -- добавляем в таблицу на удаление текущий предмет(сверху проверяли класс текущего объекта)
		end
	end
 
	for i = 1, #wearables do -- собственно цикл для удаления всего занесенного в массив на удаление
		UTIL_Remove(wearables[i]) -- удаляем объект
	end
end




function Banjoball:ConsoleWhoIAM(...)
	local player = Convars:GetCommandClient()
	local playerID = player:GetPlayerID()
	local playernick = PlayerResource:GetPlayerName(playerID)
	local playerSteamID = PlayerResource:GetSteamAccountID(playerID)
	GameRules:SendCustomMessage(tostring(playernick).." "..tostring(playerID).." "..tostring(playerSteamID), 0, 0)
	
	
	--print( '*********************************************' )
end

function Banjoball:ConsoleChangeHero(...)
	--print( '******* Example Console Command ***************' )
	-- if IsInToolsMode() == true then
		-- player = PlayerResource:GetPlayer(0)--ply:GetAssignedHero()
		-- print('Tools')
	-- else
		-- print('NoTOols')
		-- player = Convars:GetDOTACommandClient()
	-- end
	local args = {...}
	--local player
	--player = PlayerResource:GetPlayer(tonumber(args[1]))
	local text = args[1]--table.concat(args, " ")
	for i=0,9 do
		local player = PlayerResource:GetPlayer(tonumber(i))
		local playerID = player:GetPlayerID()
		if playerID ~= nil and playerID ~= -1 and PlayerResource:GetSteamAccountID(playerID) == 882114977 then
			-- Do something here for the player who called this command
			local hero = player:GetAssignedHero()
			hero:SetAbsOrigin(Vector(hero.spawn_pos.x, hero.spawn_pos.y, GroundZ))
			-- hero:StopPhysicsSimulation()
			-- hero:AddNoDraw()
			hero:ForceKill(false)
			PlayerResource:ReplaceHeroWith(playerID, "npc_dota_hero_"..text, 0, 0)
			-- local newHero = player:GetAssignedHero()
			-- hero:SetAbsOrigin(Vector(10000,10000,1000)) -- Just in case the replace causes issues (hint, it does)
			-- if hero.goalie then
				-- hero.goalie = false
				-- hero.gc.goalie = nil
				-- hero.ballGoalieProc = false
			-- end
			-- hero.isBanjoHero = false;
			-- newHero.isBanjoHero = true;
			-- for i=1, #Banjoball.vHeroes do
				-- if Banjoball.vHeroes[i] == hero then
					-- table.remove(Banjoball.vHeroes, i)
					-- table.insert(Banjoball.vHeroes, i, newHero)
					-- return nil
				-- end
			-- end
			break
		end
	end
	
	--print( '*********************************************' )
end

function Banjoball:RegisterBallHit(hero)
	local ball = Ball.unit
	if not ball then return end
	ball.lastMovedBy = hero
	ball.lastHitTime = GameRules:GetGameTime()
	ball.lastHitHero = hero
	
	if hero and not hero:IsNull() and IsValidEntity(hero) then
		hero.assistTimer = GameRules:GetGameTime()
	end
end

