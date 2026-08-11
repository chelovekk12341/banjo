-- Custom Range Indicator VScripts logic

if _G.CustomRangeRegistered then return end
_G.CustomRangeRegistered = true

_G.Range_PlayerChoices = _G.Range_PlayerChoices or {}

RANGE_SKINS = {
	"custom_range_display_green",
	"custom_range_display_purple",
	"custom_range_display_red",
	"custom_range_display_yellow",
	"custom_range_display_orange"
}

function InitRangeEvents()
	if _G.Range_SelectListenerRegistered then return end
	_G.Range_SelectListenerRegistered = true

	CustomGameEventManager:RegisterListener("range_select", function(_, data)
		local playerID = tonumber(data.PlayerID or data.playerid or data.playerID)
		if not playerID then 
			print("[Range_DEBUG] Received range_select but playerID is nil")
			return 
		end
		
		local skinName = data.index
		
		-- Валидация skinName
		local valid = false
		for _, name in ipairs(RANGE_SKINS) do
			if name == skinName then
				valid = true
				break
			end
		end
		
		if not valid then
			skinName = "custom_range_display_green"
		end
		
		_G.Range_PlayerChoices[playerID] = skinName
		print("[Range_DEBUG] Player " .. tostring(playerID) .. " selected range skin: " .. tostring(skinName))

		local default_open = {
			"custom_range_display_green",
			"custom_range_display_purple",
			"custom_range_display_red",
			"custom_range_display_yellow",
			"custom_range_display_orange"
		}

		-- Обновляем инвентарь локально
		local inventory = { shards = 0, open_high_fives = _G.ALL_HIGH_FIVES, chosen_high_five = "fall_2021", chosen_range = skinName, open_ranges = default_open }
		if GameRules.Banjoball and GameRules.Banjoball.vFullinfo then
			local ply_info = GameRules.Banjoball.vFullinfo[playerID]
			if ply_info then
				if type(ply_info["inventory"]) ~= "table" then
					ply_info["inventory"] = { shards = 0, open_high_fives = _G.ALL_HIGH_FIVES, chosen_high_five = "fall_2021" }
				end
				ply_info["inventory"]["chosen_range"] = skinName
				ply_info["inventory"]["open_ranges"] = ply_info["inventory"]["open_ranges"] or default_open
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
					print("[Supabase] Updated player range inventory successfully for SteamID: " .. steam_id .. " skinName: " .. skinName)
				else
					print("[Supabase] Failed to update range inventory: status=" .. tostring(res.StatusCode) .. " body=" .. tostring(res.Body))
				end
			end)
		end

		-- Синхронизируем UI с новыми данными
		local ply_ent = PlayerResource:GetPlayer(playerID)
		if ply_ent then
			CustomGameEventManager:Send_ServerToPlayer(ply_ent, "range_state", {
				playerID = playerID,
				chosen = skinName,
				open_ranges = inventory.open_ranges or default_open
			})
		end
	end)
end

-- Авто-инициализация при перезагрузке файла в процессе игры
if CustomGameEventManager then
	InitRangeEvents()
end
