print('[HERO_THINK] mechanics/hero_think.lua loaded')

function Banjoball:OnHeroInGameFirstTime( hero )
	print("OnHeroInGameFirstTime",hero)
	CustomGameEventManager:Send_ServerToAllClients( "update_hero_bar", {} )
	hero.StuckTicks = 0
	function hero:OnThink()
		if hero.tempremoved then return end
		local pos = hero:GetAbsOrigin()
		local vel = hero:GetPhysicsVelocity()

		if hero.goalie then
			-- check if actually still in goal (There is no Z limit for the goalie)
			if not GetGoalUnitIsWithin( hero ) then
				hero.goalie = false
				hero.gc.goalie = nil
				hero.ballGoalieProc = false

				hero:RemoveModifierByName("modifier_goalie")
				
				if hero:GetClassname() == "npc_dota_hero_terrorblade" then hero:RemoveModifierByName("modifier_metamorphosis") end
			else
				if not hero:HasModifier("modifier_goalie") then
					GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, hero, "modifier_goalie", {})
				end
				
				if hero:GetClassname() == "npc_dota_hero_terrorblade" and not hero:HasModifier("modifier_metamorphosis") then hero:AddNewModifier(hero,nil,"modifier_metamorphosis",{duration=99999})	end
			end
		end
		
		-- Figure out if a hero is stuck
		if not IsPointOnField(pos) then
			if not hero.StuckOFB then
				hero.StuckOFB = GameRules:GetGameTime()
			end
		else
			hero.StuckOFB = nil
		end
		if hero.StuckOFB and GameRules:GetGameTime() - hero.StuckOFB >= 1 then
			local old_pos = pos
			local new_pos = ClosestPointOnField(pos)
			hero:SetAbsOrigin(new_pos)
			-- local msg = string.format("[StuckOFB] Hero %s was out of bounds for >=1s. Teleporting from (%.1f, %.1f) to closest field point (%.1f, %.1f)", 
			-- 	hero:GetUnitName(), old_pos.x, old_pos.y, new_pos.x, new_pos.y)
			-- GameRules:SendCustomMessage(msg, 0, 0)
		end
		local collCheck = nil
		-- for i, ent in ipairs(GetUnitsInTrueRadius( pos, HERO_DEFAULT_RADIUS + 20 )) do--ipairs(Entities:FindAllInSphere(pos, HERO_HULL_SIZE)) do
			-- if ent.isBanjoHero and hero ~= ent and math.abs(ent:GetAbsOrigin().z - hero:GetAbsOrigin().z) <= HERO_UNSTUCK_HEIGHT  then
				-- collCheck = ent
				-- break
			-- end
		-- end
		for i,v in pairs(GetUnitsInTrueRadius( pos, HERO_DEFAULT_RADIUS + 20 )) do
			if v~=hero then
				local is_spectre_collision = false
				if (hero.HasModifier and hero:HasModifier("modifier_spectre_passive")) or
				   (v.HasModifier and v:HasModifier("modifier_spectre_passive")) then
					is_spectre_collision = true
				end
				if not is_spectre_collision then
					collCheck = true
					-- print(v,v.tempremoved,v:GetName())
				end
			end
		end
		if collCheck then
			-- ResolveNPCPositions(pos, 1)
			-- if vel:Length() ~= 0 or collCheck:GetPhysicsVelocity():Length() ~= 0 then
				-- hero:SetPhysicsVelocity(collCheck:GetPhysicsVelocity())
				-- collCheck:SetPhysicsVelocity(vel)
			-- end
			-- FindClearSpaceForUnit(hero, pos, true)
			-- FindClearSpaceForUnit(collCheck, pos, true)
			
			hero.StuckTicks = hero.StuckTicks + 1
			if hero.StuckTicks >= 3 then
				hero:SetPhysicsVelocity(Vector(0,0,0))
				hero:AddNewModifier(hero,nil,"modifier_unstuckmec", {duration=0.03}) 
				hero:RemoveModifierByName("modifier_rooted")
				hero:RemoveModifierByName("modifier_rooted_passive")
				
				-- print('gacha',hero)
				local surge_break = hero:GetAbilityByIndex(2)
				local abilName = surge_break:GetAbilityName()
				if string.ends(abilName, "break") or hero.isInBallLightning then hero:CastAbilityNoTarget(surge_break, 0) end
			end
		else
			hero.StuckTicks = 0
		end
		-- print(hero.StuckTicks)
		-- Track hero positions for up to 5 seconds before
		--if hero.trackedCounter < 10 then
			--hero.trackedCounter = hero.trackedCounter + 1
		--else
		hero.trackedStart = hero.trackedStart + 1
		hero.trackedEnd = hero.trackedEnd + 1
		
		if hero.trackedEndSafe == hero.trackedEnd - 1 then
			hero.trackedEndSafe = hero.trackedEnd
		end
		
		if hero.trackedStart == TRACKER_CIRCULAR_BUFFER_END then hero.trackedStart = 1 end
		if hero.trackedEnd == TRACKER_CIRCULAR_BUFFER_END then hero.trackedEnd = 1 end
		if hero.trackedEndSafe == TRACKER_CIRCULAR_BUFFER_END then hero.trackedEndSafe = 1 end
		
		hero.trackedPosition[hero.trackedStart] = pos
		hero.trackedVelocity[hero.trackedStart] = vel
		
		if hero.trackedParticle then
			local arrowPos = Vector(hero.trackedPosition[hero.trackedEndSafe].x, hero.trackedPosition[hero.trackedEndSafe].y, hero.trackedPosition[hero.trackedEndSafe].z + TRACKER_ARROW_Z_OFFSET)
			ParticleManager:SetParticleControl(hero.trackedParticle, 0, arrowPos)
		end
	end	
	
	Timers:CreateTimer(.1, function()
		local realPos = hero:GetAbsOrigin()

		if USE_SCRIPT_SPAWNS then
			Banjoball:AssignTeamSpawns(hero:GetTeam())
		else
			-- Count how many teammates are already in vHeroes (0-based)
			local teamSlotIndex = 0
			for _, h in ipairs(Banjoball.vHeroes) do
				if h ~= hero and h:GetTeam() == hero:GetTeam() then
					teamSlotIndex = teamSlotIndex + 1
				end
			end

			-- Only override spawn for the 5th player in a team (index 4, slots 0..3 use map spawns)
			if teamSlotIndex >= 4 then
				local spawnTable = (hero:GetTeam() == DOTA_TEAM_GOODGUYS) and SPAWN_GOODGUYS or SPAWN_BADGUYS
				local spawnPos = spawnTable[5] -- Use the 5th spawn vector for the 5th player
				hero.spawn_pos = spawnPos
				hero:SetAbsOrigin(spawnPos)
				hero.trackedPosition[1] = spawnPos
				print(string.format("[MAP_SPAWN] 5th player %d -> scripted pos: %.0f, %.0f, %.0f",
					hero.plyID, spawnPos.x, spawnPos.y, spawnPos.z))
			else
				-- Use map spawn position as-is
				hero.spawn_pos = realPos
				hero.trackedPosition[1] = realPos
				print(string.format("[MAP_SPAWN] Player %d slot %d (team %d) map pos: %.0f, %.0f, %.0f",
					hero.plyID, teamSlotIndex, hero:GetTeam(), realPos.x, realPos.y, realPos.z))
			end
		end

		hero.trackedVelocity[1] = Vector(0,0,0)
	end)
	hero.plyID = hero:GetPlayerID()
	print('hmmm',hero.plyID)
	GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, hero, "modifier_hero_passive", {})

	-- Store the player's name inside this hero handle.
	hero.playerName = PlayerResource:GetPlayerName(hero.plyID)
	if hero.playerName == nil or hero.playerName == "" then
		hero.playerName = DummyNames[hero.plyID+1]
	end

	hero.teamGlow = ParticleManager:CreateParticle("particles/generic_gameplay/team_glow.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)
	hero.shadow = ParticleManager:CreateParticle("particles/generic_gameplay/shadow.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)
	
	SetupStats(hero)
	if hero:GetTeam() == DOTA_TEAM_GOODGUYS then
		-- Blue Team
		hero.gc = self.gcs[1]
		PlayerResource:SetCustomPlayerColor(hero.plyID, 63, 127, 255)
		ParticleManager:SetParticleControl(hero.teamGlow, 1, COLOR_ARR_BLUE[COLOR_INDEX_BASE])
		hero.colArr = COLOR_ARR_BLUE
		hero.colHex = COLOR_HEX_BLUE
		hero.colStr = "blue"
		hero.ballCol = COLOR_ARR_BLUE[COLOR_INDEX_BASE]
		--hero:SetCustomHealthLabel( hero.playerName, 255, 0, 0 )
	else
		-- Red Team
		hero.gc = self.gcs[2]
		PlayerResource:SetCustomPlayerColor(hero.plyID, 255, 0, 0)
		ParticleManager:SetParticleControl(hero.teamGlow, 1, COLOR_ARR_RED[COLOR_INDEX_BASE])
		hero.colArr = COLOR_ARR_RED
		hero.colHex = COLOR_HEX_RED
		hero.colStr = "red"
		hero.ballCol = COLOR_ARR_RED[COLOR_INDEX_BASE]
		--hero:SetCustomHealthLabel( hero.playerName, 0, 0, 255 )
	end
	-- Remove health bar

	-- mark the hero as a banjo hero.
	hero.isBanjoHero = true

	table.insert(self.vHeroes, hero)

	hero.pp_collisions = {} -- player-player collisions

	hero.colliderID = DoUniqueString("a")
	self.colliderFilter[hero.colliderID] = hero

	self:SetupPhysicsSettings(hero)

	hero.tauntItem = CreateItem("item_taunt", hero, hero)
	hero.frownItem = CreateItem("item_frown", hero, hero)
	hero.hfItem = CreateItem("item_hf", hero,hero)
	print('HANAME',hero:GetName())
	if hero:GetTeam() == DOTA_TEAM_CUSTOM_1 then
		hero.gem = CreateItem("item_gem", hero, hero)
		print(hero.gem)
		hero:AddItem(hero.gem)
		print(1)
	end

	for slot = 0, 15 do
        local item = hero:GetItemInSlot(slot);
        if ( item ) then 
            item:RemoveSelf();
        end
    end
	hero.fakeInjuryItem = CreateItem("item_fake_injury", hero, hero)
	hero:AddItem(hero.tauntItem)
	hero:AddItem(hero.frownItem)
	hero:AddItem(hero.fakeInjuryItem)
	hero:AddItem(hero.hfItem)
	hero:AddItem(hero.hfItem)
	hero:AddItem(hero.hfItem)

	-- this is for black holes.
	-- hero.last_bh_accels = {}

	-- for i=0,9 do
		-- hero.last_bh_accels[i] = Vector(0,0,0)
	-- end
	
	hero.assistSpell = true -- Whether or not a hero's spell affecting the ball counts as an assist or goal (false = goal)f
	
	hero.SprintBonus = SPRINT_MAXIMAL_BONUS
	hero.SprintTime = SPRINT_FAST_TIME

	hero.SprintLast = 0

	hero.fakeInjuryFreezeTimer = 0.00
	hero.collisionRadius = HERO_DEFAULT_RADIUS
	Banjoball:HideCastBar(hero)
	
	local sprintBreakName = "surge_break"
	local classname = hero:GetClassname()
	hero.BallCollRadius = BALL_COLLISION_DIST
	hero.BallHandledOffset = BALL_HANDLED_OFFSET
	if HERO_CUSTOM_BALL_COLLISION and HERO_CUSTOM_BALL_COLLISION[classname] then
		hero.BallCollRadius = HERO_CUSTOM_BALL_COLLISION[classname].ball_collision_dist or BALL_COLLISION_DIST
		hero.BallHandledOffset = HERO_CUSTOM_BALL_COLLISION[classname].ball_handled_offset or BALL_HANDLED_OFFSET
	end
	hero.originalBallCollRadius = hero.BallCollRadius
	hero.originalBallHandledOffset = hero.BallHandledOffset

	hero.kickPower = KICK_VELOCITY
	hero.kickZ = KICK_Z
	hero.Height = BALL_COLLISION_Z_TOP
	hero.originalHeight = hero.Height
	hero.manaMinus = false
	hero.manaReg = MANA_REG_SPRINT
	hero.manaDrain = MANA_DRAIN_SPRINT

	hero.size = HERO_DEFAULT_RADIUS
	hero.ballSlow = BALL_SLOW

	hero.sprintFinihsedAt = -10
	hero.password = true
	hero.SprintMult = 0

	if classname == "npc_dota_hero_antimage" then
		hero.isSprinter = true
		sprintBreakName = "super_sprint_break"
		hero.manaReg = MANA_REG_ANTI
		hero.manaDrain = MANA_DRAIN_ANTI
		hero.fakeInjuryFreezeTimer =  2.10
		hero.password = false
		hero.drainMult = 1
	elseif classname == "npc_dota_hero_slark" then
		hero.isNinja = true
		hero.fakeInjuryFreezeTimer = 1.45
		hero.pritaica = false
		AddHiddenAbility( hero, "ninja_invis_sprint_break" )
	elseif classname == "npc_dota_hero_invoker" then
		hero.isPowershot = true
	elseif classname == "npc_dota_hero_earthshaker" then
		hero.isSlam = true
		hero.assistSpell = false
		hero.fakeInjuryFreezeTimer = 1.80
	elseif classname == "npc_dota_hero_lina" then
		hero.isPull = true
		AddHiddenAbility( hero, "pull_break" )
	elseif classname == "npc_dota_hero_bloodseeker" then
		hero.isTackle = true
		hero.tackle_end_time = 0
		hero.fakeInjuryFreezeTimer = 1.40
		hero.tackleTargets = {}
	elseif classname == "npc_dota_hero_queenofpain" then
		hero.isBlink = true
		hero.fakeInjuryFreezeTimer = 1.40
		AddHiddenAbility( hero, "blink_backtrack" )
	elseif classname == "npc_dota_hero_enigma" then
		AddHiddenAbility( hero, "pugna_oblivion_savant" )
		AddHiddenAbility( hero, "black_hole_stop" )
	elseif classname == "npc_dota_hero_puck" then
		hero.isSwap = true
		AddHiddenAbility( hero, "swap_stop" ) 
	elseif classname == "npc_dota_hero_techies" then
		AddHiddenAbility( hero, "remote_mine_detonate" ) --remote_mine_detonate
	elseif classname == "npc_dota_hero_nevermore" then
		hero.speeding = SHADOWRAZE_SPEED_BUFF
		hero.manaReg = 0
		hero.manaDrain = 0
	elseif classname == "npc_dota_hero_night_stalker" then
		hero.isDemon = true
		sprintBreakName = "demonic_endurance_sprint_break"
		hero.SprintBonus = SPRINT_BONUS_DEMON
		hero.manaReg = MANA_REG_DEMON
		hero.manaDrain = MANA_DRAIN_DEMON
		hero.speeding = DEMON_CONST
		hero:AddNewModifier(hero,hero,"modifier_night_speed", {duration=99999})
		hero.sprinting = true
		hero.fakeInjuryFreezeTimer = 2.10
		hero.password = false
		hero.drainMult = 1
	elseif classname == "npc_dota_hero_pudge" then
		hero.isHook = true
		hero.fakeInjuryFreezeTimer = 1.80
		AddHiddenAbility( hero, "hook_retract" )
		AddHiddenAbility( hero, "hook_drop" )
	elseif classname == "npc_dota_hero_storm_spirit" then
		hero.isCurveshot = true
		sprintBreakName = "ball_lightning_break"
		hero.fakeInjuryFreezeTimer = 1.50
		hero.manaReg = MANA_REG_STORM
		hero.manaDrain = MANA_DRAIN_STORM
		hero.drainMult = 1
		hero.password = false
	elseif classname == "npc_dota_hero_ogre_magi" then
		hero.isOgre = true
		hero.assistSpell = false
		hero.fakeInjuryFreezeTimer = 1.60
	elseif classname == "npc_dota_hero_juggernaut" then
		hero.shouldStopOmnislash = false
		AddHiddenAbility( hero, "omnislash_stop" )
	elseif classname == "npc_dota_hero_weaver" then
		hero.isWeaver = true
		sprintBreakName = "shukuchi_sprint_break"
		hero.SprintBonus = SPRINT_BONUS_WEAVER
		hero.manaReg = MANA_REG_WEAVER
		hero.manaDrain = MANA_DRAIN_WEAVER
		hero.fakeInjuryFreezeTimer = 1.75
		hero.password = false
		hero.drainMult = 1
		hero.trackedParticle = ParticleManager:CreateParticleForTeam("particles/generic_gameplay/moveto_arrow.vpcf", PATTACH_ABSORIGIN, hero, hero:GetTeam())
		ParticleManager:SetParticleControl(hero.trackedParticle, 1, TIME_LAPSE_ARROW_COLOR)
	end

	if hero.password then hero:AddNewModifier(hero,hero,"modifier_newsprint", {duration=99999}) end

	AddHiddenAbility( hero, "cross_finish" )
	AddHiddenAbility( hero, "glyph" )
	hero.interruptTimer = 0
	hero.assistTimer = 0
	hero.spellAssistTimer = 0
	hero.collisionEnabled = true
	hero.lastPPCollisionTime = GameRules:GetGameTime()
	hero.skewerAffected = 0

	self:SetupPersonalColliders(hero)
	
	hero:SetHullRadius(HERO_HULL_SIZE)
	
	-- Add extra abilities
	hero.sprintBreak = sprintBreakName
	AddHiddenAbility( hero, sprintBreakName )
	
	Timers:CreateTimer(.04, function()
		if hero:GetPlayerOwner():GetAssignedHero() == nil then print("Hero still nil.") end
		InitAbilities(hero)
	end)

	-- if #self.vHeroes >= PlayerCount then
		-- AllPlayersSelectedHeroes = true
		-- print("AllPlayersSelectedHeroes")

	-- end

	-- Physics thinker
	hero:OnPhysicsFrame(function(unit)
		Banjoball:OnMyPhysicsFrame(hero)
	end)

	if not RoundInProgress then
		Timers:CreateTimer(FRAME_TIME, function()
			AddEndgameRoot(hero)
			AddSilence(hero)
		end)
	end
	
	-- Track time
	hero.trackedCounter = 0
	hero.trackedStart = 1
	hero.trackedEnd = 2
	hero.trackedEndSafe = 1
	hero.trackedPosition = {}
	hero.trackedVelocity = {}
	hero.trackedPosition[1] = hero:GetAbsOrigin()
	hero.trackedVelocity[1] = Vector(0,0,0)

	-- Apply WTF mode if enabled from start
	if _wtf_mode then
		hero:AddNewModifier(hero, nil, "modifier_unlimited_casting", {})
		hero:SetAbilityPoints(10)
	end
end

function Banjoball:SetupPhysicsSettings( unit )
	Physics:Unit(unit)
	unit:Hibernate(false)
	unit:SetNavCollisionType(PHYSICS_NAV_BOUNCE)
	unit:SetGroundBehavior(PHYSICS_GROUND_ABOVE)
	-- gravity
	unit:SetPhysicsAcceleration(GRAVITY)
	unit:SetPhysicsVelocityMax(MAX_VELOCITY)
	
	--unit:SetPhysicsBoundingRadius(unit:GetPaddedCollisionRadius()+20)
	unit.shieldParticles = {}
	unit.lastShieldParticleTime = GameRules:GetGameTime()

	unit:OnBounce(function(_unit, _normal)
		Banjoball:OnGridNavBounce( _unit, _normal )
	end)
	unit:OnPreBounce(function(_unit, _normal)
		Banjoball:OnPreGridNavBounce( _unit, _normal )
	end)

	-- ╨Ф╨╗╤П Primal Beast ╨┐╨╡╤А╨╡╨╛╨┐╤А╨╡╨┤╨╡╨╗╤П╨╡╨╝ ╨╝╨╡╤В╨╛╨┤╤Л ╨╕╨╖╨╝╨╡╨╜╨╡╨╜╨╕╤П ╤Б╨║╨╛╤А╨╛╤Б╤В╨╕, ╤З╤В╨╛╨▒╤Л ╨╖╨░╨▒╨╗╨╛╨║╨╕╤А╨╛╨▓╨░╤В╤М ╨▓╨╜╨╡╤И╨╜╨╕╨╡ ╤В╨╛╨╗╤З╨║╨╕
	if unit:GetUnitName() == "npc_dota_hero_primal_beast" then
		unit.BallCollRadius = 140 -- ╨г╨▓╨╡╨╗╨╕╤З╨╕╨▓╨░╨╡╨╝ ╤Д╨╕╨╖╨╕╤З╨╡╤Б╨║╨╕╨╣ ╤А╨░╨┤╨╕╤Г╤Б ╨╖╨░╤Е╨▓╨░╤В╨░ ╨╝╤П╤З╨░ ╨┤╨╛ ╤А╨░╨╖╨╝╨╡╤А╨░ ╨║╨╛╨╗╨╗╨╕╨╖╨╕╨╕

		local old_AddPhysicsVelocity = unit.AddPhysicsVelocity
		function unit:AddPhysicsVelocity(velocity)
			if unit:HasModifier("modifier_primal_beast_passive") and not unit.isUsingOnslaught and not unit.isUsingJump then
				-- ╨Я╨╛╨╗╨╜╨╛╤Б╤В╤М╤О ╨╕╨│╨╜╨╛╤А╨╕╤А╤Г╨╡╨╝ ╨▓╨╜╨╡╤И╨╜╨╡╨╡ ╤Г╤Б╨║╨╛╤А╨╡╨╜╨╕╨╡/╤В╨╛╨╗╤З╨║╨╕
				return
			end
			old_AddPhysicsVelocity(self, velocity)
		end

		local old_SetPhysicsVelocity = unit.SetPhysicsVelocity
		function unit:SetPhysicsVelocity(velocity)
			if unit:HasModifier("modifier_primal_beast_passive") and not unit.isUsingOnslaught and not unit.isUsingJump then
				-- ╨а╨░╨╖╤А╨╡╤И╨░╨╡╨╝ ╤В╨╛╨╗╤М╨║╨╛ ╤Б╨▒╤А╨╛╤Б ╤Б╨║╨╛╤А╨╛╤Б╤В╨╕ ╨┤╨╗╤П ╨╛╤Б╤В╨░╨╜╨╛╨▓╨║╨╕ ╨╕╨╜╨╡╤А╤Ж╨╕╨╕ ╤Е╨╛╨┤╤М╨▒╤Л
				if velocity:Length2D() > 0 then
					return
				end
			end
			old_SetPhysicsVelocity(self, velocity)
		end
	end
end
