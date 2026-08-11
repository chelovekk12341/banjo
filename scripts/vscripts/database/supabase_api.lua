print('[SUPABASE_API] database/supabase_api.lua loaded')

function Banjoball:GetMSKTimeISO()
	local date_str = ""
	local time_str = ""
	
	if GetSystemDate ~= nil then
		date_str = GetSystemDate()
	end
	if GetSystemTime ~= nil then
		time_str = GetSystemTime()
	end
	
	if date_str == "" or time_str == "" then
		return ""
	end

	-- Формат GetSystemDate() обычно "MM/DD/YY" или "MM/DD/YYYY"
	local month, day, year = date_str:match("(%d+)/(%d+)/(%d+)")
	if not year then
		return ""
	end

	year = tonumber(year)
	month = tonumber(month)
	day = tonumber(day)

	if year < 100 then
		year = 2000 + year
	end

	local hour, min, sec = time_str:match("(%d+):(%d+):(%d+)")
	if not hour then
		return ""
	end

	hour = tonumber(hour)
	min = tonumber(min)
	sec = tonumber(sec)

	-- Прибавляем 3 часа для перехода из UTC в МСК только на выделенном сервере (где время в UTC)
	if IsDedicatedServer() then
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
	end

	return string.format("%04d-%02d-%02dT%02d:%02d:%02d+03:00", year, month, day, hour, min, sec)
end

function Banjoball:CreateMatchRecord()
	local match_id = "0"
	if GameRules and GameRules.Script_GetMatchID then
		match_id = tostring(GameRules:Script_GetMatchID()):gsub("ULL", "")
	end
	if match_id == "0" or match_id == "nil" or match_id == "local" then
		match_id = "local_" .. tostring(math.floor(GameRules:GetGameTime())) .. "_" .. tostring(math.random(1000, 9999))
	end
	self.current_match_record_id = match_id

	-- Выводим ID матча в консоль
	print("[BANJOBALL] ID матча: " .. match_id)

	local cap_radiant = ""
	local cap_dire = ""
	if DraftManager and DraftManager.captains then
		local r_cap = DraftManager.captains[2] -- DOTA_TEAM_GOODGUYS
		local d_cap = DraftManager.captains[3] -- DOTA_TEAM_BADGUYS
		if r_cap and r_cap ~= -1 then
			if PlayerResource:IsFakeClient(r_cap) then
				cap_radiant = "0"
			else
				cap_radiant = tostring(PlayerResource:GetSteamAccountID(r_cap))
			end
		end
		if d_cap and d_cap ~= -1 then
			if PlayerResource:IsFakeClient(d_cap) then
				cap_dire = "0"
			else
				cap_dire = tostring(PlayerResource:GetSteamAccountID(d_cap))
			end
		end
	end

	local players_data = {}
	for pID = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pID) then
			local steam_id = "0"
			local steam_id_64 = "0"
			if not PlayerResource:IsFakeClient(pID) then
				steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
				steam_id_64 = tostring(PlayerResource:GetSteamID(pID))
			end
			local hero = PlayerResource:GetSelectedHeroName(pID) or ""
			local team = PlayerResource:GetTeam(pID)
			local player_name = PlayerResource:GetPlayerName(pID) or ""
			local start_mmr = 1000
			local display_name = player_name
			local avatar_url = ""
			if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
				start_mmr = Banjoball.vFullinfo[pID]["MMR"] or 1000
				if Banjoball.vFullinfo[pID]["steam_name"] and Banjoball.vFullinfo[pID]["steam_name"] ~= "" then
					display_name = Banjoball.vFullinfo[pID]["steam_name"]
				end
				avatar_url = Banjoball.vFullinfo[pID]["steam_avatar"] or ""
			end

			table.insert(players_data, {
				steam_id = steam_id,
				steam_id_64 = steam_id_64,
				name = display_name,
				avatar_url = avatar_url,
				hero = hero,
				team = team,
				goals = 0,
				assists = 0,
				saves = 0,
				steals = 0,
				turnovers = 0,
				steals_turnovers = 0,
				pickups = 0,
				passes = 0,
				passes_received = 0,
				possession = 0,
				goalie = 0,
				total_score = 0,
				start_mmr = start_mmr,
				end_mmr = start_mmr,
				mmr_change = 0
			})
		end
	end

	local players_count = 0
	for pID = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsBroadcaster(pID) then
			local team = PlayerResource:GetTeam(pID)
			if team == DOTA_TEAM_GOODGUYS or team == DOTA_TEAM_BADGUYS then
				players_count = players_count + 1
			end
		end
	end

	local url = SUPABASE_URL .. "/rest/v1/matches"
	local req = CreateHTTPRequestScriptVM("POST", url)
	req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Content-Type", "application/json")
	req:SetHTTPRequestHeaderValue("Prefer", "resolution=merge-duplicates")
	req:SetHTTPRequestHeaderValue("x-custom-auth", SUPABASE_AUTH_KEY)

	local body = json.encode({
		match_id = match_id,
		status = "live",
		captain_radiant = cap_radiant,
		captain_dire = cap_dire,
		cheats_enabled = GameRules:IsCheatMode(),
		start_at_msc = Banjoball:GetMSKTimeISO(),
		players_count = players_count,
		players_data = players_data,
		is_local = not IsDedicatedServer(),
		is_training = IsTrainingMode()
	})

	req:SetHTTPRequestRawPostBody("application/json", body)
	req:SetHTTPRequestAbsoluteTimeoutMS(100000)
	req:Send(function(res)
		if res.StatusCode == 201 or res.StatusCode == 200 then
			print("[Supabase] Match record created successfully: " .. match_id)
		else
			print("[Supabase] CreateMatchRecord failed with status: " .. tostring(res.StatusCode) .. " body: " .. tostring(res.Body))
		end
	end)
end

function Banjoball:UpdateMatchID(old_id, new_id)
	local url = SUPABASE_URL .. "/rest/v1/matches?match_id=eq." .. old_id
	local req = CreateHTTPRequestScriptVM("PATCH", url)
	req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Content-Type", "application/json")
	req:SetHTTPRequestHeaderValue("x-custom-auth", SUPABASE_AUTH_KEY)

	local body = json.encode({ match_id = new_id })
	req:SetHTTPRequestRawPostBody("application/json", body)
	req:SetHTTPRequestAbsoluteTimeoutMS(10000)
	req:Send(function(res)
		if res.StatusCode == 200 or res.StatusCode == 204 then
			print("[Supabase] Match ID migrated: " .. old_id .. " -> " .. new_id)
			self.current_match_record_id = new_id
			Say(nil, "[BANJOBALL] ID матча обновлен: " .. new_id, false)
		else
			print("[Supabase] UpdateMatchID failed: " .. tostring(res.StatusCode) .. " body: " .. tostring(res.Body))
		end
	end)
end

function Banjoball:GetInfo(args, callback)
	local steam_ids = args[1]
	local ids_list = {}
	for id in string.gmatch(steam_ids, "[^,]+") do
		table.insert(ids_list, id)
	end
	local ids_query = table.concat(ids_list, ",")
	
	local url = SUPABASE_URL .. "/rest/v1/players?steam_id=in.(" .. ids_query .. ")"
	local req = CreateHTTPRequestScriptVM("GET", url)
	req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
	req:SetHTTPRequestAbsoluteTimeoutMS(100000)
	
	req:Send(function(res)
		if res.StatusCode == 200 and res.Body ~= nil then
			print("[Supabase] GetInfo success: " .. tostring(res.Body))
			if callback then
				callback(res)
			end
		else 
			print("[Supabase] GetInfo failed with status: " .. tostring(res.StatusCode))
			if callback then
				callback(false)
			end
		end
	end)
end

function Banjoball:SetInfo(args)
	-- Unused in Supabase implementation
end

function Banjoball:FullRequest(players_data)
	local url = SUPABASE_URL .. "/rest/v1/players"
	local req = CreateHTTPRequestScriptVM("POST", url)
	req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Content-Type", "application/json")
	req:SetHTTPRequestHeaderValue("Prefer", "resolution=merge-duplicates")
	req:SetHTTPRequestHeaderValue("x-custom-auth", SUPABASE_AUTH_KEY)
	
	local body = json.encode(players_data)
	req:SetHTTPRequestRawPostBody("application/json", body)
	req:SetHTTPRequestAbsoluteTimeoutMS(100000)
	
	req:Send(function(res)
		if res.StatusCode == 201 or res.StatusCode == 200 then
			print("[Supabase] MMR values updated successfully")
		else
			print("[Supabase] FullRequest failed with status: " .. tostring(res.StatusCode) .. " body: " .. tostring(res.Body))
		end
	end)
end

function Banjoball:CreatePlayer(playerid)
	if playerid ~= nil and playerid ~= -1 then
		local steam_id = tostring(PlayerResource:GetSteamAccountID(playerid))
		local steam_id_64 = tostring(PlayerResource:GetSteamID(playerid))
		local url = SUPABASE_URL .. "/rest/v1/players"
		
		local req = CreateHTTPRequestScriptVM("POST", url)
		req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
		req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
		req:SetHTTPRequestHeaderValue("Content-Type", "application/json")
		req:SetHTTPRequestHeaderValue("Prefer", "resolution=ignore-duplicates")
		req:SetHTTPRequestHeaderValue("x-custom-auth", SUPABASE_AUTH_KEY)
		
		local body = json.encode({
			steam_id = steam_id,
			steam_id_64 = steam_id_64,
			mmr = 1000,
			wins = 0,
			lose = 0,
			banned = false,
			clicker_active = true,
			spells_hidden = false,
			ally_abilities_hidden = false,
			camera_distance = 2000,
			camera_locked = false,
			inventory = {
				shards = 0,
				open_high_fives = {"fall_2021", "mug", "agh_2021", "crownfall", "newbloom_dragon", "poogie", "dark_carnival", "zombie", "soap", "cat_paw", "midas", "mitten"},
				chosen_high_five = "fall_2021"
			}
		})
		
		req:SetHTTPRequestRawPostBody("application/json", body)
		req:SetHTTPRequestAbsoluteTimeoutMS(100000)
		req:Send(function(res)
			if res.StatusCode == 201 or res.StatusCode == 200 then
				print("[Supabase] Player created or already exists: " .. steam_id)
			else
				print("[Supabase] CreatePlayer failed with status: " .. tostring(res.StatusCode))
			end
		end)
	end
end

function Banjoball:FetchSteamProfile(pID)
	if pID == nil or pID == -1 then return end
	if not PlayerResource:IsValidPlayerID(pID) then return end
	if PlayerResource:IsFakeClient(pID) then return end

	local steamID64 = tostring(PlayerResource:GetSteamID(pID))
	if steamID64 == "0" or steamID64 == "" then return end

	local url = "https://steamcommunity.com/profiles/" .. steamID64 .. "/?xml=1"
	local req = CreateHTTPRequestScriptVM("GET", url)
	req:SetHTTPRequestAbsoluteTimeoutMS(15000)
	
	req:Send(function(res)
		if res.StatusCode == 200 and res.Body ~= nil then
			local nickname = string.match(res.Body, "<steamID><!%[CDATA%[(.-)%]%]/></steamID>")
			if not nickname then
				nickname = string.match(res.Body, "<steamID><!%[CDATA%[(.-)%]%]></steamID>")
			end
			if not nickname then
				nickname = string.match(res.Body, "<steamID>(.-)</steamID>")
			end

			local avatar_url = string.match(res.Body, "<avatarMedium><!%[CDATA%[(.-)%]%]/></avatarMedium>")
			if not avatar_url then
				avatar_url = string.match(res.Body, "<avatarMedium><!%[CDATA%[(.-)%]%]></avatarMedium>")
			end
			if not avatar_url then
				avatar_url = string.match(res.Body, "<avatarMedium>(.-)</avatarMedium>")
			end
			
			if nickname or avatar_url then
				if not Banjoball.vFullinfo then
					Banjoball.vFullinfo = {}
				end
				if not Banjoball.vFullinfo[pID] then
					Banjoball.vFullinfo[pID] = {}
				end
				if nickname and nickname ~= "" then
					Banjoball.vFullinfo[pID]["steam_name"] = nickname
					print("[Steam API] Loaded nickname for player " .. pID .. ": " .. nickname)
				end
				if avatar_url and avatar_url ~= "" then
					avatar_url = string.gsub(avatar_url, "http://", "https://")
					Banjoball.vFullinfo[pID]["steam_avatar"] = avatar_url
					print("[Steam API] Loaded avatar for player " .. pID .. ": " .. avatar_url)
				end
			end
		else
			print("[Steam API] FetchSteamProfile failed with status: " .. tostring(res.StatusCode))
		end
	end)
end

