Tips = Tips or {}

function Tips:Init()
	Tips.used_this_game = {}
	Tips.last_tip_time = {}

	RegisterCustomEventListener("Tips:tip", Tips.Tip, Tips)
	print("[TIPS] Tipping system initialized successfully!")
end

function Tips:Tip(event)
	print("[TIPS_DEBUG] Server received event! event.PlayerID:", event and event.PlayerID, "event.target_player_id:", event and event.target_player_id)
	if not event then return end

	local source_id = tonumber(event.PlayerID)
	local target_id = tonumber(event.target_player_id)

	if not source_id or not target_id then
		return
	end

	if not PlayerResource:IsValidPlayerID(source_id) or not PlayerResource:IsValidPlayerID(target_id) then
		return
	end



	-- Проверка лимита на игру (TIPS_PER_GAME_MAX = 10)
	local limit = TIPS_PER_GAME_MAX or 10
	local used = Tips.used_this_game[source_id] or 0
	if used >= limit then
		DisplayError(source_id, "#dota_hud_error_used_all_tips_for_this_game")
		return
	end

	-- Проверка перезарядки (30 сек)
	local current_time = GameRules:GetGameTime()
	local last_time = Tips.last_tip_time[source_id]
	local cooldown = TIPS_COOLDOWN or 30

	if last_time and (current_time - last_time) < cooldown then
		local time_left = math.ceil(cooldown - (current_time - last_time))
		DisplayErrorWithValue(source_id, "Осталось ##time## сек.", { time = tostring(time_left) })
		return
	end

	-- Успешный тип
	Tips.used_this_game[source_id] = used + 1
	Tips.last_tip_time[source_id] = current_time

	Tips:UpdateClient(source_id)

	-- Проигрываем звук монеток
	EmitGlobalSound("General.Coins")

	-- Показываем тост справа на экране
	if Toasts and Toasts.NewForAll then
		Toasts:NewForAll(1, {
			source_player_id = tostring(source_id),
			target_player_id = tostring(target_id),
			currency = 5
		})
	end
end

function Tips:UpdateClient(player_id)
	if not PlayerResource:IsValidPlayerID(player_id) then return end
	local player = PlayerResource:GetPlayer(player_id)
	if not IsValidEntity(player) then return end

	CustomGameEventManager:Send_ServerToPlayer(player, "Tips:update", {
		max_this_game = TIPS_PER_GAME_MAX or 10,
		used_this_game = Tips.used_this_game[player_id] or 0,
		cooldown = Tips.last_tip_time[player_id] or -10000,
	})
end

Tips:Init()
