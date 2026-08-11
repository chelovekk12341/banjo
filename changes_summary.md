# Описание изменений для ручного обновления

Здесь собраны все изменения кода, сделанные для исправления зависания игроков на старте, отображения аватарок в нелокальном лобби, добавления времени МСК в БД и отправки промежуточных обновлений при голах.

---

## 1. Файл: game/dota_addons/banjoball_5x5/scripts/vscripts/banjoball.lua

### Изменение 1: Подсчет игроков в `OnAllPlayersLoaded`
* **Где искать:** Функция `Banjoball:OnAllPlayersLoaded()` (примерно 98-112 строки).
* **Было:**
```lua
	for i=0,9 do
		if PlayerResource:IsValidPlayerID(i) then
			local ply = PlayerResource:GetPlayer(i)
			if ply and ply:GetTeam() ~= DOTA_TEAM_CUSTOM_1 then
				PlayerCount = PlayerCount + 1
				self.vPlayers[i] = ply
			end
		end
	end
```
* **Стало:**
```lua
	for i=0,9 do
		if PlayerResource:IsValidPlayerID(i) then
			if not PlayerResource:IsBroadcaster(i) then
				local team = PlayerResource:GetTeam(i)
				if team ~= DOTA_TEAM_CUSTOM_1 then
					PlayerCount = PlayerCount + 1
					local ply = PlayerResource:GetPlayer(i)
					if ply then
						self.vPlayers[i] = ply
					end
				end
			end
		end
	end
```

---

### Изменение 2: Добавление функции расчета времени МСК (UTC+3)
* **Где искать:** Перед функцией `Banjoball:CreateMatchRecord()` (примерно 337 строка).
* **Было:**
```lua
function Banjoball:CreateMatchRecord()
```
* **Стало:**
```lua
function Banjoball:GetMSKTimeISO()
	local t = GetSystemTimeTable()
	if not t then return "" end

	local year = t.year
	local month = t.month
	local day = t.day
	local hour = t.hour
	local min = t.min
	local sec = t.sec

	-- Прибавляем 3 часа для перехода из UTC в МСК
	hour = hour + 3

	local days_in_month = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

	local function is_leap_year(y)
		return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
	end

	if is_leap_year(year) then
		days_in_month[2] = 29
	end

	if hour >= 24 then
		hour = hour - 24
		day = day + 1

		local max_days = days_in_month[month] or 31
		if day > max_days then
			day = 1
			month = month + 1

			if month > 12 then
				month = 1
				year = year + 1
			end
		end
	end

	return string.format("%04d-%02d-%02dT%02d:%02d:%02d+03:00", year, month, day, hour, min, sec)
end

function Banjoball:CreateMatchRecord()
```

---

### Изменение 3: Добавление `created_at_msk` при создании матча
* **Где искать:** Внутри функции `Banjoball:CreateMatchRecord()` (примерно 450-465 строки).
* **Было:**
```lua
	local body = json.encode({
		match_id = match_id,
		status = "live",
		captain_radiant = cap_radiant,
		captain_dire = cap_dire,
		cheats_enabled = GameRules:IsCheatMode(),
		players_data = players_data
	})
```
* **Стало:**
```lua
	local body = json.encode({
		match_id = match_id,
		status = "live",
		captain_radiant = cap_radiant,
		captain_dire = cap_dire,
		cheats_enabled = GameRules:IsCheatMode(),
		created_at_msk = Banjoball:GetMSKTimeISO(),
		players_data = players_data
	})
```

---

### Изменение 4: Безусловный вызов инициализации в `OnNPCSpawned`
* **Где искать:** Функция `Banjoball:OnNPCSpawned(keys)` (примерно 920-930 строки).
* **Было:**
```lua
				if not RoundInProgress then
					AddEndgameRoot(hero)
					AddSilence(hero)
				elseif true then--GameRules:IsCheatMode() then
					-- print(hero.IsTempest)
					print('Secondly second')
					self:OnHeroInGameFirstTime(hero)
				end
```
* **Стало:**
```lua
				if not RoundInProgress then
					AddEndgameRoot(hero)
					AddSilence(hero)
				end
				print('Secondly second')
				self:OnHeroInGameFirstTime(hero)
```

---

### Изменение 5: Предохранитель от повторной инициализации в `OnHeroInGameFirstTime`
* **Где искать:** Функция `Banjoball:OnHeroInGameFirstTime(hero)` (примерно 1160-1170 строки).
* **Было:**
```lua
function Banjoball:OnHeroInGameFirstTime( hero )
	print("OnHeroInGameFirstTime",hero)
	CustomGameEventManager:Send_ServerToAllClients( "update_hero_bar", {} )
```
* **Стало:**
```lua
function Banjoball:OnHeroInGameFirstTime( hero )
	if hero.isFirstTimeInitialized then return end
	hero.isFirstTimeInitialized = true

	print("OnHeroInGameFirstTime",hero)
	CustomGameEventManager:Send_ServerToAllClients( "update_hero_bar", {} )
```

---

## 2. Файл: game/dota_addons/banjoball_5x5/scripts/vscripts/mechanics/goal.lua

### Изменение 1: Вызов отправки лайв-обновления при каждом голе
* **Где искать:** Внутри функции `Banjoball:OnGoal(team)` перед циклом по героям (примерно 260-270 строки).
* **Было:**
```lua
		if self.radiantScore >= SCORE_TO_WIN then
			Banjoball:OnWonGame(DOTA_TEAM_GOODGUYS)
			GameOver = true
		end
	end

	for _,hero in ipairs(Banjoball.vHeroes) do
```
* **Стало:**
```lua
		if self.radiantScore >= SCORE_TO_WIN then
			Banjoball:OnWonGame(DOTA_TEAM_GOODGUYS)
			GameOver = true
		end
	end

	-- Если игра еще не завершена, отправляем промежуточное обновление в БД
	if not GameOver then
		self:SendLiveMatchUpdate()
	end

	for _,hero in ipairs(Banjoball.vHeroes) do
```

---

### Изменение 2: Добавление функции `SendLiveMatchUpdate()`
* **Где искать:** Перед функцией `Banjoball:UpdateMatchRecord(...)` (примерно 580 строка).
* **Было:**
```lua
function Banjoball:UpdateMatchRecord(nWinningTeam, real_players_count)
```
* **Стало:**
```lua
function Banjoball:SendLiveMatchUpdate()
	local match_id = self.current_match_record_id
	if not match_id then return end

	local real_players_count = 0
	for pID = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsFakeClient(pID) then
			real_players_count = real_players_count + 1
		end
	end

	local players_data = {}
	for _, hero in ipairs(Banjoball.vHeroes) do
		if hero and not hero:IsNull() and IsValidEntity(hero) then
			local pID = hero:GetPlayerID()
			if pID and PlayerResource:IsValidPlayerID(pID) then
				local steam_id = "0"
				local is_bot = PlayerResource:IsFakeClient(pID)
				if not is_bot then
					steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
				end
				
				local goals = hero.goalsAgainst or 0
				local assists = hero.numAssists or 0
				local saves = hero.numSaves or 0
				local steals = hero.steals or 0
				local turnovers = hero.turnovers or 0
				local steals_turnovers = steals - turnovers
				local pickups = hero.pickups or 0
				local passes = hero.passes or 0
				local passes_received = hero.passesReceived or 0
				local possession = hero.possession or 0
				local goalie = hero.goalie or 0
				local nonSaves = hero.non_saves or 0
				
				local total_score = (10 * goals) + (5 * assists) + (steals - turnovers) + pickups + (2 * passes) + (3 * saves) - nonSaves

				local start_mmr = 1000
				if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
					start_mmr = Banjoball.vFullinfo[pID]["MMR"] or 1000
				end

				table.insert(players_data, {
					steam_id = steam_id,
					hero = hero:GetUnitName(),
					team = hero:GetTeam(),
					goals = goals,
					assists = assists,
					saves = saves,
					steals = steals,
					turnovers = turnovers,
					steals_turnovers = steals_turnovers,
					pickups = pickups,
					passes = passes,
					passes_received = passes_received,
					possession = possession,
					goalie = goalie,
					total_score = total_score,
					start_mmr = start_mmr,
					end_mmr = start_mmr,
					mmr_change = 0
				})
			end
		end
	end

	local url = SUPABASE_URL .. "/rest/v1/matches?match_id=eq." .. match_id
	local req = CreateHTTPRequestScriptVM("PATCH", url)
	req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Content-Type", "application/json")

	local update_payload = {
		status = "live",
		radiant_score = self.radiantScore,
		dire_score = self.direScore,
		duration = math.floor(GameRules:GetGameTime()),
		players_data = players_data
	}

	local body = json.encode(update_payload)

	req:SetHTTPRequestRawPostBody("application/json", body)
	req:SetHTTPRequestAbsoluteTimeoutMS(100000)
	req:Send(function(res)
		if res.StatusCode == 204 or res.StatusCode == 200 then
			print("[Supabase] Match record updated live: " .. match_id)
		else
			print("[Supabase] SendLiveMatchUpdate failed with status: " .. tostring(res.StatusCode))
		end
	end)
end

function Banjoball:UpdateMatchRecord(nWinningTeam, real_players_count)
```

---

### Изменение 3: Добавление `finished_at_msk` при завершении матча
* **Где искать:** Внутри функции `Banjoball:UpdateMatchRecord(...)` (примерно 800 строка).
* **Было:**
```lua
	local update_payload = {
		status = "finished",
		winner = nWinningTeam,
		radiant_score = self.radiantScore,
		dire_score = self.direScore,
		duration = math.floor(GameRules:GetGameTime()),
		mvp_match = mvp_match_sid,
		players_data = players_data
	}
```
* **Стало:**
```lua
	local update_payload = {
		status = "finished",
		winner = nWinningTeam,
		radiant_score = self.radiantScore,
		dire_score = self.direScore,
		duration = math.floor(GameRules:GetGameTime()),
		mvp_match = mvp_match_sid,
		finished_at_msk = Banjoball:GetMSKTimeISO(),
		players_data = players_data
	}
```

---

## 3. Файл: content/dota_addons/banjoball_5x5/panorama/scripts/custom_game/draft.js

### Изменение 1: Вычисление SteamID в `RenderPlayerCard`
* **Где искать:** Функция `RenderPlayerCard(...)` (примерно 303-317 строки).
* **Было:**
```javascript
  // Аватарка
  var steamId = player.steamid || "0";
  var accountId = player.accountid ? player.accountid.toString() : "0";

  if (steamId === "0" && playerInfo && playerInfo.player_steamid && playerInfo.player_steamid !== "0") {
    steamId = playerInfo.player_steamid;
    try {
      accountId = (BigInt(steamId) - 76561197960265728n).toString();
    } catch (e) {
      accountId = (parseInt(steamId) - 76561197960265728).toString();
    }
  }
```
* **Стало:**
```javascript
  // Аватарка
  var accountId = player.accountid ? player.accountid.toString() : "0";
  var steamId = "0";

  if (accountId && accountId !== "0") {
    try {
      steamId = (BigInt(accountId) + 76561197960265728n).toString();
    } catch (e) {
      steamId = player.steamid || "0";
    }
  } else if (playerInfo && playerInfo.player_steamid && playerInfo.player_steamid !== "0") {
    steamId = playerInfo.player_steamid;
    try {
      accountId = (BigInt(steamId) - 76561197960265728n).toString();
    } catch (e) {
      accountId = (parseInt(steamId) - 76561197960265728).toString();
    }
  } else {
    steamId = player.steamid || "0";
  }
```

---

### Изменение 2: Защита от userdata в `RenderPlayerCard`
* **Где искать:** Функция `RenderPlayerCard(...)` (примерно 330-350 строки).
* **Было:**
```javascript
    } else if (steamId && steamId !== "0" && steamId !== "76561197960265728") {
      avatar.steamid = steamId;
      avatar.accountid = accountId;
      $.Msg("[DRAFT] Set remote player avatar: " + playerIDInt + " (SteamID: " + steamId + ", AccountID: " + accountId + ")");
```
* **Стало:**
```javascript
    } else if (steamId && steamId !== "0" && steamId !== "76561197960265728" && steamId.indexOf("userdata") === -1) {
      avatar.steamid = steamId;
      avatar.accountid = accountId;
      $.Msg("[DRAFT] Set remote player avatar: " + playerIDInt + " (SteamID: " + steamId + ", AccountID: " + accountId + ")");
```

---

### Изменение 3: Вычисление SteamID и аватарки в `CreateAvatarForVote`
* **Где искать:** Функция `CreateAvatarForVote(...)` (примерно 530-550 строки).
* **Было:**
```javascript
function CreateAvatarForVote(parent, steamId, accountId) {
  var isBot = !steamId || steamId === "0" || steamId === "76561197960265728";

  if (isBot) {
    var botPanel = $.CreatePanel("Panel", parent, "");
    botPanel.AddClass("VoteAvatar");
    botPanel.AddClass("BotAvatar");
    botPanel.hittest = false;
  } else {
    var avatar = $.CreatePanel("DOTAAvatarImage", parent, "");
    avatar.AddClass("VoteAvatar");
    avatar.hittest = false;
    avatar.steamid = steamId;
    if (accountId) {
      avatar.accountid = accountId;
    }
  }
}
```
* **Стало:**
```javascript
function CreateAvatarForVote(parent, steamId, accountId) {
  var calculatedSteamId = steamId;
  if (accountId && accountId !== 0 && accountId !== "0") {
    try {
      calculatedSteamId = (BigInt(accountId) + 76561197960265728n).toString();
    } catch (e) {
      // fallback
    }
  }

  var isBot = !calculatedSteamId || calculatedSteamId === "0" || calculatedSteamId === "76561197960265728";

  if (isBot) {
    var botPanel = $.CreatePanel("Panel", parent, "");
    botPanel.AddClass("VoteAvatar");
    botPanel.AddClass("BotAvatar");
    botPanel.hittest = false;
  } else {
    var avatar = $.CreatePanel("DOTAAvatarImage", parent, "");
    avatar.AddClass("VoteAvatar");
    avatar.hittest = false;
    avatar.steamid = calculatedSteamId;
    if (accountId) {
      avatar.accountid = accountId.toString();
    }
  }
}
```
