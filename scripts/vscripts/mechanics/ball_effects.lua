BALL_EFFECTS = {
	{
		name = "none",
		particle = ""
	},
	{
		name = "ball_hot",
		particle = "particles/general_events/ball_hot/ball_hot.vpcf"
	},
	{
		name = "snowy_vortex",
		particle = "particles/general_events/ball_hot/phase_boots_winterrewardline_2025_snowy_vortex.vpcf"
	}
	-- TODO: новые эффекты временно отключены
}

_G.Ball_PlayerChoices = _G.Ball_PlayerChoices or {}

function GetBallEffectIndexByName(name)
	if not name then return 2 end
	for i, effect in ipairs(BALL_EFFECTS) do
		if effect.name == name then
			return i
		end
	end
	return 2
end

function GetBallEffectParticleByName(name)
	local idx = GetBallEffectIndexByName(name)
	return BALL_EFFECTS[idx].particle
end

-- Инициализация слушателя события выбора эффекта мяча
function InitBallEffectsEvents()
	if _G.BallEffectsListenerRegistered then return end
	_G.BallEffectsListenerRegistered = true

	CustomGameEventManager:RegisterListener("ball_effect_select", function(_, data)
		local playerID = tonumber(data.PlayerID or data.playerid or data.playerID)
		if not playerID then 
			print("[BALL_EFFECTS] Received ball_effect_select but playerID is nil")
			return 
		end
		
		local effectName = data.index
		local index = GetBallEffectIndexByName(effectName)
		effectName = BALL_EFFECTS[index].name
		
		_G.Ball_PlayerChoices[playerID] = effectName
		print("[BALL_EFFECTS] Player " .. tostring(playerID) .. " selected ball effect: " .. tostring(effectName))

		local default_open = {"ball_hot", "snowy_vortex"}

		-- Обновляем инвентарь локально
		local inventory = { shards = 0, open_ball_effects = default_open, chosen_ball_effect = effectName }
		if GameRules.Banjoball and GameRules.Banjoball.vFullinfo then
			local ply_info = GameRules.Banjoball.vFullinfo[playerID]
			if ply_info then
				if type(ply_info["inventory"]) ~= "table" then
					ply_info["inventory"] = { shards = 0, open_ball_effects = default_open }
				end
				ply_info["inventory"]["chosen_ball_effect"] = effectName
				if not ply_info["inventory"]["open_ball_effects"] then
					ply_info["inventory"]["open_ball_effects"] = default_open
				end
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
					print("[Supabase] Updated player inventory successfully for SteamID: " .. steam_id .. " chosen_ball_effect: " .. effectName)
				else
					print("[Supabase] Failed to update player inventory. Code: " .. res.StatusCode)
				end
			end)
		end

		-- Отправляем новое состояние обратно клиенту
		local open_ball_effects = default_open
		if GameRules.Banjoball and GameRules.Banjoball.vFullinfo and GameRules.Banjoball.vFullinfo[playerID] then
			local inv = GameRules.Banjoball.vFullinfo[playerID]["inventory"]
			if inv and inv.open_ball_effects then
				open_ball_effects = inv.open_ball_effects
			end
		end

		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerID), "ball_effects_state", {
			playerID = playerID,
			chosen = effectName,
			open_ball_effects = open_ball_effects
		})
	end)
end
