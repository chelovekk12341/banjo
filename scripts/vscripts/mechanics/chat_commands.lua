print('[CHAT_COMMANDS] mechanics/chat_commands.lua loaded')

function Banjoball:PlayerSay( keys )
	local ply = keys.ply
	local txt = keys.text

	if txt == nil or txt == "" then
		return
	end

	print("[BANJOBALL] PlayerSay: " .. tostring(txt))

	-- Команда !random в чате
	if txt and string.find(string.lower(txt), "!random") then
		print("[BANJOBALL] Received !random command. Randoming heroes for everyone who hasn't chosen.")
		Say(nil, "[BANJOBALL] Randoming heroes for players and bots...", false)
		
		local heroesPool = DEBUG_BOT_HEROES or { "npc_dota_hero_antimage" }
		
		-- Перебираем всех игроков в лобби
		for pID = 0, DOTA_MAX_PLAYERS - 1 do
			if PlayerResource:IsValidPlayerID(pID) then
				-- Проверяем, идет ли выбор героев и свободен ли слот героя у игрока
				if HeroSelection and HeroSelection.playerPicks and HeroSelection.playerPicks[pID] == nil then
					local randomHero = heroesPool[math.random(1, #heroesPool)]
					print(string.format("[BANJOBALL] Randoming hero %s for PlayerID %d", randomHero, pID))
					HeroSelection:HeroSelect({
						PlayerID = pID,
						HeroName = randomHero
					})
				end
			end
		end

		-- Принудительно сбрасываем таймер выбора героев в 0 для моментального старта
		if HeroSelection then
			Say(nil, "[BANJOBALL] Ending hero selection phase.", false)
			HeroSelection.TimeLeft = 0
			HeroSelection:Tick()
		end
	end
end

function Banjoball:OnPlayerChat( keys )
	local txt = keys.text
	local pID = keys.playerid
	if not pID then pID = keys.player_id end
	
	-- Игнорируем системные сообщения (pID == -1 или nil), чтобы избежать бесконечной рекурсии
	if pID == nil or pID == -1 then
		return
	end
	
	print("[BANJOBALL] OnPlayerChat event: text = " .. tostring(txt) .. ", player_id = " .. tostring(pID))
	
	if txt == nil or txt == "" then return end
	
	local player_steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
	local is_owner = (player_steam_id == "201230874") or IsInToolsMode() or GameRules:IsCheatMode()
	
	-- Логика из второй OnPlayerChat (команды !steam, !pos, !score, !win)
	if pID ~= nil and pID ~= -1 and is_owner then
		if txt == "-steam" or txt == "!steam" or txt == "steam" then
			local steam_id = PlayerResource:GetSteamAccountID(pID)
			local msg = string.format("[STEAM] Player %d | AccountID = %s", pID, tostring(steam_id))
			GameRules:SendCustomMessage(msg, 0, 0)
		elseif txt == "-pos" or txt == "!pos" or txt == "pos" then
			local ply = PlayerResource:GetPlayer(pID)
			if ply then
				local hero = ply:GetAssignedHero()
				if hero then
					local pos = hero:GetAbsOrigin()
					local msg = string.format("[POS] Player %d | X=%.1f  Y=%.1f  Z=%.1f",
						pID, pos.x, pos.y, pos.z)
					GameRules:SendCustomMessage(msg, 0, 0)
				end
			end
		elseif txt == "-cursor" or txt == "!cursor" or txt == "cursor" then
			local ply = PlayerResource:GetPlayer(pID)
			if ply then
				CustomGameEventManager:Send_ServerToPlayer(ply, "request_cursor_position", { player_id = pID })
			end
		elseif txt == "!ball" or txt == "-ball" or txt == "ball" then
			local ply = PlayerResource:GetPlayer(pID)
			if ply then
				local hero = ply:GetAssignedHero()
				if hero and IsValidEntity(hero) and hero:IsAlive() then
					local ball = Ball.unit
					if ball then
						local target_pos = hero:GetAbsOrigin() + hero:GetForwardVector() * 80
						target_pos.z = GROUND_Z + 20
						ball:StopPhysicsSimulation()
						ball:SetAbsOrigin(target_pos)
						ball.lastPos = target_pos
						ball.controller = nil
						ball.lastMovedBy = hero
						ball.lastHitHero = hero
						ball.lastHitTime = GameRules:GetGameTime()
						Timers:CreateTimer(0.05, function()
							ball:StartPhysicsSimulation()
							ball:SetPhysicsVelocity(Vector(0, 0, 0))
							ball:SetPhysicsAcceleration(GRAVITY)
						end)
						EmitSoundOnLocationWithCaster(target_pos, "Hero_Tinker.Laser", hero)
						GameRules:SendCustomMessage("Ball teleported to your hero!", 0, 0)
					end
				end
			end
		elseif string.match(txt, "^!score%s+(%S+)%s+(%d+)") then
			local team_str, score_str = string.match(txt, "^!score%s+(%S+)%s+(%d+)")
			team_str = string.lower(team_str)
			local new_score = tonumber(score_str)
			if new_score then
				if team_str == "left" or team_str == "radiant" or team_str == "blue" then
					self.radiantScore = new_score
					GameRules:GetGameModeEntity():SetTopBarTeamValue(DOTA_TEAM_GOODGUYS, self.radiantScore)
					CustomGameEventManager:Send_ServerToAllClients("updateTeamScores", {blueScore = self.radiantScore, redScore = self.direScore})
					GameRules:SendCustomMessage("[SCORE] Radiant score set to " .. tostring(new_score), 0, 0)
					if self.radiantScore >= SCORE_TO_WIN then
						Banjoball:OnWonGame(DOTA_TEAM_GOODGUYS)
					end
				elseif team_str == "right" or team_str == "dire" or team_str == "red" then
					self.direScore = new_score
					GameRules:GetGameModeEntity():SetTopBarTeamValue(DOTA_TEAM_BADGUYS, self.direScore)
					CustomGameEventManager:Send_ServerToAllClients("updateTeamScores", {blueScore = self.radiantScore, redScore = self.direScore})
					GameRules:SendCustomMessage("[SCORE] Dire score set to " .. tostring(new_score), 0, 0)
					if self.direScore >= SCORE_TO_WIN then
						Banjoball:OnWonGame(DOTA_TEAM_BADGUYS)
					end
				end
			end
		elseif txt == "!win left" or txt == "!win radiant" or txt == "!win blue" then
			Banjoball:OnWonGame(DOTA_TEAM_GOODGUYS)
		elseif txt == "!win right" or txt == "!win dire" or txt == "!win red" then
			Banjoball:OnWonGame(DOTA_TEAM_BADGUYS)
		elseif txt == "!win" then
			local team = PlayerResource:GetTeam(pID)
			print("[BANJOBALL] !win command executed by player " .. tostring(pID) .. " team " .. tostring(team))
			if team and team ~= DOTA_TEAM_NOTEAM then
				Banjoball:OnWonGame(team)
			end
		end
		
		if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] and Banjoball.vFullinfo[pID]["Steam"] and SELID and SELID[Banjoball.vFullinfo[pID]["Steam"]] then
			if txt:sub(1,3) == "lua" then
				Banjoball:Lua(keys)
			elseif txt:sub(1,3) == "loadhe" then
				Banjoball:LoadHeroes(keys)
			end
		end
	end
	
	-- Вызов PlayerSay для обработки !random и прочих кастомных команд чата
	if pID then
		local ply = PlayerResource:GetPlayer(pID)
		if ply then
			self:PlayerSay({
				ply = ply,
				text = txt,
				teamOnly = keys.teamonly == 1 or keys.teamOnly == true
			})
		else
			print("[BANJOBALL] Player object for ID " .. tostring(pID) .. " is nil, trying direct call")
			self:PlayerSay({
				ply = { GetAssignedHero = function() return nil end },
				text = txt,
				teamOnly = keys.teamonly == 1 or keys.teamOnly == true
			})
		end
	end
end

function Banjoball:OnPlayerSettingsChanged(event)
	local pID = event.PlayerID
	if not pID then return end
	local distance = event.distance
	local locked = event.locked
	local clicker = event.clicker_active
	local spells_hidden = event.spells_hidden

	if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
		Banjoball.vFullinfo[pID]["cam_distance"] = tonumber(distance)
		Banjoball.vFullinfo[pID]["cam_locked"] = (locked == 1 or locked == true)
		Banjoball.vFullinfo[pID]["clicker_active"] = (clicker == 1 or clicker == true)
		Banjoball.vFullinfo[pID]["spells_hidden"] = (spells_hidden == 1 or spells_hidden == true)
		
		print(string.format("[SETTINGS] Updated settings for player %d: dist=%s, lock=%s, clicker=%s, spells_hidden=%s", 
			pID, tostring(distance), tostring(locked), tostring(clicker), tostring(spells_hidden)))
	end
end

CustomGameEventManager:RegisterListener("report_cursor_position", function(_, args)
	local pID = args.PlayerID
	if not pID then return end
	local x = args.x
	local y = args.y
	local z = args.z
	if not x or not y or not z then return end
	
	local msg = string.format("[CURSOR] Player %d | X=%.1f  Y=%.1f  Z=%.1f", pID, x, y, z)
	GameRules:SendCustomMessage(msg, 0, 0)
end)
