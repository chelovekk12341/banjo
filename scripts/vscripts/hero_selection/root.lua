--[[
 Hero selection module for D2E.
 This file basically just separates the functions related to hero selection from
 the other functions present in D2E.
]]

require("config")

--Constant parameters
SELECTION_DURATION_LIMIT = 60

--Class definition
if HeroSelection == nil then
	HeroSelection = {}
	HeroSelection.__index = HeroSelection
end

--[[
	Start
	Call this function from your gamemode once the gamestate changes
	to pre-game to start the hero selection.
]]
function HeroSelection:Start()
	--Figure out which players have to pick
	 HeroSelection.playerPicks = {}
	 HeroSelection.numPickers = 0
	for pID = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID( pID ) then
			HeroSelection.numPickers = HeroSelection.numPickers + 1
		end
	end

	--Start the pick timer
	HeroSelection.TimeLeft = SELECTION_DURATION_LIMIT
	Timers:CreateTimer( 0.04, HeroSelection.Tick )

	--Keep track of the number of players that have picked
	HeroSelection.playersPicked = 0

	--Listen for the pick event
	HeroSelection.listener = CustomGameEventManager:RegisterListener( "hero_selected", HeroSelection.HeroSelect )

	-- В локальном лобби боты выбирают героев по очереди с задержкой в 1 секунду
	local isLocal = (not IsDedicatedServer() or IsInToolsMode())
	if isLocal then
		local botIndex = 1
		for pID = 0, DOTA_MAX_PLAYERS - 1 do
			if PlayerResource:IsValidPlayerID(pID) and PlayerResource:IsFakeClient(pID) then
				local delay = botIndex * 1.0
				botIndex = botIndex + 1
				Timers:CreateTimer("bot_hero_select_" .. pID, {
					useGameTime = false,
					endTime = delay,
					callback = function()
						if not HeroSelectionOver and HeroSelection.playerPicks[pID] == nil then
							local heroesPool = DEBUG_BOT_HEROES or { "npc_dota_hero_antimage" }
							local randomHero = heroesPool[math.random(1, #heroesPool)]
							print(string.format("[DRAFT] Scheduled bot hero select: Player %d picks %s", pID, randomHero))
							HeroSelection:HeroSelect({ PlayerID = pID, HeroName = randomHero })
						end
					end
				})
			end
		end
	end
end

--[[
	Tick
	A tick of the pick timer.
	Params:
		- event {table} - A table containing PlayerID and HeroID.
]]
function HeroSelection:Tick() 
	-- Если это локальное лобби, проверяем, выбрали ли все реальные игроки героев.
	-- Если да — сразу завершаем стадию выбора героев.
	local isLocal = (not IsDedicatedServer() or IsInToolsMode())
	if isLocal then
		local all_real_selected = true
		local real_players_count = 0
		for pID = 0, DOTA_MAX_PLAYERS - 1 do
			if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsFakeClient(pID) then
				real_players_count = real_players_count + 1
				if not PlayerResource:HasSelectedHero(pID) then
					all_real_selected = false
				end
			end
		end

		if real_players_count > 0 and all_real_selected then
			print("[DRAFT] All real players selected heroes in local lobby. Ending picking phase early!")
			HeroSelection:EndPicking()
			return nil
		end
	end

	--Send a time update to all clients
	if HeroSelection.TimeLeft >= 0 then
		CustomGameEventManager:Send_ServerToAllClients( "picking_time_update", {time = HeroSelection.TimeLeft} )
	end

	--Tick away a second of time
	HeroSelection.TimeLeft = HeroSelection.TimeLeft - 1
	if HeroSelection.TimeLeft == -1 then
		--End picking phase
		HeroSelection:EndPicking()
		return nil
	elseif HeroSelection.TimeLeft >= 0 then
		return 1
	else
		return nil
	end
end

--[[
	HeroSelect
	A player has selected a hero. This function is caled by the CustomGameEventManager
	once a 'hero_selected' event was seen.
	Params:
		- event {table} - A table containing PlayerID and HeroID.
]]
function HeroSelection:HeroSelect( event )

	--If this player has not picked yet give him the hero
	if HeroSelection.playerPicks[ event.PlayerID ] == nil then
		HeroSelection.playersPicked = HeroSelection.playersPicked + 1
		HeroSelection.playerPicks[ event.PlayerID ] = event.HeroName

		--Send a pick event to all clients
		CustomGameEventManager:Send_ServerToAllClients( "picking_player_pick", 
			{ PlayerID = event.PlayerID, HeroName = event.HeroName} )

		--Assign the hero if picking is over
		if HeroSelection.TimeLeft <= 0 then
			HeroSelection:AssignHero( event.PlayerID, event.HeroName )
		end
	end

	-- Если все реальные игроки выбрали героев, автопикаем ботов (только на выделенных серверах)
	local isLocal = (not IsDedicatedServer() or IsInToolsMode())
	if not isLocal then
		local has_real_players_left = false
		for pID = 0, DOTA_MAX_PLAYERS - 1 do
			if PlayerResource:IsValidPlayerID(pID) then
				-- Проверяем, является ли игрок реальным человеком (не ботом) и выбрал ли он героя
				if not PlayerResource:IsFakeClient(pID) and HeroSelection.playerPicks[pID] == nil then
					has_real_players_left = true
					break
				end
			end
		end

		if not has_real_players_left then
			local heroesPool = DEBUG_BOT_HEROES or { "npc_dota_hero_antimage" }

			for pID = 0, DOTA_MAX_PLAYERS - 1 do
				if PlayerResource:IsValidPlayerID(pID) then
					if HeroSelection.playerPicks[pID] == nil then
						local randomHero = heroesPool[math.random(1, #heroesPool)]
						print(string.format("[DRAFT] Autopicking bot hero %s for PlayerID %d", randomHero, pID))
						
						HeroSelection.playersPicked = HeroSelection.playersPicked + 1
						HeroSelection.playerPicks[pID] = randomHero

						CustomGameEventManager:Send_ServerToAllClients( "picking_player_pick", 
							{ PlayerID = pID, HeroName = randomHero} )
					end
				end
			end
		end
	end

	--Check if all heroes have been picked
	if HeroSelection.playersPicked >= HeroSelection.numPickers then
		--End picking
		HeroSelection.TimeLeft = 0
		HeroSelection:Tick()
	end
end

--[[
	EndPicking
	The final function of hero selection which is called once the selection is done.
	This function spawns the heroes for the players and signals the picking screen
	to disappear.
]]
function HeroSelection:EndPicking()
	--Stop listening to pick events
	--CustomGameEventManager:UnregisterListener( self.listener )

	local heroesPool = DEBUG_BOT_HEROES or { "npc_dota_hero_antimage" }

	-- Выдаем случайных героев всем, кто не успел выбрать самостоятельно
	for pID = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pID) then
			if HeroSelection.playerPicks[pID] == nil then
				-- Если игрок выбрал героя в стандартном UI, сохраняем его выбор
				if PlayerResource:HasSelectedHero(pID) then
					local selectedHero = PlayerResource:GetSelectedHeroName(pID)
					if selectedHero and selectedHero ~= "" then
						HeroSelection.playerPicks[pID] = selectedHero
						print(string.format("[DRAFT] Player %d already selected hero %s in standard UI.", pID, selectedHero))
					end
				end
			end

			-- Если это бот (Fake Client) и он не выбрал героя, принудительно даем ему случайного героя.
			-- Реальные игроки получат рандом от самого движка доты при старте игры.
			if HeroSelection.playerPicks[pID] == nil and PlayerResource:IsFakeClient(pID) then
				local randomHero = heroesPool[math.random(1, #heroesPool)]
				HeroSelection.playerPicks[pID] = randomHero
				print(string.format("[DRAFT] Autopicking hero %s for BOT %d", randomHero, pID))
			end
		end
	end

	--Assign the picked heroes to all players that have picked
	for player, hero in pairs( HeroSelection.playerPicks ) do
		HeroSelection:AssignHero( player, hero )
	end

	--Signal the picking screen to disappear
	CustomGameEventManager:Send_ServerToAllClients( "picking_done", {} )
	HeroSelectionOver = true
end

--[[
	AssignHero
	Assign a hero to the player. Replaces the current hero of the player
	with the selected hero, after it has finished precaching.
	Params:
		- player {integer} - The playerID of the player to assign to.
		- hero {string} - The unit name of the hero to assign (e.g. 'npc_dota_hero_rubick')
 ]]
function HeroSelection:AssignHero( player, hero )
	-- Если игрок уже выбрал именно этого героя в стандартном UI, ничего не делаем.
	-- Движок Dota 2 сам заспавнит его.
	if PlayerResource:HasSelectedHero( player ) then
		local selectedHero = PlayerResource:GetSelectedHeroName( player )
		if selectedHero == hero then
			print(string.format("[DRAFT] Player %d already selected %s. Skipping MakeRandomHeroSelection.", player, hero))
			return
		end
	end

	-- Заставляем стандартный движок доты заспавнить случайного героя на карте.
	-- Как только он заспавнится, в OnNPCSpawned мы заменим его на выбранного героя.
	local ply = PlayerResource:GetPlayer( player )
	if ply then
		ply:MakeRandomHeroSelection()
	end
end