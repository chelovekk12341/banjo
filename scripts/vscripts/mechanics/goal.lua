local function IsValidHero(hero)
	return hero ~= nil and not hero:IsNull() and IsValidEntity(hero)
end

-- TODO: in the future prolly should have a class for a Team. ex. logo, color, players, etc in the far future.
function Banjoball:OnGoal(team)
	local currTime = GameRules:GetGameTime()
	if currTime-Banjoball.lastGoalTime < TIME_TILL_NEXT_ROUND then
		return
	end
	local lastGoalTime = Banjoball.lastGoalTime
	Banjoball.lastGoalTime = currTime

	RoundOver = true

	local ball = Ball.unit

	local scorer = ball.lastMovedBy
	local is_scorer_valid = scorer ~= nil and not scorer:IsNull() and IsValidEntity(scorer)

	-- Retrieve winning and losing teams.
	local otherTeam = "Radiant"
	local nWinningTeam = DOTA_TEAM_BADGUYS
	local nLosingTeam = DOTA_TEAM_GOODGUYS
	if team == "Radiant" then
		nWinningTeam = DOTA_TEAM_GOODGUYS
		nLosingTeam = DOTA_TEAM_BADGUYS
		otherTeam = "Dire"
	end

	-- Если забивший игрок невалиден, найдем любого живого игрока или рефери
	if not is_scorer_valid then
		print("[GOAL_DEBUG] Scorer is invalid! Searching for fallback scorer...")
		for _, hero in ipairs(Banjoball.vHeroes) do
			if IsValidHero(hero) then
				scorer = hero
				is_scorer_valid = true
				break
			end
		end
		if not is_scorer_valid then
			scorer = Referee
			is_scorer_valid = scorer ~= nil and not scorer:IsNull() and IsValidEntity(scorer)
		end
	end

	local scorer_fallback = false
	if not is_scorer_valid then
		scorer = {
			GetTeam = function() return nWinningTeam end,
			GetAbsOrigin = function() return Vector(0,0,0) end,
			assistTimer = 0,
			spellAssistTimer = 0,
			goalsAgainst = 0,
			playerName = "Disconnected Player",
			colStr = "white",
			IsTempestDouble = function() return false end,
			HasModifier = function() return false end,
		}
		scorer_fallback = true
	end

	local flightTime = nil
	if ball.lastHitTime and ball.lastHitTime > 0 then
		flightTime = currTime - ball.lastHitTime
	end

	local assist_table = {}
	
	local goaliePunished = false
	-- First checks to see if the referee punished a goalkeeper, otherwise this
	-- checks if a spell like slam affected the ball (with protection from false own-goals)
	if goaliePunished then
		scorer = refereePunished
		table.insert(assist_table, Referee)
		goaliePunished = nil
		goaliePunished = true
	else
		for _,hero in ipairs(Banjoball.vHeroes) do
			if IsValidHero(hero) then
				if scorer == Referee then
					scorer = hero
					table.insert(assist_table, Referee)
				end
				if hero:GetTeam() == nWinningTeam then
					if not hero.assistSpell then
						if hero.spellAssistTimer > scorer.assistTimer and hero.spellAssistTimer > scorer.spellAssistTimer then
							scorer = hero
						end
					end
				elseif scorer:GetTeam() == nLosingTeam then
					if not hero.assistSpell then
						if hero.spellAssistTimer > scorer.assistTimer and hero.spellAssistTimer > scorer.spellAssistTimer then
							scorer = hero
						end
					end
				end
			end
		end
	end

	if scorer:GetTeam() == nWinningTeam then
		local gametime = GameRules:GetGameTime()
		local assist_timer = 0

		-- Cuts off assists at when the last enemy interrupted the play
		for _,hero in ipairs(Banjoball.vHeroes) do
			if IsValidHero(hero) then
				if hero:GetTeam() ~= scorer:GetTeam() then
					if assist_timer < hero.interruptTimer then
						assist_timer = hero.interruptTimer
					end
				end
			end
		end
		
		-- Cut off the timer at the max assist time.
		if assist_timer < gametime - ASSIST_TIME then
			assist_timer = gametime - ASSIST_TIME
		end
		
		-- Cut off the timer at the last goal.
		if assist_timer < lastGoalTime then
			assist_timer = lastGoalTime
		end
		
		-- Determines who gets assists points
		for _,hero in ipairs(Banjoball.vHeroes) do
			if IsValidHero(hero) then
				if hero:GetTeam() == scorer:GetTeam() then
					if hero ~= scorer then
						local gametime = GameRules:GetGameTime()
						
						if assist_timer < hero.assistTimer or assist_timer < hero.spellAssistTimer then
							table.insert(assist_table, hero)
							hero.numAssists = hero.numAssists + 1
						end
					end
				end
			end
		end

		if not scorer_fallback then
			scorer.scoredParticle = ParticleManager:CreateParticle("particles/scored_txt/tusk_rubickpunch_txt.vpcf", PATTACH_ABSORIGIN_FOLLOW, scorer)
			ParticleManager:SetParticleControlEnt(scorer.scoredParticle, 4, scorer, 4, "", scorer:GetAbsOrigin(), true)

			local part = ParticleManager:CreateParticle("particles/units/heroes/hero_keeper_of_the_light/keeper_of_the_light_chakra_magic.vpcf", PATTACH_OVERHEAD_FOLLOW, scorer)
			ParticleManager:SetParticleControlEnt(part, 1, scorer, 1, "", scorer:GetAbsOrigin(), true)

			scorer.highlightP = ParticleManager:CreateParticle("particles/econ/courier/courier_trail_05/courier_trail_05.vpcf", PATTACH_ABSORIGIN_FOLLOW, scorer)
		end

		EmitGlobalSound("Round_End" .. RandomInt(1, NUM_ROUNDEND_SOUNDS))

		scorer.goalsAgainst = scorer.goalsAgainst + 1
	else
		EmitGlobalSound("Fail" .. RandomInt(1, NUM_FAIL_SOUNDS))

		scorer.goalsAgainst = scorer.goalsAgainst - 1
	end


	ball.dontChangeFriction = true

	-- Slow the ball down a lot
	ball:SetPhysicsFriction(BALL_FRICTION)

	--local win_ball_pos = ball:GetAbsOrigin()
	Timers:CreateTimer(.06, function()
		local win_ball_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_templar_assassin/templar_assassin_trap_explode.vpcf", PATTACH_ABSORIGIN, ball.particleDummy)
		EmitSoundAtPosition("Hero_TemplarAssassin.Trap.Explode", ball:GetAbsOrigin())
	end)

	CleanUp(ball)

	-- force activate the break abil if hero has it.
	for _,hero in ipairs(Banjoball.vHeroes) do
		if IsValidHero(hero) then
			local surge_break = hero:GetAbilityByIndex(2)
			if surge_break then
				local abilName = surge_break:GetAbilityName()
				if abilName and string.ends(abilName, "break") then
					hero:CastAbilityNoTarget(surge_break, 0)
				end
			end

			if hero:GetClassname() == "npc_dota_hero_slark" then
				if hero.pritaica then
					local slarkBreak = hero:FindAbilityByName("ninja_invis_sprint_break")
					if slarkBreak then
						hero:CastAbilityNoTarget(slarkBreak, 0)
					end
				end
			end

			AddEndgameRoot(hero)

			if hero:GetTeam() == nWinningTeam then
				ParticleManager:CreateParticle("particles/legion_duel_victory/legion_commander_duel_victory.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)
				GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, hero, "modifier_victory_anim", {})
			else
				GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, hero, "modifier_defeat_anim", {})
			end
		end
	end

	local heroWhoDidNotSave = nil
	for _,hero in ipairs(Banjoball.vHeroes) do
		if IsValidHero(hero) then
			if hero:GetTeam() == nLosingTeam then
				if hero.isGoalie then
					heroWhoDidNotSave = hero
					break
				end
				if heroWhoDidNotSave == nil or heroWhoDidNotSave.time_as_goalie < hero.time_as_goalie then
					heroWhoDidNotSave = hero
				end
			end
		end
	end

	if heroWhoDidNotSave ~= nil and ball.lastMovedBy:GetTeam() ~= heroWhoDidNotSave:GetTeam() and (heroWhoDidNotSave.isGoalie or heroWhoDidNotSave.time_as_goalie > 0) then
		print("goalie didn't save.")
		heroWhoDidNotSave.non_saves = heroWhoDidNotSave.non_saves + 1
	end

	-- Allot time for the break ability to execute.
	Timers:CreateTimer(.06, function()
		for _,hero in ipairs(Banjoball.vHeroes) do
			if IsValidHero(hero) then
				CleanUp(hero)
				AddSilence(hero)
				if hero:IsTempestDouble() and hero:HasModifier("modifier_newsprint") then
					hero:RemoveModifierByName("modifier_kill")
				end
			end
		end
	end)

	-- Check if game over.
	local winningTeamCol = "blue"
	local losingTeamCol = "red"
	if nWinningTeam == DOTA_TEAM_BADGUYS then
		winningTeamCol = "red"
		losingTeamCol = "blue"
		self.direScore = self.direScore + 1
		self.forSFDire = math.min((self.forSFDire + 1), 3) -- if dire scores, SF takes minimum score between 3 (max multiplier) and his custom score
		self.forSFRadiant = math.max((self.forSFRadiant - 1), 0) -- Radiant SF takes maximum score between 0 (min multiplier) and his custom score
		print("Bad guys " .. self.direScore)
		GameRules:GetGameModeEntity():SetTopBarTeamValue ( DOTA_TEAM_BADGUYS, self.direScore )
		if self.direScore >= SCORE_TO_WIN then
			Banjoball:OnWonGame(DOTA_TEAM_BADGUYS)
			GameOver = true
		end
	else
		self.radiantScore = self.radiantScore + 1
		self.forSFRadiant = math.min((self.forSFRadiant + 1), 3)
		self.forSFDire = math.max((self.forSFDire - 1), 0)
		print("Good guys guys " .. self.radiantScore)
		GameRules:GetGameModeEntity():SetTopBarTeamValue ( DOTA_TEAM_GOODGUYS, self.radiantScore )
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
		if IsValidHero(hero) then
			local mult = (hero:GetTeam() == 2 and Banjoball.forSFRadiant) or Banjoball.forSFDire
			if hero:GetClassname() == "npc_dota_hero_nevermore" then
				hero.kickPower = (KICKVEL_PER_GOAL * mult) + KICK_VELOCITY
			end
		end
	end

	local lines = {
		[1] = ColorIt(scorer.playerName or "Unknown", scorer.colStr or "white") .. " scored for the " .. ColorIt(team or "Unknown", winningTeamCol or "white") .. "!!!"
	}
	-- Check for own goals
	if scorer:GetTeam() == nLosingTeam then
		lines[1] = ColorIt(scorer.playerName or "Unknown", scorer.colStr or "white") .. " has own goaled on " .. ColorIt(otherTeam or "Unknown", losingTeamCol or "white") .. "!!!"
	end

	for _,assist in pairs(assist_table) do
		if assist == Referee then
			table.insert(lines, "The Referee has assisted in the goal!!!")
		else
			table.insert(lines, ColorIt(assist.playerName or "Unknown", assist.colStr or "white") .. " assisted in the goal!!!")
		end
	end

	ShowQuickMessages(lines, .2)

	if flightTime then
		if ENABLE_FLIGHT_TIME_MSG then
			local hitHeroName = "неизвестного героя"
			if ball.lastHitHero and ball.lastHitHero.playerName then
				hitHeroName = ball.lastHitHero.playerName
			end
			local chatMsg = string.format("Время полета мяча от удара героя %s до ворот: %.2f сек.", hitHeroName, flightTime)
			GameRules:SendCustomMessage(chatMsg, 0, 0)
		end

		if flightTime < 0.6 and ENABLE_FAST_GOAL_SOUND then
			CustomGameEventManager:Send_ServerToAllClients("play_edits_sound", { sound = "MontagemVozesProfundas" })
		end
	end

	RoundsCompleted = RoundsCompleted + 1

	RoundInProgress = false
	
	Banjoball:UpdateTeamScoreboard()
	
	if GameOver then
		return
	end

	local function StartPrep(extraDelay)
		extraDelay = extraDelay or 0
		local scorerName = (scorer and scorer.playerName) or "Unknown"

		-- Если включён режим "без респавна" — стартуем раунд мгновенно, без отсчёта
		if _no_goal_respawn then
			ShowCenterMsg(scorerName .. " SCORED!", 0)
			Banjoball.timeRemaining = 0

			-- Выполняем блок сброса состояния сразу
			for _,hero in ipairs(Banjoball.vHeroes) do
				if IsValidHero(hero) then
					if hero:HasModifier("modifier_flail_passive") then
						hero:RemoveModifierByName("modifier_flail_passive")
					end

					AddEndgameRoot(hero)

					if hero:HasModifier("modifier_victory_anim") then
						hero:RemoveModifierByName("modifier_victory_anim")
					elseif hero:HasModifier("modifier_defeat_anim") then
						hero:RemoveModifierByName("modifier_defeat_anim")
					end

					hero.dontChangeFriction = false
					hero:SetPhysicsFriction(GROUND_FRICTION)
					hero:StopPhysicsSimulation()

					if ball.netParticle then
						ParticleManager:DestroyParticle(ball.netParticle, false)
						ball.netParticle = nil
					end

					-- Reset last trackers
					hero.trackedPosition[1] = hero:GetAbsOrigin()
					hero.trackedVelocity[1] = Vector(0,0,0)
					hero.trackedStart = 1
					hero.trackedEnd = 2
					hero.trackedEndSafe = 1

					if hero.trackedParticle then
						local arrowPos = Vector(hero.trackedPosition[hero.trackedEndSafe].x, hero.trackedPosition[hero.trackedEndSafe].y, hero.trackedPosition[hero.trackedEndSafe].z + TRACKER_ARROW_Z_OFFSET)
						ParticleManager:SetParticleControl(hero.trackedParticle, 0, arrowPos)
					end

					ParticleManager:CreateParticle("particles/econ/events/ti4/blink_dagger_end_ti4.vpcf", PATTACH_ABSORIGIN, hero)

					if is_scorer_valid and scorer.highlightP then
						ParticleManager:DestroyParticle(scorer.highlightP, false)
						scorer.highlightP = nil
					end
				end
			end

			ParticleManager:CreateParticle("particles/econ/events/ti5/blink_dagger_end_ti5.vpcf", PATTACH_ABSORIGIN, ball.particleDummy)

			ball.controller = nil
			ball.lastHitTime = nil
			ball.lastHitHero = nil
			ball.dontChangeFriction = false
			ball:SetPhysicsFriction(BALL_FRICTION)

			if ball.ballParticle then
				ParticleManager:DestroyParticle(ball.ballParticle, true)
				ball.ballParticle = ParticleManager:CreateParticle("particles/ball/ball.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
				ball.trailColor = COLOR_ARR_WHITE[COLOR_INDEX_BASE]
				ParticleManager:SetParticleControl(ball.ballParticle, 5, ball.trailColor)
			end

			if is_scorer_valid and scorer.GetAbsOrigin then
				FindClearSpaceForUnit(ball, scorer:GetAbsOrigin(), false)
			else
				FindClearSpaceForUnit(ball, Vector(0,0,0), false)
			end

			Timers:CreateTimer(.03, function()
				ball:StopPhysicsSimulation()
			end)

			-- Мгновенный старт раунда
			Timers:CreateTimer(0.1, function()
				Banjoball.timeRemaining = 0

				for _,hero in ipairs(Banjoball.vHeroes) do
					if IsValidHero(hero) then
						RemoveEndgameRoot(hero)
						RemoveSilence(hero)
						hero:StartPhysicsSimulation()
						hero:SetPhysicsAcceleration(GRAVITY)
						hero:SetPhysicsVelocity(Vector(0,0,0))
					end
				end

				ball:StartPhysicsSimulation()
				ball:SetPhysicsAcceleration(GRAVITY)

				local ballVel = BALL_TO_GOODGUYS
				if nLosingTeam == DOTA_TEAM_BADGUYS then
					ballVel = BALL_TO_BADGUYS
				end

				ball:SetPhysicsVelocity(ballVel)

				RoundOver = false
				RoundInProgress = true

				GameRules:SendCustomMessage("PLAY!!", 0, 0)
				EmitGlobalSound("Round_Start" .. RandomInt(1, NumRoundStartSounds))
			end)
			return
		end

		-- Стандартный путь: задержка + 3-секундный обратный отсчёт
		local start = 3 + extraDelay
		ShowCenterMsg(scorerName .. " SCORED!", TIME_TILL_NEXT_ROUND + extraDelay - start )
		local roundCountdownSet = RandomInt(1, #RoundCountdownSounds)
		local numCountdownSounds = RoundCountdownSounds[roundCountdownSet]

		Banjoball.timeRemaining = TIME_TILL_NEXT_ROUND + extraDelay
		
		for i=start,1,-1 do
			Timers:CreateTimer(TIME_TILL_NEXT_ROUND + extraDelay - i, function()
				if i == start then
					if USE_SCRIPT_SPAWNS and not _no_goal_respawn then
						Banjoball:AssignTeamSpawns(DOTA_TEAM_GOODGUYS)
						Banjoball:AssignTeamSpawns(DOTA_TEAM_BADGUYS)
					end

					for _,hero in ipairs(Banjoball.vHeroes) do
						if IsValidHero(hero) then
							if hero:HasModifier("modifier_flail_passive") then
								hero:RemoveModifierByName("modifier_flail_passive")
							end

							AddEndgameRoot(hero)

							if hero:HasModifier("modifier_victory_anim") then
								hero:RemoveModifierByName("modifier_victory_anim")
							elseif hero:HasModifier("modifier_defeat_anim") then
								hero:RemoveModifierByName("modifier_defeat_anim")
							end

						-- NOTE: make sure to do all physics stuff BEFORE StopPhysicsSimulation or AFTER StartPhysicsSimulation.
						hero.dontChangeFriction = false

						hero:SetPhysicsFriction(GROUND_FRICTION)

						hero:StopPhysicsSimulation()

						if ball.netParticle then
							ParticleManager:DestroyParticle(ball.netParticle, false)
							ball.netParticle = nil
						end

						-- return heroes back to their spawn positions.
						if not _no_goal_respawn and hero.spawn_pos then
							hero:SetAbsOrigin(Vector(hero.spawn_pos.x, hero.spawn_pos.y, GroundZ))
						end
						
						-- Reset last trackers
						hero.trackedPosition[1] = hero:GetAbsOrigin()
						hero.trackedVelocity[1] = Vector(0,0,0)
						hero.trackedStart = 1
						hero.trackedEnd = 2
						hero.trackedEndSafe = 1
						
						if hero.trackedParticle then
							local arrowPos = Vector(hero.trackedPosition[hero.trackedEndSafe].x, hero.trackedPosition[hero.trackedEndSafe].y, hero.trackedPosition[hero.trackedEndSafe].z + TRACKER_ARROW_Z_OFFSET)
							ParticleManager:SetParticleControl(hero.trackedParticle, 0, arrowPos)
						end

						ParticleManager:CreateParticle("particles/econ/events/ti4/blink_dagger_end_ti4.vpcf", PATTACH_ABSORIGIN, hero)

						if is_scorer_valid and scorer.highlightP then
							ParticleManager:DestroyParticle(scorer.highlightP, false)
							scorer.highlightP = nil
						end

						-- make them all face the ball (looks nicer)
						Timers:CreateTimer(.03, function()
							if IsValidHero(hero) then
								hero:SetForwardVector((ball:GetAbsOrigin()-hero:GetAbsOrigin()):Normalized())

								hero:SetMana(hero:GetMaxMana())

								Timers:CreateTimer(.03, function()
									if IsValidHero(hero) then
										hero:AddNewModifier(ball, nil, "modifier_camera_follow", {})
										PlayAnimation("act_dota_spawn", hero)
									end
								end)
							end
						end)
					end
				end

				-- play some particle on the ball
				ParticleManager:CreateParticle("particles/econ/events/ti5/blink_dagger_end_ti5.vpcf", PATTACH_ABSORIGIN, ball.particleDummy)

				ball.controller = nil
				ball.lastHitTime = nil
				ball.lastHitHero = nil

				ball.dontChangeFriction = false

				ball:SetPhysicsFriction(BALL_FRICTION)
				
				if ball.ballParticle then
					ParticleManager:DestroyParticle(ball.ballParticle, true)
					ball.ballParticle = ParticleManager:CreateParticle("particles/ball/ball.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
					ball.trailColor = COLOR_ARR_WHITE[COLOR_INDEX_BASE]
					ParticleManager:SetParticleControl(ball.ballParticle, 5, ball.trailColor)
				end

				--ball:SetAbsOrigin(Vector(0,0,GroundZ))
				if _no_goal_respawn and is_scorer_valid and scorer.GetAbsOrigin then
					FindClearSpaceForUnit(ball, scorer:GetAbsOrigin(), false)
				else
					FindClearSpaceForUnit(ball, Vector(0,0,0), false)
				end

				Timers:CreateTimer(.03, function()
					ball:StopPhysicsSimulation()
				end)
			end
			EmitGlobalSound("RoundCountdown" .. roundCountdownSet .. "_" .. RandomInt(1, numCountdownSounds))
			GameRules:SendCustomMessage(i .. "...", 0, 0)
		end)
	end

	Timers:CreateTimer(TIME_TILL_NEXT_ROUND + extraDelay, function()
		Banjoball.timeRemaining = 0
		
		for _,hero in ipairs(Banjoball.vHeroes) do
			if IsValidHero(hero) then
				RemoveEndgameRoot(hero)

				RemoveSilence(hero)

				hero:StartPhysicsSimulation()

				hero:SetPhysicsAcceleration(GRAVITY)

				hero:SetPhysicsVelocity(Vector(0,0,0))
			end
		end

			ball:StartPhysicsSimulation()

			ball:SetPhysicsAcceleration(GRAVITY)
			
			local ballVel = BALL_TO_GOODGUYS
			if nLosingTeam == DOTA_TEAM_BADGUYS then
				ballVel = BALL_TO_BADGUYS
			end

			ball:SetPhysicsVelocity(ballVel)
			
			RoundOver = false
			RoundInProgress = true

			GameRules:SendCustomMessage("PLAY!!", 0, 0)

			local roundStartSound = "Round_Start" .. RandomInt(1, NumRoundStartSounds)

			EmitGlobalSound(roundStartSound)

			--print("playing " .. roundStartSound)
		end)
	end

	if flightTime and flightTime < 0.6 and ENABLE_FAST_GOAL_PAUSE then
		-- Ставим игру на стандартную паузу Dota 2
		PauseGame(true)
		
		-- Снимаем с паузы через 3 секунды реального времени
		Timers:CreateTimer({
			useGameTime = false,
			endTime = 3,
			callback = function()
				PauseGame(false)
			end
		})
		
		StartPrep(3)
	else
		StartPrep()
	end
end

function Banjoball:OnWonGame( nWinningTeam )
	local shutout = false
	local sWinningTeam = "Radiant"
	local lWinningTeam = "#radiant_victory"
	if nWinningTeam == DOTA_TEAM_BADGUYS then
		sWinningTeam = "Dire"
		lWinningTeam = "#dire_victory"
		if self.radiantScore == 0 then
			shutout = true
		end
	else
		if self.direScore == 0 then
			shutout = true
		end
	end
	ShowCenterMsg(sWinningTeam .. " WINS!", 4 )
	-- print('bef win', #Banjoball.vSteamIds)
	local real_players_count = 0
	for pID = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsFakeClient(pID) and not PlayerResource:IsBroadcaster(pID) then
			real_players_count = real_players_count + 1
		end
	end

	-- Update match record on Supabase server
	self:UpdateMatchRecord(nWinningTeam, real_players_count)

	if SITEOK == true and MMROK == true and real_players_count >= 4 and not IsInToolsMode() then
		local players_data = {}
		for i,v in pairs(Banjoball.vFullinfo) do
			if v ~= nil and v["Hero"] ~= nil and (v["Team"] == 2 or v["Team"] == 3) and v["Steam"] ~= nil and v["Steam"] ~= 0 and tostring(v["Steam"]) ~= "0" then
				local multiplier = v.double_down and 2 or 1
				if v["Team"] == nWinningTeam then
					v["MMR"] = (v["MMR"] or 1000) + (MMR_PER_GAME * multiplier)
					v["WINS"] = (v["WINS"] or 0) + 1
				else
					v["MMR"] = (v["MMR"] or 1000) - (MMR_PER_GAME * multiplier)
					v["LOSE"] = (v["LOSE"] or 0) + 1
				end
				local new_last_double_down_at = v.last_double_down_at
				if v.double_down then
					new_last_double_down_at = GetISO8601Time(GetSystemTimeTableCustom())
				end
				print(string.format("[DoubleDown] Saving player to Supabase payload: steam_id=%s, double_down=%s, last_double_down_at=%s",
					tostring(v["Steam"]), tostring(v.double_down), tostring(new_last_double_down_at)))

				table.insert(players_data, {
					steam_id = tostring(v["Steam"]),
					mmr = v["MMR"] or 1000,
					wins = v["WINS"] or 0,
					lose = v["LOSE"] or 0,
					nickname = PlayerResource:GetPlayerName(i),
					-- last_double_down_at = new_last_double_down_at, -- Временно отключено
					camera_distance = v["cam_distance"] or 2000,
					camera_locked = v["cam_locked"] == true,
					clicker_active = v["clicker_active"] ~= false,
					spells_hidden = v["spells_hidden"] == true,
					ally_abilities_hidden = v["ally_abilities_hidden"] == true,
					inventory = v["inventory"]
				})
			end
		end
		Banjoball:FullRequest(players_data)
	end
	-- TODO:
	--[[for _,hero in pairs(self.vHeroes) do
		-- inc games won for player.
	end]]
	CustomGameEventManager:Send_ServerToAllClients("game_over", {winner = lWinningTeam})
	Timers:CreateTimer(1.0, function()
		GameRules:SetGameWinner( nWinningTeam )
	end)
	GameRules:SetSafeToLeave( true )
	-- TODO: show popup with elo rating change

end

--[[function Banjoball:GetTeamName( team )
	if team == DOTA_TEAM_GOODGUYS then
end]]

function CleanUp( unit )
	if unit.isBanjoHero then
		local hero = unit
		if hero.isUsingPull then
			Banjoball:BreakPull(hero)
		end
	elseif unit.isBall then
		local ball = Ball.unit
		if ball.affectedByPowershot then
			ball.affectedByPowershot = false
			ParticleManager:DestroyParticle(ball.powershot_particle, false)
			ball.affectedByPowershot = false
		end
	end
end

function Banjoball:UpdateTeamScoreboard()
	CustomGameEventManager:Send_ServerToAllClients("updateTeamScores", {blueScore = Banjoball.radiantScore, redScore = Banjoball.direScore})
end

function Banjoball:SendLiveMatchUpdate()
	local match_id = self.current_match_record_id
	if not match_id then return end

	local real_players_count = 0
	for pID = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsFakeClient(pID) and not PlayerResource:IsBroadcaster(pID) then
			real_players_count = real_players_count + 1
		end
	end

	local players_data = {}
	for _, hero in ipairs(Banjoball.vHeroes) do
		if hero and not hero:IsNull() and IsValidEntity(hero) then
			local pID = hero:GetPlayerID()
			if pID and PlayerResource:IsValidPlayerID(pID) then
				local steam_id = "0"
				local steam_id_64 = "0"
				local is_bot = PlayerResource:IsFakeClient(pID)
				if not is_bot then
					steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
					steam_id_64 = tostring(PlayerResource:GetSteamID(pID))
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
				local possession = math.floor((hero.possession_time or 0) + 0.5)
				local goalie = hero.goalie or 0
				local nonSaves = hero.non_saves or 0
				
				local total_score = (SCORE_GOAL_POINTS * goals) + (SCORE_ASSIST_POINTS * assists) + (SCORE_STEAL_POINTS * steals + SCORE_TURNOVER_POINTS * turnovers) + (SCORE_PICKUP_POINTS * pickups) + (SCORE_PASS_POINTS * passes) + (SCORE_SAVE_POINTS * saves) + (SCORE_NONSAVE_POINTS * nonSaves)

				local start_mmr = 1000
				if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
					start_mmr = Banjoball.vFullinfo[pID]["MMR"] or 1000
				end
 
				local player_name = PlayerResource:GetPlayerName(pID) or ""
				local display_name = player_name
				local avatar_url = ""
				if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
					if Banjoball.vFullinfo[pID]["steam_name"] and Banjoball.vFullinfo[pID]["steam_name"] ~= "" then
						display_name = Banjoball.vFullinfo[pID]["steam_name"]
					end
					avatar_url = Banjoball.vFullinfo[pID]["steam_avatar"] or ""
				end
 
				local connection_state = PlayerResource:GetConnectionState(pID)
				local is_disconnected = (connection_state == DOTA_CONNECTION_STATE_DISCONNECTED) or (connection_state == DOTA_CONNECTION_STATE_ABANDONED)

				table.insert(players_data, {
					steam_id = steam_id,
					steam_id_64 = steam_id_64,
					name = display_name,
					avatar_url = avatar_url,
					hero = hero:GetUnitName(),
					team = hero:GetTeam(),
					disconnected = is_disconnected,
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

	local url = SUPABASE_URL .. "/rest/v1/matches"
	local req = CreateHTTPRequestScriptVM("POST", url)
	req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Content-Type", "application/json")
	req:SetHTTPRequestHeaderValue("Prefer", "resolution=merge-duplicates")
	req:SetHTTPRequestHeaderValue("x-custom-auth", SUPABASE_AUTH_KEY)

	local update_payload = {
		match_id = match_id,
		status = "live",
		captain_radiant = cap_radiant,
		captain_dire = cap_dire,
		radiant_score = self.radiantScore,
		dire_score = self.direScore,
		duration = math.max(0, math.floor(GameRules:GetGameTime() - (HUMAN_GAME_TIME or 0))),
		players_count = real_players_count,
		players_data = players_data,
		is_local = not IsDedicatedServer()
	}

	local body = json.encode(update_payload)

	req:SetHTTPRequestRawPostBody("application/json", body)
	req:SetHTTPRequestAbsoluteTimeoutMS(100000)
	req:Send(function(res)
		if res.StatusCode == 204 or res.StatusCode == 200 then
			print("[Supabase] Match record updated live: " .. match_id)
			print("[Supabase] Live update sent (Score: " .. tostring(self.radiantScore) .. ":" .. tostring(self.direScore) .. ")")
		else
			print("[Supabase] Live update FAILED (" .. tostring(res.StatusCode) .. ") body: " .. tostring(res.Body))
		end
	end)
end

function Banjoball:UpdateMatchRecord(nWinningTeam, real_players_count)
	if self.is_match_abandoned then
		print("[BANJOBALL] UpdateMatchRecord ignored because match is abandoned")
		return
	end
	local match_id = self.current_match_record_id
	
	-- Проверяем реальный Match ID в конце игры на случай, если при старте он еще не был получен
	local real_match_id = "0"
	if GameRules and GameRules.Script_GetMatchID then
		real_match_id = tostring(GameRules:Script_GetMatchID()):gsub("ULL", "")
	end

	local updated_match_id_body = nil

	if real_match_id ~= "0" and real_match_id ~= "nil" and real_match_id ~= "local" then
		-- Если до этого у нас был локальный ID, а теперь есть реальный Match ID от Valve
		if match_id and string.match(match_id, "^local_") then
			print(string.format("[Supabase] Match ID changed from %s to %s. Migrating record.", match_id, real_match_id))
			updated_match_id_body = real_match_id
		else
			match_id = real_match_id
			self.current_match_record_id = real_match_id
		end
	end

	if not match_id then
		local m_id = "0"
		if GameRules and GameRules.Script_GetMatchID then
			m_id = tostring(GameRules:Script_GetMatchID()):gsub("ULL", "")
		end
		if m_id == "0" or m_id == "nil" then
			m_id = "local_" .. tostring(math.floor(GameRules:GetGameTime())) .. "_" .. tostring(math.random(1000, 9999))
		end
		match_id = m_id
		self.current_match_record_id = match_id
	end

	-- Пересчитаем игроков с исключением обсерверов
	local clean_players_count = 0
	for pID = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsFakeClient(pID) and not PlayerResource:IsBroadcaster(pID) then
			clean_players_count = clean_players_count + 1
		end
	end

	local players_data = {}
	
	-- Для MVP каждой команды
	local mvp_radiant_sid = "0"
	local mvp_dire_sid = "0"
	local max_score_radiant = -999999
	local max_score_dire = -999999

	for _, hero in ipairs(Banjoball.vHeroes) do
		if hero and not hero:IsNull() and IsValidEntity(hero) then
			local pID = hero:GetPlayerID()
			if pID and PlayerResource:IsValidPlayerID(pID) then
				local steam_id = "0"
				local steam_id_64 = "0"
				local is_bot = PlayerResource:IsFakeClient(pID)
				if not is_bot then
					steam_id = tostring(PlayerResource:GetSteamAccountID(pID))
					steam_id_64 = tostring(PlayerResource:GetSteamID(pID))
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
				local possession = math.floor((hero.possession_time or 0) + 0.5)
				local goalie = hero.goalie or 0
				local nonSaves = hero.non_saves or 0
				
				local total_score = (SCORE_GOAL_POINTS * goals) + (SCORE_ASSIST_POINTS * assists) + (SCORE_STEAL_POINTS * steals + SCORE_TURNOVER_POINTS * turnovers) + (SCORE_PICKUP_POINTS * pickups) + (SCORE_PASS_POINTS * passes) + (SCORE_SAVE_POINTS * saves) + (SCORE_NONSAVE_POINTS * nonSaves)

				local start_mmr = 1000
				if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
					start_mmr = Banjoball.vFullinfo[pID]["MMR"] or 1000
				end

				local double_down = false
				if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
					double_down = Banjoball.vFullinfo[pID].double_down == true
				end
				local multiplier = double_down and 2 or 1

				local mmr_change = 0
				local end_mmr = start_mmr
				if (clean_players_count >= 6 or IsInToolsMode()) and not is_bot then
					if hero:GetTeam() == nWinningTeam then
						mmr_change = MMR_PER_GAME * multiplier
					else
						mmr_change = -MMR_PER_GAME * multiplier
					end
					end_mmr = start_mmr + mmr_change
				end

				-- Бот не может быть MVP. Считаем MVP для Radiant и Dire отдельно
				if not is_bot then
					local hero_team = hero:GetTeam()
					if hero_team == 2 then -- Radiant
						if total_score > max_score_radiant then
							max_score_radiant = total_score
							mvp_radiant_sid = steam_id
						end
					elseif hero_team == 3 then -- Dire
						if total_score > max_score_dire then
							max_score_dire = total_score
							mvp_dire_sid = steam_id
						end
					end
				end

				local player_name = PlayerResource:GetPlayerName(pID) or ""
				local display_name = player_name
				local avatar_url = ""
				if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
					if Banjoball.vFullinfo[pID]["steam_name"] and Banjoball.vFullinfo[pID]["steam_name"] ~= "" then
						display_name = Banjoball.vFullinfo[pID]["steam_name"]
					end
					avatar_url = Banjoball.vFullinfo[pID]["steam_avatar"] or ""
				end
				local connection_state = PlayerResource:GetConnectionState(pID)
				local is_disconnected = (connection_state == DOTA_CONNECTION_STATE_DISCONNECTED) or (connection_state == DOTA_CONNECTION_STATE_ABANDONED)

				table.insert(players_data, {
					steam_id = steam_id,
					steam_id_64 = steam_id_64,
					name = display_name,
					avatar_url = avatar_url,
					hero = hero:GetUnitName(),
					team = hero:GetTeam(),
					disconnected = is_disconnected,
					goals = goals,
					assists = assists,
					saves = saves,
					non_saves = nonSaves,
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
					end_mmr = end_mmr,
					mmr_change = mmr_change
				})
			end
		end
	end

	-- Конвертируем победителя в текстовый формат
	local winner_name = nil
	if nWinningTeam == 2 then
		winner_name = "radiant"
	elseif nWinningTeam == 3 then
		winner_name = "dire"
	end

	-- Массив из 2 значений MVP: [MVP левой (Radiant), MVP правой (Dire)]
	local mvp_match_payload = { mvp_radiant_sid, mvp_dire_sid }

	local url = SUPABASE_URL .. "/rest/v1/matches"
	local req = CreateHTTPRequestScriptVM("POST", url)
	req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Content-Type", "application/json")
	req:SetHTTPRequestHeaderValue("Prefer", "resolution=merge-duplicates")
	req:SetHTTPRequestHeaderValue("x-custom-auth", SUPABASE_AUTH_KEY)

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

	local update_payload = {
		match_id = match_id,
		status = "finished",
		winner = winner_name,
		captain_radiant = cap_radiant,
		captain_dire = cap_dire,
		radiant_score = self.radiantScore,
		dire_score = self.direScore,
		duration = math.max(0, math.floor(GameRules:GetGameTime() - (HUMAN_GAME_TIME or 0))),
		mvp_match = mvp_match_payload,
		finished_at_msc = Banjoball:GetMSKTimeISO(),
		players_count = clean_players_count,
		players_data = players_data,
		is_local = not IsDedicatedServer(),
		is_training = IsTrainingMode()
	}

	if updated_match_id_body then
		update_payload.match_id = updated_match_id_body
	end

	local body = json.encode(update_payload)

	req:SetHTTPRequestRawPostBody("application/json", body)
	req:SetHTTPRequestAbsoluteTimeoutMS(100000)
	req:Send(function(res)
		if res.StatusCode == 204 or res.StatusCode == 200 then
			print("[Supabase] Match record updated successfully: " .. match_id)
			local final_match_id = updated_match_id_body or match_id
			if updated_match_id_body then
				self.current_match_record_id = updated_match_id_body
			end
			
			-- Отправляем статистику игроков в match_players (yt ,jn)
			Banjoball:SendMatchPlayersData(players_data, final_match_id)
		else
			print("[Supabase] UpdateMatchRecord failed with status: " .. tostring(res.StatusCode) .. " body: " .. tostring(res.Body))
		end
	end)
end

function Banjoball:SendMatchPlayersData(players_data, match_id)
	if not players_data or #players_data == 0 then return end

	local match_players_payload = {}
	for _, player in ipairs(players_data) do
		-- Исключаем ботов (steam_id == "0") из детальной статистики, чтобы не нарушать внешние ключи в БД
		if player.steam_id and player.steam_id ~= "0" then
			local mp = {
				match_id = match_id,
				steam_id = player.steam_id,
				steam_id_64 = player.steam_id_64,
				hero = player.hero,
				team = player.team,
				goals = player.goals,
				assists = player.assists,
				saves = player.saves,
				steals = player.steals,
				turnovers = player.turnovers,
				steals_turnovers = player.steals_turnovers,
				pickups = player.pickups,
				passes = player.passes,
				passes_received = player.passes_received,
				possession = player.possession,
				goalie = player.goalie,
				total_score = player.total_score,
				start_mmr = player.start_mmr,
				end_mmr = player.end_mmr,
				mmr_change = player.mmr_change
			}
			table.insert(match_players_payload, mp)
		end
	end

	if #match_players_payload == 0 then return end

	local url = SUPABASE_URL .. "/rest/v1/match_players"
	local req = CreateHTTPRequestScriptVM("POST", url)
	req:SetHTTPRequestHeaderValue("apikey", SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Authorization", "Bearer " .. SUPABASE_KEY)
	req:SetHTTPRequestHeaderValue("Content-Type", "application/json")
	req:SetHTTPRequestHeaderValue("x-custom-auth", SUPABASE_AUTH_KEY)

	local body = json.encode(match_players_payload)
	req:SetHTTPRequestRawPostBody("application/json", body)
	req:SetHTTPRequestAbsoluteTimeoutMS(100000)
	req:Send(function(res)
		if res.StatusCode == 201 or res.StatusCode == 200 then
			print("[Supabase] Match players statistics saved successfully: " .. match_id)
		else
			print("[Supabase] SendMatchPlayersData failed with status: " .. tostring(res.StatusCode) .. " body: " .. tostring(res.Body))
		end
	end)
end
