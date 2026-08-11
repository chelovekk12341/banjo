Convars:RegisterCommand('player_say', function(...)
	local arg = {...}
	table.remove(arg,1)
	local sayType = arg[1]
	table.remove(arg,1)

	local cmdPlayer = Convars:GetCommandClient()
	keys = {}
	keys.ply = cmdPlayer
	keys.teamOnly = false
	keys.text = table.concat(arg, " ")

	if (sayType == 4) then
		-- Student messages
	elseif (sayType == 3) then
		-- Coach messages
	elseif (sayType == 2) then
		-- Team only
		keys.teamOnly = true
		-- Call your player_say function here like
		self:PlayerSay(keys)
	else
		-- All chat
		-- Call your player_say function here like
		self:PlayerSay(keys)
	end
end, 'player say', 0)

-- bb_pos: prints current hero coordinates to console
-- Automatically bound to "=" key on map start
-- To set manually: bind "=" "bb_pos"
Convars:RegisterCommand('bb_pos', function()
	local cmdPlayer = Convars:GetCommandClient()
	if not cmdPlayer then
		print("[bb_pos] no client")
		return
	end
	
	local pID = cmdPlayer:GetPlayerID()
	local player_steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
	local is_owner = (player_steam_id == "201230874") or IsInToolsMode() or GameRules:IsCheatMode()
	if not is_owner then
		return
	end

	local hero = cmdPlayer:GetAssignedHero()
	if not hero then
		print("[bb_pos] no hero assigned")
		return
	end
	local pos = hero:GetAbsOrigin()
	local msg = string.format("[POS] Player %d | X=%.1f  Y=%.1f  Z=%.1f",
		pID, pos.x, pos.y, pos.z)
	print(msg)
	GameRules:SendCustomMessage(msg, 0, 0)
end, 'print hero position to console', 0)

Convars:RegisterCommand('bb_steam', function()
	local cmdPlayer = Convars:GetCommandClient()
	if not cmdPlayer then return end
	local pID = cmdPlayer:GetPlayerID()
	local player_steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
	local is_owner = (player_steam_id == "201230874") or IsInToolsMode() or GameRules:IsCheatMode()
	if not is_owner then return end

	local steam_id = PlayerResource:GetSteamAccountID(pID)
	local msg = string.format("[STEAM] Player %d | AccountID = %s", pID, tostring(steam_id))
	GameRules:SendCustomMessage(msg, 0, 0)
end, 'print steam ID', 0)

Convars:RegisterCommand('bb_random', function()
	local cmdPlayer = Convars:GetCommandClient()
	if not cmdPlayer then return end
	local pID = cmdPlayer:GetPlayerID()
	local player_steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
	local is_owner = (player_steam_id == "201230874") or IsInToolsMode() or GameRules:IsCheatMode()
	if not is_owner then return end

	Banjoball:PlayerSay({
		ply = cmdPlayer,
		text = "!random"
	})
end, 'random heroes for all', 0)

Convars:RegisterCommand('bb_score', function(...)
	local cmdPlayer = Convars:GetCommandClient()
	if not cmdPlayer then return end
	local pID = cmdPlayer:GetPlayerID()
	local player_steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
	local is_owner = (player_steam_id == "201230874") or IsInToolsMode() or GameRules:IsCheatMode()
	if not is_owner then return end

	local arg = {...}
	table.remove(arg, 1) -- remove command name
	local team_str = arg[1]
	local score_str = arg[2]
	if team_str and score_str then
		Banjoball:OnPlayerChat({
			playerid = pID,
			text = "!score " .. tostring(team_str) .. " " .. tostring(score_str)
		})
	end
end, 'set score: bb_score left/right <score>', 0)

Convars:RegisterCommand('bb_win', function(...)
	local cmdPlayer = Convars:GetCommandClient()
	if not cmdPlayer then return end
	local pID = cmdPlayer:GetPlayerID()
	local player_steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
	local is_owner = (player_steam_id == "201230874") or IsInToolsMode() or GameRules:IsCheatMode()
	if not is_owner then return end

	local arg = {...}
	table.remove(arg, 1) -- remove command name
	local team_str = arg[1]
	if team_str then
		Banjoball:OnPlayerChat({
			playerid = pID,
			text = "!win " .. tostring(team_str)
		})
	else
		Banjoball:OnPlayerChat({
			playerid = pID,
			text = "!win"
		})
	end
end, 'win game: bb_win left/right or empty for self team', 0)
