print('[BOT_THINK] ai/bot_think.lua loaded')

function Banjoball:InitializeBotHero(hero, team)
	if not hero or hero:IsNull() then return end
	
	-- ╨Ч╨░╤Й╨╕╤В╨░ ╨╛╤В ╨┐╨╛╨▓╤В╨╛╤А╨╜╨╛╨╣ ╨╕╨╜╨╕╤Ж╨╕╨░╨╗╨╕╨╖╨░╤Ж╨╕╨╕ ╨╛╨┤╨╜╨╛╨╣ ╨╕ ╤В╨╛╨╣ ╨╢╨╡ ╤Б╤Г╤Й╨╜╨╛╤Б╤В╨╕
	for _, h in ipairs(self.vHeroes) do
		if h == hero then
			print("[DEBUG_BOT] Hero already initialized, skipping duplicate init:", hero:GetUnitName())
			return
		end
	end

	print("[DEBUG_BOT] Initializing Bot Hero:", hero:GetUnitName(), "Team:", team)
	local ownerID = hero:GetPlayerOwnerID()
	if ownerID and ownerID ~= -1 then
		hero.plyID = ownerID
		PlayerResource:SetCustomTeamAssignment(ownerID, team)
	else
		if hero.SetPlayerID then
			hero:SetPlayerID(-1)
		end
		hero.plyID = -1
	end

	hero.isBanjoHero = true
	hero.playerName = "Bot " .. hero:GetUnitName():gsub("npc_dota_hero_", "")

	-- ╨Ф╨░╨╡╨╝ ╨┐╤А╨░╨▓╨░ ╤Г╨┐╤А╨░╨▓╨╗╨╡╨╜╨╕╤П ╨▓╤Б╨╡╨╝ ╤А╨╡╨░╨╗╤М╨╜╤Л╨╝ ╨╕╨│╤А╨╛╨║╨░╨╝ ╨╗╨╛╨▒╨▒╨╕ ╤Б ╨╖╨░╨┤╨╡╤А╨╢╨║╨╛╨╣, ╤З╤В╨╛╨▒╤Л ID ╨╕╨│╤А╨╛╨║╨╛╨▓ ╤Г╤Б╨┐╨╡╨╗╨╕ ╨┐╤А╨╕╨▓╤П╨╖╨░╤В╤М╤Б╤П ╨║ ╨│╨╡╤А╨╛╤О
	Timers:CreateTimer(0.8, function()
		if not hero or hero:IsNull() then return end
		local currentOwnerID = hero:GetPlayerOwnerID()
		print("[BOTS] Setting up unit sharing for bot:", hero:GetUnitName(), "OwnerID:", currentOwnerID)
		for pID = 0, DOTA_MAX_PLAYERS - 1 do
			if PlayerResource:IsValidPlayerID(pID) and not PlayerResource:IsFakeClient(pID) then
				hero:SetControllableByPlayer(pID, true)
				if currentOwnerID and currentOwnerID ~= -1 then
					PlayerResource:SetUnitShareMaskForPlayer(currentOwnerID, pID, 1, true)
					print(string.format("[BOTS] Share mask applied: Bot %d -> Real Player %d", currentOwnerID, pID))
				end
			end
		end
	end)

	hero:SetTeam(team)

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
			local new_pos = ClosestPointOnField(pos)
			hero:SetAbsOrigin(new_pos)
		end
		local collCheck = nil
		for i,v in pairs(GetUnitsInTrueRadius( pos, HERO_DEFAULT_RADIUS + 20 )) do
			if v~=hero then
				local is_spectre_collision = false
				if (hero.HasModifier and hero:HasModifier("modifier_spectre_passive")) or
				   (v.HasModifier and v:HasModifier("modifier_spectre_passive")) then
					is_spectre_collision = true
				end
				if not is_spectre_collision then
					collCheck = true
				end
			end
		end
		if collCheck then
			hero.StuckTicks = hero.StuckTicks + 1
			if hero.StuckTicks >= 3 then
				hero:SetPhysicsVelocity(Vector(0,0,0))
				hero:AddNewModifier(hero,nil,"modifier_unstuckmec", {duration=0.03}) 
				hero:RemoveModifierByName("modifier_rooted")
				hero:RemoveModifierByName("modifier_rooted_passive")
				
				local surge_break = hero:GetAbilityByIndex(2)
				local abilName = surge_break:GetAbilityName()
				if string.ends(abilName, "break") or hero.isInBallLightning then hero:CastAbilityNoTarget(surge_break, 0) end
			end
		else
			hero.StuckTicks = 0
		end
		
		if not hero.trackedStart then
			hero.trackedStart = 1
			hero.trackedEnd = 1
			hero.trackedEndSafe = 1
			hero.trackedPosition = {}
			hero.trackedVelocity = {}
		end

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
	end	

	hero.teamGlow = ParticleManager:CreateParticle("particles/generic_gameplay/team_glow.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)
	hero.shadow = ParticleManager:CreateParticle("particles/generic_gameplay/shadow.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)

	if team == DOTA_TEAM_GOODGUYS then
		hero.gc = self.gcs[1]
		ParticleManager:SetParticleControl(hero.teamGlow, 1, COLOR_ARR_BLUE[COLOR_INDEX_BASE])
		hero.colArr = COLOR_ARR_BLUE
		hero.colHex = COLOR_HEX_BLUE
		hero.colStr = "blue"
		hero.ballCol = COLOR_ARR_BLUE[COLOR_INDEX_BASE]
	else
		hero.gc = self.gcs[2]
		ParticleManager:SetParticleControl(hero.teamGlow, 1, COLOR_ARR_RED[COLOR_INDEX_BASE])
		hero.colArr = COLOR_ARR_RED
		hero.colHex = COLOR_HEX_RED
		hero.colStr = "red"
		hero.ballCol = COLOR_ARR_RED[COLOR_INDEX_BASE]
	end

	table.insert(self.vHeroes, hero)
	hero.pp_collisions = {}
	hero.colliderID = DoUniqueString("a")
	self.colliderFilter[hero.colliderID] = hero

	self:SetupPhysicsSettings(hero)

	hero.tauntItem = CreateItem("item_taunt", hero, hero)
	hero.frownItem = CreateItem("item_frown", hero, hero)
	hero.hfItem = CreateItem("item_hf", hero, hero)
	hero.fakeInjuryItem = CreateItem("item_fake_injury", hero, hero)

	for slot = 0, 15 do
		local item = hero:GetItemInSlot(slot)
		if item then item:RemoveSelf() end
	end

	hero:AddItem(hero.tauntItem)
	hero:AddItem(hero.frownItem)
	hero:AddItem(hero.fakeInjuryItem)
	hero:AddItem(hero.hfItem)
	hero:AddItem(hero.hfItem)
	hero:AddItem(hero.hfItem)

	hero.assistSpell = true
	hero.SprintBonus = SPRINT_MAXIMAL_BONUS
	hero.SprintTime = SPRINT_FAST_TIME
	hero.SprintLast = 0
	hero.fakeInjuryFreezeTimer = 0.00
	hero.collisionRadius = HERO_DEFAULT_RADIUS
	Banjoball:HideCastBar(hero)

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
		hero.sprintBreak = "super_sprint_break"
		hero.manaReg = MANA_REG_ANTI
		hero.manaDrain = MANA_DRAIN_ANTI
		hero.fakeInjuryFreezeTimer = 2.10
		hero.password = false
		hero.drainMult = 1
	elseif classname == "npc_dota_hero_slark" then
		hero.isNinja = true
		hero.fakeInjuryFreezeTimer = 1.45
		hero.pritaica = false
		AddHiddenAbility(hero, "ninja_invis_sprint_break")
	elseif classname == "npc_dota_hero_invoker" then
		hero.isPowershot = true
	elseif classname == "npc_dota_hero_earthshaker" then
		hero.isSlam = true
		hero.assistSpell = false
		hero.fakeInjuryFreezeTimer = 1.80
	elseif classname == "npc_dota_hero_lina" then
		hero.isPull = true
		AddHiddenAbility(hero, "pull_break")
	elseif classname == "npc_dota_hero_bloodseeker" then
		hero.isTackle = true
		hero.tackle_end_time = 0
		hero.fakeInjuryFreezeTimer = 1.40
		hero.tackleTargets = {}
	elseif classname == "npc_dota_hero_queenofpain" then
		hero.isBlink = true
		hero.fakeInjuryFreezeTimer = 1.40
		AddHiddenAbility(hero, "blink_backtrack")
	elseif classname == "npc_dota_hero_enigma" then
		AddHiddenAbility(hero, "pugna_oblivion_savant")
		AddHiddenAbility(hero, "black_hole_stop")
	elseif classname == "npc_dota_hero_puck" then
		hero.isSwap = true
		AddHiddenAbility(hero, "swap_stop")
	elseif classname == "npc_dota_hero_techies" then
		AddHiddenAbility(hero, "remote_mine_detonate")
	elseif classname == "npc_dota_hero_nevermore" then
		hero.speeding = SHADOWRAZE_SPEED_BUFF
		hero.manaReg = 0
		hero.manaDrain = 0
	elseif classname == "npc_dota_hero_night_stalker" then
		hero.isDemon = true
		hero.sprintBreak = "demonic_endurance_sprint_break"
		hero.SprintBonus = SPRINT_BONUS_DEMON
		hero.manaReg = MANA_REG_DEMON
		hero.manaDrain = MANA_DRAIN_DEMON
		hero.speeding = DEMON_CONST
		hero:AddNewModifier(hero, hero, "modifier_night_speed", {duration=99999})
		hero.sprinting = true
		hero.fakeInjuryFreezeTimer = 2.10
		hero.password = false
		hero.drainMult = 1
	elseif classname == "npc_dota_hero_pudge" then
		hero.isHook = true
		hero.fakeInjuryFreezeTimer = 1.80
		AddHiddenAbility(hero, "hook_retract")
		AddHiddenAbility(hero, "hook_drop")
	elseif classname == "npc_dota_hero_storm_spirit" then
		hero.isCurveshot = true
		hero.sprintBreak = "ball_lightning_break"
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
		AddHiddenAbility(hero, "omnislash_stop")
	elseif classname == "npc_dota_hero_weaver" then
		hero.isWeaver = true
		hero.sprintBreak = "shukuchi_sprint_break"
		hero.SprintBonus = SPRINT_BONUS_WEAVER
		hero.manaReg = MANA_REG_WEAVER
		hero.manaDrain = MANA_DRAIN_WEAVER
		hero.fakeInjuryFreezeTimer = 1.75
		hero.password = false
		hero.drainMult = 1
		hero.trackedParticle = ParticleManager:CreateParticleForTeam("particles/generic_gameplay/moveto_arrow.vpcf", PATTACH_ABSORIGIN, hero, hero:GetTeam())
		ParticleManager:SetParticleControl(hero.trackedParticle, 1, TIME_LAPSE_ARROW_COLOR)
	end

	if hero.password then hero:AddNewModifier(hero, hero, "modifier_newsprint", {duration=99999}) end

	AddHiddenAbility(hero, "cross_finish")
	AddHiddenAbility(hero, "glyph")
	hero.interruptTimer = 0
	hero.assistTimer = 0
	hero.spellAssistTimer = 0
	hero.collisionEnabled = true
	hero.lastPPCollisionTime = GameRules:GetGameTime()
	hero.skewerAffected = 0

	SetupStats(hero)
	self:SetupPersonalColliders(hero)
	hero:SetHullRadius(HERO_HULL_SIZE)

	if not hero.sprintBreak then
		hero.sprintBreak = "surge_break"
		AddHiddenAbility(hero, "surge_break")
	else
		AddHiddenAbility(hero, hero.sprintBreak)
	end

	Timers:CreateTimer(.04, function()
		InitAbilities(hero)
	end)

	Timers:CreateTimer(.1, function()
		if USE_SCRIPT_SPAWNS then
			Banjoball:AssignTeamSpawns(team)
		end
	end)

	hero:OnPhysicsFrame(function(unit)
		Banjoball:OnMyPhysicsFrame(hero)
	end)

	if _wtf_mode then
		hero:AddNewModifier(hero, nil, "modifier_unlimited_casting", {})
		hero:SetAbilityPoints(10)
	end

	if not RoundInProgress then
		Timers:CreateTimer(FRAME_TIME, function()
			AddEndgameRoot(hero)
			AddSilence(hero)
		end)
	end
	print(string.format("[DEBUG_BOT] Initialized %s successfully. Total Banjoball heroes: %d", hero:GetUnitName(), #self.vHeroes))
	CustomGameEventManager:Send_ServerToAllClients("update_hero_bar", {})
end
