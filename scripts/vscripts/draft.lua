if DraftManager == nil then
    DraftManager = class({})
end

DRAFT_PHASE_CAPTAINS_VOTE = 1
DRAFT_PHASE_PICKING = 2
DRAFT_PHASE_FINISHED = 3

DRAFT_VOTE_TIME = 10 -- 10 секунд на голосование
DRAFT_PICK_TIME = 10 -- 10 секунд на ход капитана

-- Таблицы очерёдности пиков для разного числа игроков
-- 1 = Синий капитан (Goodguys), 2 = Красный капитан (Badguys)
local PICK_ORDERS = {
    [8] = {1,2,2,1,1,2,2,1}, -- 10 игроков
    [7] = {1,2,2,1,1,2,1},   -- 9 игроков
    [6] = {1,1,2,2,2,1},     -- 8 игроков
}

local function GetPickOrder(total_picks)
    if PICK_ORDERS[total_picks] then
        return PICK_ORDERS[total_picks]
    end
    -- 7 и ниже — по очереди: 1,2,1,2,...
    local order = {}
    for i = 1, total_picks do
        order[i] = (i % 2 == 1) and 1 or 2
    end
    return order
end

function DraftManager:Init()
    print("[DRAFT] Initializing DraftManager")
    self.phase = DRAFT_PHASE_CAPTAINS_VOTE
    self.timer = DRAFT_VOTE_TIME
    self.isPaused = false
    self.elapsed_time = 50
    self.choices = {} -- player_id -> role (1: хочу, 0: не хочу)
    self.rolls = {} -- player_id -> roll_value
    self.teams = {
        [DOTA_TEAM_GOODGUYS] = {}, -- Синяя команда (Левая)
        [DOTA_TEAM_BADGUYS] = {}   -- Красная команда (Правая)
    }
    self.captains = {
        [DOTA_TEAM_GOODGUYS] = nil,
        [DOTA_TEAM_BADGUYS] = nil
    }
    self.active_captain_team = DOTA_TEAM_GOODGUYS -- Синие выбирают первыми
    self.free_players = {} -- нераспределенные игроки (player_id)
    self.players = {} -- список всех участников драфта (player_id)
    self.pause_time_left = {}
    self.paused_by = nil
    self.custom_player_names = {}
    self.preferences = {}
    self.training_votes = {}
    self.pref_roles = {}
    _G._forced_training_mode = false

    -- Регистрируем слушатели Panorama событий
    CustomGameEventManager:RegisterListener("draft_captain_choice", Dynamic_Wrap(DraftManager, "OnCaptainChoice"))
    CustomGameEventManager:RegisterListener("draft_register_player", Dynamic_Wrap(DraftManager, "OnRegisterPlayer"))
    CustomGameEventManager:RegisterListener("draft_pick_player", Dynamic_Wrap(DraftManager, "OnPickPlayer"))
    CustomGameEventManager:RegisterListener("draft_toggle_pause", Dynamic_Wrap(DraftManager, "OnTogglePause"))
    CustomGameEventManager:RegisterListener("draft_skip", Dynamic_Wrap(DraftManager, "OnSkipDraft"))
    CustomGameEventManager:RegisterListener("draft_prefer_team", Dynamic_Wrap(DraftManager, "OnPreferTeam"))
    CustomGameEventManager:RegisterListener("draft_vote_training", Dynamic_Wrap(DraftManager, "OnVoteTraining"))
    CustomGameEventManager:RegisterListener("draft_select_role", Dynamic_Wrap(DraftManager, "OnSelectRole"))
end

function DraftManager:Start()
    -- Если лобби локальное и включено отключение драфта, сразу завершаем его
    local isLocal = (not IsDedicatedServer() or IsInToolsMode())
    if isLocal and not DRAFT_IN_LOCAL_LOBBY then
        print("[DRAFT] Draft disabled in local lobby. Skipping draft phase.")
        self:Init()
        self.players = {}
        local real_players = 0
        for pID = 0, DOTA_MAX_PLAYERS - 1 do
            if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsBroadcaster(pID) then
                local is_valid = true
                if IsDedicatedServer() then
                    if PlayerResource:GetSteamAccountID(pID) == 0 then
                        is_valid = false
                    end
                end
                if is_valid then
                    table.insert(self.players, pID)
                    self.choices[pID] = -1
                    real_players = real_players + 1
                end
            end
        end
        if real_players < 2 then
            print("[DRAFT] Only 1 player. Auto-enabling training mode in local lobby.")
            _G._forced_training_mode = true
        end
        self:FinishDraftDirectly()
        return
    end

    self:Init()

    isLocal = (not IsDedicatedServer() or IsInToolsMode())
    local voteTime = DRAFT_VOTE_TIME
    if isLocal then
        voteTime = 100
        self.timer = voteTime
    end


    -- Получаем активных игроков
    self.players = {}
    for pID = 0, DOTA_MAX_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsBroadcaster(pID) then
            local is_valid = true
            if IsDedicatedServer() then
                if PlayerResource:GetSteamAccountID(pID) == 0 then
                    is_valid = false
                end
            end
            if is_valid then
                table.insert(self.players, pID)
                self.choices[pID] = -1 -- еще не выбрал
                
                -- Подгружаем предпочтительную роль игрока из БД (inventory)
                local prefRoleVal = ""
                if Banjoball and Banjoball.vFullinfo and Banjoball.vFullinfo[pID] and Banjoball.vFullinfo[pID]["inventory"] then
                    prefRoleVal = Banjoball.vFullinfo[pID]["inventory"]["pref_role"] or ""
                end
                self.pref_roles[pID] = prefRoleVal
            end
        end
    end

    -- Автоматический выбор режима тренировки, если реальных игроков <= 2
    local total_real = 0
    for _, pID in ipairs(self.players) do
        if not PlayerResource:IsFakeClient(pID) then
            total_real = total_real + 1
        end
    end

    if total_real <= 2 then
        print(string.format("[DRAFT] Real players count is %d (<= 2). Auto-voting training mode for everyone.", total_real))
        for _, pID in ipairs(self.players) do
            if not PlayerResource:IsFakeClient(pID) then
                self.training_votes = self.training_votes or {}
                self.training_votes[pID] = true
            end
        end
        _G._forced_training_mode = true
    end

    print("[DRAFT_DEBUG] DraftManager:Start() active players count: " .. #self.players)
    for _, pID in ipairs(self.players) do
        print(string.format("  [DRAFT_DEBUG] PlayerID: %d | SteamID: %s | Team: %d | ConnectionState: %d", 
            pID, 
            tostring(PlayerResource:GetSteamAccountID(pID)),
            PlayerResource:GetTeam(pID),
            PlayerResource:GetConnectionState(pID)))
    end

    -- Если игроков слишком мало (например, тестируем в одиночку), пропускаем драфт
    if #self.players < 2 then
        print("[DRAFT] Not enough players to host a draft. Skipping. Auto-enabling training mode.")
        _G._forced_training_mode = true
        self:FinishDraftDirectly()
        return
    end

    -- Записываем начальные свободные игроки
    for _, pID in ipairs(self.players) do
        table.insert(self.free_players, pID)
    end

    -- Обновляем NetTable
    self:UpdateNetTable()

    -- Загружаем MMR из Supabase
    local steamIdsTable = {}
    for _, pID in ipairs(self.players) do
        local steamID = PlayerResource:GetSteamAccountID(pID)
        if steamID and steamID ~= 0 then
            table.insert(steamIdsTable, tostring(steamID))
        end
    end

    if #steamIdsTable > 0 and not NOMMR then
        local steamIdsStr = table.concat(steamIdsTable, ",")
        print("[DRAFT] Requesting MMR for draft players: " .. steamIdsStr)
        Banjoball:GetInfo({steamIdsStr}, function(res)
            if res then
                local decoded = json.decode(res.Body)
                if decoded then
                    for _, jse in pairs(decoded) do
                        local steamIDNum = tonumber(jse.steam_id)
                        local plyid = Banjoball.vSteamIds[steamIDNum]
                        if plyid then
                            if not Banjoball.vFullinfo[plyid] then
                                Banjoball.vFullinfo[plyid] = {
                                    Steam = steamIDNum,
                                    MMR = 1000,
                                    WINS = 0,
                                    LOSE = 0,
                                    Banned = -1
                                }
                            end
                            Banjoball.vFullinfo[plyid]["MMR"] = tonumber(jse.mmr) or 1000
                            Banjoball.vFullinfo[plyid]["WINS"] = tonumber(jse.wins) or 0
                            Banjoball.vFullinfo[plyid]["LOSE"] = tonumber(jse.lose) or 0
                            Banjoball.vFullinfo[plyid]["Banned"] = jse.banned or false
                            Banjoball.vFullinfo[plyid]["cam_distance"] = tonumber(jse.camera_distance) or 2000
                            if jse.camera_locked ~= nil then
                                Banjoball.vFullinfo[plyid]["cam_locked"] = (jse.camera_locked == true or jse.camera_locked == 1)
                            else
                                Banjoball.vFullinfo[plyid]["cam_locked"] = false
                            end
                        end
                    end
                    print("[DRAFT] MMR loaded successfully for draft players")
                    self:UpdateNetTable()
                else
                    print("[DRAFT] Failed to decode JSON for MMR")
                end
            else
                print("[DRAFT] GetInfo failed for draft players")
            end
        end)
    end

    -- В локальном лобби боты голосуют по очереди с задержкой в 1 секунду
    if isLocal then
        local botIndex = 1
        for _, pID in ipairs(self.players) do
            if PlayerResource:IsFakeClient(pID) then
                local delay = botIndex * 1.0
                botIndex = botIndex + 1
                Timers:CreateTimer("bot_vote_" .. pID, {
                    useGameTime = false,
                    endTime = delay,
                    callback = function()
                        if self.isPaused then
                            return 1.0 -- откладываем на 1 секунду, пока драфт на паузе
                        end
                        if self.phase == DRAFT_PHASE_CAPTAINS_VOTE then
                            -- 40% - хочу стать капитаном, 30% - зарандомить команды, 30% - не хочу
                            local rand = math.random(100)
                            local role = 0
                            if rand <= 40 then
                                role = 1
                            elseif rand <= 70 then
                                role = 2
                            else
                                role = 0
                            end
                            self:OnCaptainChoice({ player_id = pID, role = role })
                        end
                    end
                })
            end
        end
    end

    -- Запускаем таймер фазы голосования
    self:StartTimer(voteTime, function()
        self:EndCaptainVoting()
    end)
end

function DraftManager:StartTimer(duration, callback)
    self.timer = duration
    self:UpdateNetTable()

	Timers:RemoveTimer("draft_timer")
	Timers:CreateTimer("draft_timer", {
		useGameTime = false,
		endTime = 1,
		callback = function()
			if self.phase == DRAFT_PHASE_FINISHED then
				return nil
			end
			if self.isPaused then
                if self.paused_by then
                    -- Если локальное лобби или режим инструментов, то пауза бесконечная
                    if not IsDedicatedServer() or IsInToolsMode() then
                        return 1
                    end

                    local timeLeft = self.pause_time_left[self.paused_by] or 0
                    timeLeft = timeLeft - 1
                    self.pause_time_left[self.paused_by] = timeLeft
 
                    if timeLeft <= 0 then
                        self.isPaused = false
                        self.paused_by = nil
                        GameRules:SendCustomMessage("[DRAFT] Пауза автоматически снята: у капитана закончился лимит времени.", 0, 0)
                        self:UpdateNetTable()
                    else
                        self:UpdateNetTable()
                    end
                end
                return 1
            end
            self.elapsed_time = self.elapsed_time - 1
            self.timer = self.timer - 1
            self:UpdateNetTable()

            if self.elapsed_time <= 0 then
                print("[DRAFT_DEBUG] Global draft timer expired! Forcing draft completion.")
                if self.phase == DRAFT_PHASE_CAPTAINS_VOTE then
                    self:EndCaptainVoting()
                    if self.phase == DRAFT_PHASE_PICKING then
                        self:AutoPickAllRemaining()
                    end
                else
                    self:AutoPickAllRemaining()
                end
                return nil
            end

            if self.timer <= 0 then
                callback()
                return nil
            end
            return 1
        end
    })
end

function DraftManager:OnRegisterPlayer(event)
    local pID = tonumber(event.player_id)
    local name = event.player_name
    if pID and name and name ~= "" then
        print(string.format("[DRAFT] Registering player name for %d: %s", pID, name))
        DraftManager.custom_player_names = DraftManager.custom_player_names or {}
        DraftManager.custom_player_names[pID] = name
        DraftManager:UpdateNetTable()
    end
end

function DraftManager:GetPlayerName(pID)
    pID = tonumber(pID)
    if not pID then return "" end

    if self.custom_player_names and self.custom_player_names[pID] and self.custom_player_names[pID] ~= "" then
        return self.custom_player_names[pID]
    end

    local name = PlayerResource:GetPlayerName(pID)
    if name and name ~= "" then
        return name
    end

    return "Игрок " .. (pID + 1)
end

function DraftManager:OnCaptainChoice(event)
    local pID = tonumber(event.player_id)
    local role = event.role -- 1: хочу, 0: не хочу, 2: зарандомить

    if DraftManager.phase ~= DRAFT_PHASE_CAPTAINS_VOTE then return end
    if not pID then return end

    -- Блокируем выбор роли "хочу стать капитаном" для игроков с MMR < DRAFT_CAPTAIN_MIN_MMR (кроме 201230874)
    if role == 1 then
        local mmrVal = 1000
        if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
            mmrVal = Banjoball.vFullinfo[pID]["MMR"] or 1000
        end
        local accountId = PlayerResource:GetSteamAccountID(pID)
        local minMmr = DRAFT_CAPTAIN_MIN_MMR or 950
        if mmrVal < minMmr and accountId ~= 201230874 then
            print(string.format("[DRAFT] Player %d has low MMR (%d) and cannot be captain. Ignoring choice.", pID, mmrVal))
            return
        end
    end

    -- Защита от повторных нажатий
    if DraftManager.choices[pID] == role then return end

    print(string.format("[DRAFT] Player %d voted for role: %d", pID, role))
    DraftManager.choices[pID] = role

    if event.player_name and event.player_name ~= "" then
        DraftManager.custom_player_names = DraftManager.custom_player_names or {}
        DraftManager.custom_player_names[pID] = event.player_name
    end

    if role == 1 then
        if PlayerResource:GetSteamAccountID(pID) == 201230874 then
            DraftManager.rolls[pID] = 100
        else
            DraftManager.rolls[pID] = math.random(1, 100)
        end
        local playerName = DraftManager:GetPlayerName(pID)
        GameRules:SendCustomMessage(string.format("[ROLL] %s выбросил: %d", playerName, DraftManager.rolls[pID]), 0, 0)
    else
        DraftManager.rolls[pID] = nil -- очищаем ролл, если игрок переголосовал
    end

    DraftManager:UpdateNetTable()

    -- Считаем голоса за рандомизацию для мгновенного шафла
    local total_real_players_random = 0
    local random_team_votes_random = 0
    for _, id in ipairs(DraftManager.players) do
        if not PlayerResource:IsFakeClient(id) then
            total_real_players_random = total_real_players_random + 1
            if DraftManager.choices[id] == 2 then
                random_team_votes_random = random_team_votes_random + 1
            end
        end
    end
    local random_votes_needed_instant = math.ceil(total_real_players_random * (DRAFT_RANDOM_VOTE_PERCENT / 100))
    if total_real_players_random > 0 and random_team_votes_random >= random_votes_needed_instant then
        print("[DRAFT] Required random votes reached. Shuffling teams immediately!")
        Timers:RemoveTimer("draft_timer")
        Timers:CreateTimer(0.1, function()
            GameRules:SendCustomMessage("[DRAFT] Требуемое количество голосов за рандомизацию набрано. Команды будут случайно перемешаны!", 0, 0)
            DraftManager:FinishDraftDirectly()
        end)
        return
    end

    -- Проверяем, проголосовали ли все требуемые игроки
    local isLocal = (not IsDedicatedServer() or IsInToolsMode())
    local all_voted = true
    for _, id in ipairs(DraftManager.players) do
        if isLocal or not PlayerResource:IsFakeClient(id) then
            if DraftManager.choices[id] == -1 then
                all_voted = false
                break
            end
        end
    end

    if all_voted then
        print("[DRAFT] All required players voted. Ending captain voting phase early (asynchronously).")
        Timers:RemoveTimer("draft_timer")
        Timers:CreateTimer(0.1, function()
            DraftManager:EndCaptainVoting()
        end)
    end
end

function DraftManager:OnVoteTraining(event)
    local pID = tonumber(event.player_id)
    local vote = event.vote == 1 or event.vote == true
    if not pID then return end
    if DraftManager.phase == DRAFT_PHASE_FINISHED then return end

    DraftManager.training_votes = DraftManager.training_votes or {}
    DraftManager.training_votes[pID] = vote

    -- Считаем голоса за тренировочный режим
    local total_real = 0
    local votes = 0
    for _, id in ipairs(DraftManager.players) do
        if not PlayerResource:IsFakeClient(id) then
            total_real = total_real + 1
            if DraftManager.training_votes[id] then
                votes = votes + 1
            end
        end
    end

    local needed = math.ceil(total_real * (DRAFT_TRAINING_VOTE_PERCENT / 100))
    if total_real > 0 and votes >= needed then
        if not _G._forced_training_mode then
            _G._forced_training_mode = true
            -- GameRules:SendCustomMessage("[DRAFT] " .. DRAFT_TRAINING_VOTE_PERCENT .. "%+ реальных игроков проголосовали за режим тренировки!", 0, 0)
        end
    else
        if _G._forced_training_mode then
            _G._forced_training_mode = false
            GameRules:SendCustomMessage("[DRAFT] Отменен режим тренировки (недостаточно голосов).", 0, 0)
        end
    end

    DraftManager:UpdateNetTable()
end

function DraftManager:OnSelectRole(event)
    local pID = tonumber(event.player_id)
    local role = event.role or ""
    if not pID then return end
    if DraftManager.phase == DRAFT_PHASE_FINISHED then return end

    DraftManager.pref_roles = DraftManager.pref_roles or {}
    DraftManager.pref_roles[pID] = role

    -- Сохраняем выбранную роль в базу данных Supabase в jsonb поле inventory
    local steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
    if steam_id and steam_id ~= "0" then
        local url = SUPABASE_URL .. "/rest/v1/players"
        local req = CreateHTTPRequestScriptVM("POST", url)
        if req then
            local inventory = { shards = 0 }
            if Banjoball and Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
                local ply_info = Banjoball.vFullinfo[pID]
                if ply_info then
                    if type(ply_info["inventory"]) ~= "table" then
                        ply_info["inventory"] = { shards = 0 }
                    end
                    ply_info["inventory"]["pref_role"] = role
                    inventory = ply_info["inventory"]
                end
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
            req:SetHTTPRequestAbsoluteTimeoutMS(10000)
            
            req:Send(function(res)
                if res.StatusCode == 200 or res.StatusCode == 204 then
                    print("[Supabase] Updated player pref_role successfully for SteamID: " .. steam_id .. " role: " .. role)
                else
                    print("[Supabase] Failed to update pref_role in inventory: status=" .. tostring(res.StatusCode) .. " body=" .. tostring(res.Body))
                end
            end)
        end
    end

    DraftManager:UpdateNetTable()
end

function DraftManager:EndCaptainVoting()
    print("[DRAFT] End of Captain Voting phase")

    -- Считаем голоса за рандомизацию
    local total_real_players = 0
    local random_team_votes = 0
    for _, pID in ipairs(self.players) do
        if not PlayerResource:IsFakeClient(pID) then
            total_real_players = total_real_players + 1
            if self.choices[pID] == 2 then
                random_team_votes = random_team_votes + 1
            end
        end
    end

    if total_real_players > 0 and (random_team_votes / total_real_players) >= 0.6 then
        GameRules:SendCustomMessage("[DRAFT] 60%+ реальных игроков проголосовали за рандомизацию команд. Команды будут случайно перемешаны!", 0, 0)
        self:FinishDraftDirectly()
        return
    end

    self.phase = DRAFT_PHASE_PICKING
    self.pick_step = 1

    -- Собираем список волонтеров
    local volunteers = {}
    for _, pID in ipairs(self.players) do
        if self.choices[pID] == 1 then
            table.insert(volunteers, pID)
        end
    end

    -- Сортируем волонтеров по роллам
    local sortByRoll = function(a, b)
        return (self.rolls[a] or 0) > (self.rolls[b] or 0)
    end
    table.sort(volunteers, sortByRoll)

    local cap1, cap2
    local cap1_source, cap2_source

    if #volunteers >= 2 then
        cap1 = volunteers[1]
        cap2 = volunteers[2]
        cap1_source = "волонтер"
        cap2_source = "волонтер"
    else
        -- Если волонтеров < 2, то нам нужно добрать капитанов
        if #volunteers == 1 then
            cap1 = volunteers[1]
            cap1_source = "волонтер"
        end

        -- Собираем списки приоритетов для добора из оставшихся игроков
        local minMmr = DRAFT_CAPTAIN_MIN_MMR or 950

        -- Группы с MMR >= 900
        local high_novote = {}
        local high_random = {}
        local high_refused = {}

        -- Группы с MMR < 900
        local low_novote = {}
        local low_random = {}
        local low_refused = {}

        for _, pID in ipairs(self.players) do
            if pID ~= cap1 then
                local choice = self.choices[pID]
                local mmrVal = 1000
                if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
                    mmrVal = Banjoball.vFullinfo[pID]["MMR"] or 1000
                end

                local hasHighMmr = (mmrVal >= minMmr)

                if choice == -1 or choice == nil then
                    if hasHighMmr then
                        table.insert(high_novote, pID)
                    else
                        table.insert(low_novote, pID)
                    end
                elseif choice == 2 then
                    if hasHighMmr then
                        table.insert(high_random, pID)
                    else
                        table.insert(low_random, pID)
                    end
                else -- choice == 0 (Не хочу быть капитаном)
                    if hasHighMmr then
                        table.insert(high_refused, pID)
                    else
                        table.insert(low_refused, pID)
                    end
                end
            end
        end

        -- Функция для случайного выбора игрока из списка и удаления его оттуда
        local function pullRandomPlayer(list)
            if #list == 0 then return nil end
            local idx = math.random(1, #list)
            local pID = list[idx]
            table.remove(list, idx)
            return pID
        end

        -- Логика добора
        local function getNextCaptain()
            -- Сначала игроки с MMR >= 900 (в порядке: не голосовал -> нажал рандом -> не хотел)
            local pID = pullRandomPlayer(high_novote)
            if pID then return pID, "не голосовал (MMR >= " .. minMmr .. ")" end

            pID = pullRandomPlayer(high_random)
            if pID then return pID, "нажал рандом (MMR >= " .. minMmr .. ")" end

            pID = pullRandomPlayer(high_refused)
            if pID then return pID, "не хотел (MMR >= " .. minMmr .. ")" end

            -- Затем игроки с MMR < 900 (в последнюю очередь, в том же порядке)
            pID = pullRandomPlayer(low_novote)
            if pID then return pID, "не голосовал (MMR < " .. minMmr .. ")" end

            pID = pullRandomPlayer(low_random)
            if pID then return pID, "нажал рандом (MMR < " .. minMmr .. ")" end

            pID = pullRandomPlayer(low_refused)
            if pID then return pID, "не хотел (MMR < " .. minMmr .. ")" end

            return nil
        end

        if not cap1 then
            cap1, cap1_source = getNextCaptain()
        end
        if not cap2 then
            cap2, cap2_source = getNextCaptain()
        end

        -- Резервный выбор (если по итогу итераций кто-то не выбрался, чтобы избежать багов)
        if not cap1 or not cap2 then
            print("[DRAFT_WARNING] Captain election failed to find enough players through priorities! Falling back to random selection.")
            local fallback_candidates = {}
            for _, pID in ipairs(self.players) do
                if pID ~= cap1 and pID ~= cap2 then
                    table.insert(fallback_candidates, pID)
                end
            end

            if not cap1 then
                cap1 = pullRandomPlayer(fallback_candidates) or 0
                cap1_source = "резервный случайный выбор"
            end
            if not cap2 then
                cap2 = pullRandomPlayer(fallback_candidates) or cap1
                cap2_source = "резервный случайный выбор"
            end

            local msg = string.format("[DRAFT DEBUGLOG] Резервный выбор капитанов: Синий = %s, Красный = %s", tostring(cap1), tostring(cap2))
            print(msg)
            GameRules:SendCustomMessage(msg, 0, 0)
        end
    end

    -- Убедимся, что для капитанов проставлены роллы и учет особых аккаунтов
    if cap1 and PlayerResource:IsValidPlayerID(cap1) and PlayerResource:GetSteamAccountID(cap1) == 201230874 then
        self.rolls[cap1] = 100
    else
        self.rolls[cap1] = self.rolls[cap1] or math.random(1, 100)
    end

    if cap2 and PlayerResource:IsValidPlayerID(cap2) and PlayerResource:GetSteamAccountID(cap2) == 201230874 then
        self.rolls[cap2] = 100
    else
        self.rolls[cap2] = self.rolls[cap2] or math.random(1, 100)
    end

    self.captains[DOTA_TEAM_GOODGUYS] = cap1
    self.captains[DOTA_TEAM_BADGUYS] = cap2

    print(string.format("[DRAFT] Captain Goodguys (Blue): PlayerID %d (Source: %s, Roll: %d)", cap1, tostring(cap1_source), self.rolls[cap1] or 0))
    print(string.format("[DRAFT] Captain Badguys (Red): PlayerID %d (Source: %s, Roll: %d)", cap2, tostring(cap2_source), self.rolls[cap2] or 0))

    -- Пишем в чат результаты выбора
    local cap1Name = self:GetPlayerName(cap1)
    local cap2Name = self:GetPlayerName(cap2)

    if cap1_source == "волонтер" then
        GameRules:SendCustomMessage(string.format("Капитан СИНЕЙ команды %s (%d)", cap1Name, self.rolls[cap1] or 0), 0, 0)
    else
        GameRules:SendCustomMessage(string.format("%s автоматически выбран первым капитаном (%s)", cap1Name, cap1_source or "добор"), 0, 0)
    end

    if cap2_source == "волонтер" then
        GameRules:SendCustomMessage(string.format("Капитан КРАСНОЙ команды %s (%d)", cap2Name, self.rolls[cap2] or 0), 0, 0)
    else
        GameRules:SendCustomMessage(string.format("%s автоматически выбран вторым капитаном (%s)", cap2Name, cap2_source or "добор"), 0, 0)
    end

    -- Капитаны автоматически перемещаются в свои команды и удаляются из свободных игроков
    self:MovePlayerToTeam(cap1, DOTA_TEAM_GOODGUYS)
    self:MovePlayerToTeam(cap2, DOTA_TEAM_BADGUYS)

    self.active_captain_team = DOTA_TEAM_GOODGUYS -- Начинает синий капитан

    self.pause_time_left[cap1] = 30
    self.pause_time_left[cap2] = 30

    -- Начинаем драфт игроков
    self:NextPickTurn()
end

function DraftManager:MovePlayerToTeam(pID, team)
    -- Удаляем из свободных игроков
    for i, id in ipairs(self.free_players) do
        if tonumber(id) == tonumber(pID) then
            table.remove(self.free_players, i)
            break
        end
    end

    -- Добавляем в команду
    table.insert(self.teams[team], pID)
end

function DraftManager:NextPickTurn()
    -- Если не осталось свободных игроков, драфт завершен
    if #self.free_players == 0 then
        self:FinishDraft()
        return
    end

    local active_captain = self.captains[self.active_captain_team]

    -- Если остался ровно один свободный игрок, автопикаем его через 2 секунды
    if #self.free_players == 1 then
        self:StartTimer(2, function()
            self:AutoPick()
        end)
    -- Если активный капитан - бот, то делаем автопик через 1 секунду
    elseif PlayerResource:IsFakeClient(active_captain) then
        self:StartTimer(1, function()
            self:AutoPick()
        end)
    else
        self:StartTimer(DRAFT_PICK_TIME, function()
            self:AutoPick()
        end)
    end
end

function DraftManager:OnPickPlayer(event)
    local pID = event.player_id
    local targetID = event.target_player_id

    if DraftManager.phase ~= DRAFT_PHASE_PICKING then return end

    local active_captain = DraftManager.captains[DraftManager.active_captain_team]
    if pID ~= active_captain then
        print("[DRAFT] Player trying to pick is not the active captain!")
        return
    end

    -- Проверяем, свободен ли игрок
    local is_free = false
    for _, id in ipairs(DraftManager.free_players) do
        if tonumber(id) == tonumber(targetID) then
            is_free = true
            break
        end
    end

    if not is_free then
        print("[DRAFT] Target player is not free!")
        return
    end

    print(string.format("[DRAFT] Captain %d picked player %d for team %d", active_captain, targetID, DraftManager.active_captain_team))
    DraftManager:MovePlayerToTeam(targetID, DraftManager.active_captain_team)

    -- Передаем ход
    DraftManager.pick_step = DraftManager.pick_step + 1
    local total_picks = math.max(0, #DraftManager.players - 2)
    local pick_order = GetPickOrder(total_picks)
    if pick_order[DraftManager.pick_step] == 1 then
        DraftManager.active_captain_team = DOTA_TEAM_GOODGUYS
    else
        DraftManager.active_captain_team = DOTA_TEAM_BADGUYS
    end
    DraftManager:NextPickTurn()
end

function DraftManager:AutoPick()
    if #self.free_players == 0 then return end

    -- Выбираем случайного свободного игрока
    local randomIndex = math.random(1, #self.free_players)
    local targetID = self.free_players[randomIndex]
    local active_captain = self.captains[self.active_captain_team]

    print(string.format("[DRAFT] Time expired! Auto-picking player %d for team %d", targetID, self.active_captain_team))
    self:MovePlayerToTeam(targetID, self.active_captain_team)

    -- Передаем ход
    self.pick_step = self.pick_step + 1
    local total_picks = math.max(0, #self.players - 2)
    local pick_order = GetPickOrder(total_picks)
    if pick_order[self.pick_step] == 1 then
        self.active_captain_team = DOTA_TEAM_GOODGUYS
    else
        self.active_captain_team = DOTA_TEAM_BADGUYS
    end
    self:NextPickTurn()
end

function DraftManager:AutoPickAllRemaining()
    print("[DRAFT_DEBUG] AutoPickAllRemaining started. Remaining players: " .. #self.free_players)
    
    Timers:RemoveTimer("draft_timer")

    while #self.free_players > 0 do
        local randomIndex = math.random(1, #self.free_players)
        local targetID = self.free_players[randomIndex]
        local active_captain = self.captains[self.active_captain_team]

        if active_captain then
            print(string.format("[DRAFT] Global time expired! Auto-picking player %d for team %d", targetID, self.active_captain_team))
            self:MovePlayerToTeam(targetID, self.active_captain_team)

            -- Передаем ход
            self.pick_step = self.pick_step + 1
            local total_picks = math.max(0, #self.players - 2)
            local pick_order = GetPickOrder(total_picks)
            local next_team = pick_order[self.pick_step]
            if next_team == 1 then
                self.active_captain_team = DOTA_TEAM_GOODGUYS
            elseif next_team == 2 then
                self.active_captain_team = DOTA_TEAM_BADGUYS
            end
        else
            local team = DOTA_TEAM_GOODGUYS
            if #self.teams[DOTA_TEAM_GOODGUYS] > #self.teams[DOTA_TEAM_BADGUYS] then
                team = DOTA_TEAM_BADGUYS
            end
            self:MovePlayerToTeam(targetID, team)
        end
    end

    self:FinishDraft()
end

function DraftManager:FinishDraft()
    print("[DRAFT_DEBUG] FinishDraft started.")
    self.phase = DRAFT_PHASE_FINISHED
    Timers:RemoveTimer("draft_timer")
    self.preferences = {}

    -- Проверим, не остались ли свободные игроки по какой-то причине
    if #self.free_players > 0 then
        print(string.format("[DRAFT_DEBUG] Warning: %d free players left during FinishDraft. Assigning them automatically.", #self.free_players))
        for _, pID in ipairs(self.free_players) do
            -- Определяем, в какой команде меньше игроков
            local team = DOTA_TEAM_GOODGUYS
            if #self.teams[DOTA_TEAM_GOODGUYS] > #self.teams[DOTA_TEAM_BADGUYS] then
                team = DOTA_TEAM_BADGUYS
            end
            table.insert(self.teams[team], pID)
            print(string.format("[DRAFT_DEBUG] Auto-assigned remaining free player %d to team %d", pID, team))
        end
        self.free_players = {}
    end

    -- Проверим, все ли валидные игроки вообще распределены по командам
    for pID = 0, DOTA_MAX_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsBroadcaster(pID) then
            local isAssigned = false
            for _, id in ipairs(self.teams[DOTA_TEAM_GOODGUYS]) do
                if tonumber(id) == pID then isAssigned = true break end
            end
            for _, id in ipairs(self.teams[DOTA_TEAM_BADGUYS]) do
                if tonumber(id) == pID then isAssigned = true break end
            end
            if not isAssigned then
                local team = DOTA_TEAM_GOODGUYS
                if #self.teams[DOTA_TEAM_GOODGUYS] > #self.teams[DOTA_TEAM_BADGUYS] then
                    team = DOTA_TEAM_BADGUYS
                end
                table.insert(self.teams[team], pID)
                print(string.format("[DRAFT_DEBUG] Found unassigned active PlayerID %d! Auto-assigning to team %d", pID, team))
            end
        end
    end

    -- Сначала временно сбрасываем всех игроков в DOTA_TEAM_NOTEAM, чтобы освободить места на командах
    for pID = 0, DOTA_MAX_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(pID) then
            PlayerResource:SetCustomTeamAssignment(pID, DOTA_TEAM_NOTEAM)
        end
    end

    Timers:CreateTimer(0.1, function()
        -- Распределяем игроков по командам в движке Dota 2 и логируем
        print("[DRAFT_DEBUG] Assigning teams in engine:")
        for _, pID in ipairs(self.teams[DOTA_TEAM_GOODGUYS]) do
            PlayerResource:SetCustomTeamAssignment(pID, DOTA_TEAM_GOODGUYS)
            print(string.format("  PlayerID %d -> GOODGUYS (Radiant). Engine Team now: %d", pID, PlayerResource:GetTeam(pID)))
        end
        for _, pID in ipairs(self.teams[DOTA_TEAM_BADGUYS]) do
            PlayerResource:SetCustomTeamAssignment(pID, DOTA_TEAM_BADGUYS)
            print(string.format("  PlayerID %d -> BADGUYS (Dire). Engine Team now: %d", pID, PlayerResource:GetTeam(pID)))
        end

        -- Логируем состав команд в NetTable
        self:UpdateNetTable()

        -- Запускаем старт игры мгновенно без 5-секундной задержки
        print("[DRAFT_DEBUG] Calling GameRules:FinishCustomGameSetup() immediately")
        GameRules:FinishCustomGameSetup()
    end)
end

function DraftManager:OnSkipDraft(event)
    local pID = event.player_id
    if not pID then return end

    -- Проверяем, действительно ли лобби локальное
    local isLocal = (not IsDedicatedServer() or IsInToolsMode())
    if not isLocal then
        print("[DRAFT] Non-local lobby tried to skip draft!")
        return
    end

    print(string.format("[DRAFT] Player %d requested to skip draft.", pID))
    DraftManager:FinishDraftDirectly()
end

function DraftManager:OnPreferTeam(event)
    local pID = tonumber(event.player_id)
    local team = tonumber(event.team)
    if not pID then return end
    if DraftManager.phase ~= DRAFT_PHASE_PICKING then return end

    -- Капитаны не могут выбирать предпочтение
    if pID == DraftManager.captains[DOTA_TEAM_GOODGUYS] or pID == DraftManager.captains[DOTA_TEAM_BADGUYS] then
        return
    end

    -- Если игрок уже пикнут в команду, то преференс менять нельзя
    if DraftManager:GetPlayerDraftTeam(pID) ~= 0 then
        return
    end

    if team ~= DOTA_TEAM_GOODGUYS and team ~= DOTA_TEAM_BADGUYS then
        return
    end

    DraftManager.preferences = DraftManager.preferences or {}
    if DraftManager.preferences[pID] == team then
        DraftManager.preferences[pID] = nil
    else
        DraftManager.preferences[pID] = team
    end

    DraftManager:UpdateNetTable()
end

function DraftManager:FinishDraftDirectly()
    print("[DRAFT_DEBUG] FinishDraftDirectly started.")
    self.phase = DRAFT_PHASE_FINISHED
    Timers:RemoveTimer("draft_timer")
    self.preferences = {}
    self.pref_roles = {}

    -- Очищаем команды перед распределением
    self.teams[DOTA_TEAM_GOODGUYS] = {}
    self.teams[DOTA_TEAM_BADGUYS] = {}

    -- Копируем список игроков для перемешивания
    local shuffled = {}
    for _, pID in ipairs(self.players) do
        table.insert(shuffled, pID)
    end

    -- Дополнительно проверим, все ли валидные игроки есть в self.players
    for pID = 0, DOTA_MAX_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsBroadcaster(pID) then
            local exists = false
            for _, id in ipairs(shuffled) do
                if tonumber(id) == pID then exists = true break end
            end
            if not exists then
                table.insert(shuffled, pID)
                print(string.format("[DRAFT_DEBUG] Found active PlayerID %d not in shuffled list! Added to shuffled list.", pID))
            end
        end
    end

    -- Fisher-Yates shuffle для случайного распределения
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- Сначала временно сбрасываем всех игроков в DOTA_TEAM_NOTEAM, чтобы освободить места на командах
    for pID = 0, DOTA_MAX_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(pID) then
            PlayerResource:SetCustomTeamAssignment(pID, DOTA_TEAM_NOTEAM)
        end
    end

    Timers:CreateTimer(0.1, function()
        -- Распределяем игроков по командам: поочередно в GOODGUYS и BADGUYS
        local team = DOTA_TEAM_GOODGUYS
        for _, pID in ipairs(shuffled) do
            PlayerResource:SetCustomTeamAssignment(pID, team)
            table.insert(self.teams[team], pID)
            print(string.format("[DRAFT_DEBUG] Shuffled assignment: PlayerID %d -> team %d. Engine Team now: %d", pID, team, PlayerResource:GetTeam(pID)))

            -- Принудительно обновляем команду героя в игре по всем доступным источникам
            local hero = nil
            if Banjoball and Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
                hero = Banjoball.vFullinfo[pID]["Hero"]
            end
            if not hero then
                hero = PlayerResource:GetSelectedHeroEntity(pID)
            end
            if not hero and HeroSelection and HeroSelection.playerPicks then
                local chosenHeroName = HeroSelection.playerPicks[pID]
                if chosenHeroName then
                    local allHeroes = Entities:FindAllByClassname("npc_dota_hero_*")
                    for _, h in ipairs(allHeroes) do
                        if h:GetUnitName() == chosenHeroName then
                            hero = h
                            break
                        end
                    end
                end
            end

            if hero and not hero:IsNull() then
                if hero:GetTeam() ~= team then
                    hero:SetTeam(team)
                    print(string.format("[DRAFT_DEBUG] Forcibly updated Hero %s (PlayerID %d) team to %d on draft finish", hero:GetUnitName(), pID, team))
                end
                if hero:GetPlayerOwnerID() == -1 or not hero:GetPlayerOwnerID() then
                    hero:SetPlayerID(pID)
                end
                if Banjoball and Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
                    Banjoball.vFullinfo[pID]["Hero"] = hero
                    Banjoball.vFullinfo[pID]["Team"] = team
                end
            end

            team = (team == DOTA_TEAM_GOODGUYS) and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS
        end

        self:UpdateNetTable()
        print("[DRAFT_DEBUG] FinishDraftDirectly: Calling GameRules:FinishCustomGameSetup()")
        GameRules:FinishCustomGameSetup()
    end)
end

function DraftManager:OnTogglePause(event)
    local pID = event.player_id
    if not pID then return end

    local isLocal = (not IsDedicatedServer() or IsInToolsMode())
    if not isLocal then
        print("[DRAFT] Pause is not allowed on dedicated servers (non-local lobbies)!")
        return
    end

    if DraftManager.isPaused then
        DraftManager.isPaused = false
        DraftManager.paused_by = nil
        print("[DRAFT] Pause disabled by player: " .. pID)
    else
        DraftManager.isPaused = true
        DraftManager.paused_by = pID
        print(string.format("[DRAFT] Pause enabled by player %d", pID))
    end

    DraftManager:UpdateNetTable()
end


function DraftManager:UpdateNetTable()
    -- Считаем голоса за рандомизацию и тренировочный режим для NetTable
    local total_real_players = 0
    local random_team_votes = 0
    local training_votes_count = 0
    for _, pID in ipairs(self.players) do
        if not PlayerResource:IsFakeClient(pID) then
            total_real_players = total_real_players + 1
            if self.choices[pID] == 2 then
                random_team_votes = random_team_votes + 1
            end
            if self.training_votes and self.training_votes[pID] then
                training_votes_count = training_votes_count + 1
            end
        end
    end
    local random_votes_needed = math.ceil(total_real_players * (DRAFT_RANDOM_VOTE_PERCENT / 100))
    local training_votes_needed = math.ceil(total_real_players * (DRAFT_TRAINING_VOTE_PERCENT / 100))

    local playersData = {}
    for _, pID in ipairs(self.players) do
        local mmrVal = 1000
        if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
            mmrVal = Banjoball.vFullinfo[pID]["MMR"] or 1000
        end

        playersData[tostring(pID)] = {
            playerName = self:GetPlayerName(pID),
            choice = self.choices[pID] or -1,
            roll = self.rolls[pID] or 0,
            team = self:GetPlayerDraftTeam(pID),
            mmr = mmrVal,
            steamid = tostring(PlayerResource:GetSteamID(pID)),
            accountid = PlayerResource:GetSteamAccountID(pID),
            pref_team = self.preferences and self.preferences[pID] or 0,
            voted_training = (self.training_votes and self.training_votes[pID]) or false,
            pref_role = self.pref_roles and self.pref_roles[pID] or ""
        }
    end

    local isInfinite = (not IsDedicatedServer() or IsInToolsMode())
    local total_picks = math.max(0, #self.players - 2)
    local pick_order = GetPickOrder(total_picks)

    local data = {
        phase = self.phase,
        timer = self.timer,
        elapsed_time = self.elapsed_time or 0,
        is_paused = self.isPaused or false,
        is_infinite_pause = isInfinite,
        is_local_lobby = isInfinite,
        active_captain_team = self.active_captain_team,
        pick_step = self.pick_step or 1,
        total_picks = total_picks,
        pick_order = pick_order,
        random_votes = random_team_votes,
        random_votes_needed = random_votes_needed,
        training_votes_count = training_votes_count,
        training_votes_needed = training_votes_needed,
        random_votes_percent = DRAFT_RANDOM_VOTE_PERCENT,
        training_votes_percent = DRAFT_TRAINING_VOTE_PERCENT,
        captains = {
            goodguys = self.captains[DOTA_TEAM_GOODGUYS] or -1,
            badguys = self.captains[DOTA_TEAM_BADGUYS] or -1
        },
        pause_time_left = {
            goodguys = self.pause_time_left[self.captains[DOTA_TEAM_GOODGUYS] or -1] or 30,
            badguys = self.pause_time_left[self.captains[DOTA_TEAM_BADGUYS] or -1] or 30
        },
        teams = {
            goodguys = self.teams[DOTA_TEAM_GOODGUYS] or {},
            badguys = self.teams[DOTA_TEAM_BADGUYS] or {}
        },
        players = playersData
    }


    CustomNetTables:SetTableValue("draft", "status", data)
end


function DraftManager:GetPlayerDraftTeam(pID)
    local pIDNum = tonumber(pID)
    if not pIDNum then return 0 end

    for _, id in ipairs(self.teams[DOTA_TEAM_GOODGUYS]) do
        if tonumber(id) == pIDNum then return DOTA_TEAM_GOODGUYS end
    end
    for _, id in ipairs(self.teams[DOTA_TEAM_BADGUYS]) do
        if tonumber(id) == pIDNum then return DOTA_TEAM_BADGUYS end
    end
    return 0 -- Free/not selected
end
