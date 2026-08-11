function Banjoball:InitMap()
	local ball = Ball.unit

	self.bcs = {
		[1] = Physics:AddCollider("bounds_collider_1", Physics:ColliderFromProfile("aaboxreflect")),
		[2] = Physics:AddCollider("bounds_collider_2", Physics:ColliderFromProfile("aaboxreflect")),
		[3] = Physics:AddCollider("bounds_collider_3", Physics:ColliderFromProfile("aaboxreflect")),
	}
	local bcs = self.bcs

	-- the top of everything
	bcs[1].box = {Vector(BIG_OFFSET, BIG_OFFSET, BIG_OFFSET-3000), Vector(-1*BIG_OFFSET, -1*BIG_OFFSET, BIG_OFFSET+3000)}

	-- top of radiant goal post, ball reflector
	bcs[2].box = {Vector(-1*BIG_OFFSET, GOAL_Y*-1-BIG_OFFSET, GOAL_Z), Vector(R_SCORE+10, GOAL_Y+BIG_OFFSET, BIG_OFFSET)}
	--bcs[2].draw = true

	-- top of dire goal post, ball reflector
	bcs[3].box = {Vector(BIG_OFFSET, GOAL_Y*-1-BIG_OFFSET, GOAL_Z), Vector(D_SCORE-10, GOAL_Y+BIG_OFFSET, BIG_OFFSET)}
	--bcs[3].draw = true

	for i,bc in ipairs(bcs) do
		bc.test = function(self, unit)
			return OnBoundsCollision(self, unit, bc)
		end
		bc.filter = Banjoball.colliderFilter
	end

	Banjoball:AddGoalBox()
end

function OnBoundsCollision( self, unit, bc )
	if not IsPhysicsUnit(unit) then return false end

	local ball = Ball.unit

	local isBall = unit == ball

	local passTest = true

	local unitPos = unit:GetAbsOrigin()
	
	--print(bc.name)
	--print(VectorString(unitPos))

	-- top of radiant, top of dire goals
	if bc.name == "bounds_collider_2" or bc.name == "bounds_collider_3" then
		if unit.goalie then
			return false
		end
	end

	-- when someone is holding the ball
	if isBall and ball.controller then
		return false
	end

	-- done with passTest logic. move onto parsing that logic, add sounds, effects, etc.
	if passTest then
		if isBall and not ball.affectedByPowershot then
			unit:EmitSound("Bounce" .. RandomInt(1, NUM_BOUNCE_SOUNDS))
		elseif unit.isBanjoHero then
			TryPlayCracks(unit, nil, true)
		end
		if unit.isAboveGround then
			Banjoball:PlayReflectParticle(unit)
		end
	else

	end

	return passTest
end

function Banjoball:PlayReflectParticle( unit )
	local currTime = GameRules:GetGameTime()
	if not unit.lastShieldParticleTime or currTime-unit.lastShieldParticleTime > .03 then
		local pos = unit:GetAbsOrigin()
		local fv = unit:GetForwardVector()
		unit.shieldParticle = ParticleManager:CreateParticle("particles/units/heroes/hero_medusa/medusa_mana_shield_impact_highlight01.vpcf", PATTACH_CUSTOMORIGIN, unit)
		ParticleManager:SetParticleControl(unit.shieldParticle, 0, Vector(pos.x,pos.y,pos.z-70) + Vector(fv.x,fv.y,0)*40)
		unit.lastShieldParticleTime = currTime
	end
end

function PlayAnimation( name, unit )
    unit:AddAbility(name)
    local anim = unit:FindAbilityByName(name)
    anim:SetLevel(1)
    -- waiting a frame may be necessary, to prevent a crash, but feel free to try without the timer.
    Timers:CreateTimer(.03, function()
        unit:CastAbilityNoTarget(anim, 0)
        -- need to wait a frame here, i checked and some animations won't play if the abil is removed right away.
        Timers:CreateTimer(.03, function()
            unit:RemoveAbility(name)
        end)
    end)    
end

function Banjoball:InitCreeps(  )
	CreepSpecs = {[1] = "rs", [2] = "ds", [3] = "ns", [4] = "brew"}

	for i,spec_team in ipairs(CreepSpecs) do
		CreepSpecs[spec_team] = {}
		local spec_team_table = CreepSpecs[spec_team]
		local ptr = 1
		local t = Entities:FindAllByName(spec_team .. ptr .. "*")
		--ptr = ptr + 1
		while t and #t > 0 do
			spec_team_table[ptr] = {}
			for i2,ent in ipairs(t) do
				spec_team_table[ptr][i2] = ent
				--print("adding " .. ent:GetName() .. " to " .. spec_team .. " " .. ptr .. " " .. i2)
				InitCreepSpec(ent)
			end
			ptr = ptr + 1
			t = Entities:FindAllByName(spec_team .. ptr .. "*")
		end
	end
	--DeepPrintTable(CreepSpecs)
end

function InitCreepSpec( creep )
	if creep.GetUnitName then
		--print(creep:GetUnitName() .. " success")
		ClearAbilities( creep )
		GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, creep, "modifier_creep_spectator", {})
		AddDisarmed( creep )
		AddEndgameRoot(creep)
		creep.isCreepSpectator = true
		creep:SetAbsOrigin(GetGroundPosition(creep:GetAbsOrigin(), creep))

		if string.starts(creep:GetName(), "brew") then
			Timers:CreateTimer(RandomFloat(5, 20), function()
				local anim = "act_dota_spawn"
				--[[if RandomInt(1, 100) <= 25 then
					anim = "act_dota_cast_ability_1"
				end]]

				PlayAnimation(anim, creep)

				return RandomFloat(5, 20)
			end)
		end
	end
end

function SetupStats( hero )
	hero.goalsAgainst = 0
	hero.numAssists = 0
	-- Banjoball:GetInfo(hero:GetPlayerID(), {PlayerResource:GetSteamAccountID(hero:GetPlayerID()),"MMR"}, function(res) 
	-- hero.MMR = 0
	-- end)
	hero.numSaves = 0
	hero.numPasses = 0
	hero.pickups = 0
	hero.non_saves = 0
	hero.time_as_goalie = 0
	hero.passesReceived = 0
	hero.steals = 0
	hero.turnovers = 0
	hero.possession_time = 0
end

function Banjoball:InitScoreboard(  )
	--if ScoreboardTimer then return end

	Timers:CreateTimer(0.03, function()
		if GameRules:IsGamePaused() then
			return 0.03
		end
		_G.PhysicsGameTick = (_G.PhysicsGameTick or 0) + 1
		CustomNetTables:SetTableValue("player_physics_stats", "global", { tick = _G.PhysicsGameTick })
		local status, err = pcall(function()
			if Banjoball.vHeroes then
				for _, hero in pairs(Banjoball.vHeroes) do
					if hero and not hero:IsNull() and hero:IsRealHero() then
						local physSpeed = 0
						if hero.GetPhysicsVelocity and hero:GetPhysicsVelocity() then
							physSpeed = hero:GetPhysicsVelocity():Length()
						end
						local speed = physSpeed
						if hero.GetIdealSpeed then
							speed = math.max(physSpeed, hero:GetIdealSpeed())
						end

						local pos = hero:GetAbsOrigin()
						local mana = hero:GetMana()
						local max_mana = hero:GetMaxMana()

						local mana_regen = 0
						local is_borrow_time = hero:HasModifier("modifier_borrow_time")
						local can_regen = false
						if is_borrow_time then
							if mana < max_mana then
								can_regen = true
							end
						else
							if not hero.pritaica and not hero.surgeOn and mana < max_mana and not hero:HasModifier("modifier_mist_coil_debuff") then
								can_regen = true
							end
						end
						if can_regen then
							mana_regen = (hero.manaReg or 0) / (FRAME_TIME or 0.033)
						end

						local mana_drain = 0
						if hero.pritaica then
							mana_drain = (MANA_DRAIN_NINJA or 0) / (FRAME_TIME or 0.033)
						elseif hero.surgeOn then
							mana_drain = (hero.manaDrain or 0) * (hero.drainMult or 1) / (FRAME_TIME or 0.033)
						end

						local data = {
							speed = speed,
							mana = mana,
							max_mana = max_mana,
							mana_regen = mana_regen,
							mana_drain = mana_drain,
							pos_x = pos.x,
							pos_y = pos.y,
							pos_z = pos.z,
						}
						CustomNetTables:SetTableValue("player_physics_stats", tostring(hero:GetEntityIndex()), data)
					end
				end
			end

			local ball = Ball.unit
			if ball and not ball:IsNull() then
				local speed = 0
				if ball.GetPhysicsVelocity and ball:GetPhysicsVelocity() then
					speed = ball:GetPhysicsVelocity():Length()
				end
				local pos = ball:GetAbsOrigin()
				local data = {
					speed = speed,
					pos_x = pos.x,
					pos_y = pos.y,
					pos_z = pos.z,
				}
				CustomNetTables:SetTableValue("player_physics_stats", "ball", data)
			end
		end)
		if not status then
			print("[PHYSICS_TIMER_ERROR]", err)
		end
		if _G.TicksToPause and _G.TicksToPause > 0 then
			_G.TicksToPause = _G.TicksToPause - 1
			if _G.TicksToPause == 0 then
				PauseGame(true)
			end
		end
		return 0.03
	end)

	ScoreboardTimer = Timers:CreateTimer(.5, function()
		for _,hero in pairs(Banjoball.vHeroes) do
			local pID = hero:GetPlayerID()
			if pID ~= nil and pID ~= -1 then
				-- local ply = hero:GetPlayerOwner() or {["MMR"] = 1000}
				local playerInfo = (Banjoball.vFullinfo and Banjoball.vFullinfo[pID]) or {}
				local wins = playerInfo["WINS"] or 0
				local lose = playerInfo["LOSE"] or 0
				local totalGames = wins + lose
				local wr = "0%"
				if totalGames > 0 then
					wr = tostring(math.floor((wins / totalGames) * 100)) .. "%"
				end
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="goals", value=hero.goalsAgainst})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="assists", value=hero.numAssists})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="mmr", value=(playerInfo["MMR"] or 1000)})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="win", value=wins})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="lose", value=lose})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="wr", value=wr})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="steals", value=hero.steals})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="turnovers", value=hero.turnovers})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="pickups", value=hero.pickups})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="passes", value=hero.numPasses})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="passesReceived", value=hero.passesReceived})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="saves", value=hero.numSaves})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="nonSaves", value=hero.non_saves})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="possession", value=round(hero.possession_time,0)})
				CustomGameEventManager:Send_ServerToAllClients("updateStat", {player_ID=pID, key="goalie", value=round(hero.time_as_goalie,0)})
			end
		end
		
		CustomGameEventManager:Send_ServerToAllClients("updateScoreboard", {})
		
		return .5
	end)

end

function Banjoball:PrecacheTest()
	PrecacheResource("particle", "particles/econ/courier/courier_trail_international_2013_se/courier_international_2013_se.vpcf", PrecacheContext)
end

function Banjoball:AddGoalBox()
	local ball = Ball.unit

	self.gcs = {
		[1] = Physics:AddCollider("goal_collider_1", Physics:ColliderFromProfile("aaboxreflect")),
		[2] = Physics:AddCollider("goal_collider_2", Physics:ColliderFromProfile("aaboxreflect"))
	}

	local gcs = self.gcs

	gcs[1].box = {Vector(R_OUTWARDNESS, -1*GOAL_OUTER_Y, 0), Vector(-1*BIG_OFFSET, GOAL_OUTER_Y, BIG_OFFSET)}
	gcs[2].box = {Vector(D_OUTWARDNESS, -1*GOAL_OUTER_Y, 0), Vector(BIG_OFFSET, GOAL_OUTER_Y, BIG_OFFSET)}
	gcs[1].team = DOTA_TEAM_GOODGUYS
	gcs[2].team = DOTA_TEAM_BADGUYS
	-- gcs[1].draw=true
	-- gcs[2].draw=true

	for _,gc in ipairs(gcs) do
		gc.test = function ( self, unit )
			if not IsPhysicsUnit(unit) then return false end
			if unit.tempremoved then return false end
			if unit == gc.goalie then return false end -- ignore the current goalie in this goalpost.

			local passTest = false
			if unit ~= ball and gc.goalie then
				-- if the unit isn't the ball and there's a goalie in there, collision occurs.
				passTest = true
				
				-- If the hero is currently hooked, drop the hero.
				if unit.hookedBy ~= nil then
					unit.hookedBy.hookDummy:drop()
				end
			elseif unit == ball then
				passTest = false
			elseif unit.isBanjoHero and not gc.goalie and unit:GetTeamNumber() == gc.team then
				-- if there's nobody in the goal and the unit isn't the ball and he's on the same team as this goal post, then let the unit in.
				--print("new goalie")
				gc.goalie = unit
				unit.goalie = true
				unit.timeBecameGoalie = GameRules:GetGameTime()
				passTest = false
			else
				passTest = true
				
				-- If the hero is currently hooked, drop the hero.
				if unit.hookedBy ~= nil then
					unit.hookedBy.hookDummy:drop()
				end
			end

			-- Projectiles don't care if there's a goalie or not.
			if Banjoball:IsProjectile(unit) then
				passTest = false
			end

			-- done with calculating passTest value.
			if passTest then
				Banjoball:PlayReflectParticle(unit)
				-- if high velocity onto the goal post, do sounds/effects etc.
				if unit.isBanjoHero then
					TryPlayCracks(unit)
				end
			end

			return passTest
		end
		--gc.draw=true
		gc.filter = Banjoball.colliderFilter
	end
end