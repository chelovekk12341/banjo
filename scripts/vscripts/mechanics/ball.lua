function Ball:Init(  )
	Ball.unit = CreateUnitByName("ball", Vector(0,0,0), true, nil, nil, DOTA_TEAM_NOTEAM)
	local ball = Ball.unit
	--table.insert(Banjoball.colliderFilter, ball)
	ball.colliderID = DoUniqueString("a")
	Banjoball.colliderFilter[ball.colliderID] = ball
	BALL = ball.unit
	ball.isBall = true
	ball.particleDummy = CreateUnitByName("dummy", Vector(0,0,GroundZ+BALL_PARTICLE_Z_OFFSET), false, nil, nil, DOTA_TEAM_NOTEAM)
	--ball.particleDummy = ball
	ball.lastBounceTime = 0
	ball.lastPos = Vector(0,0,GroundZ)
	ball.isRotating = false
	ball.lastMovedBy = Referee
	ball.refereeLastCalled = GameRules:GetGameTime()
	ball.invisTime = 0
	ball.exploitProc = false
	ball.curveshotSize = 0
	ball.isOutside = 0
	ball.trailColor = COLOR_ARR_WHITE[COLOR_INDEX_BASE]

	function ball:SpawnParticle(  )
		-- constantly reposition the ball particle dummy.
		ball.particleDummy:SetAbsOrigin(Vector(0,0,GroundZ+BALL_PARTICLE_Z_OFFSET))
		Timers:CreateTimer(0.06, function()
			if ball.ballParticle then
				ball.ballParticle = ParticleManager:DestroyParticle(ball.ballParticle, true)
			end
			if not ball.ballParticle then
				ball.ballParticle = ParticleManager:CreateParticle("particles/ball/ball.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
				ball.trailColor = COLOR_ARR_WHITE[COLOR_INDEX_BASE]
				ParticleManager:SetParticleControl(ball.ballParticle, 5, ball.trailColor)
			end
		end)
	end

	function ball:Rotate(  )
		if not ball.ballParticle then return end
		if (ball:GetAbsOrigin()-ball.lastPos):Length() > 1 then
			ParticleManager:SetParticleControl(ball.ballParticle, 11, Vector(0,0,-5000))
		else
			ParticleManager:SetParticleControl(ball.ballParticle, 11, Vector(0,0,0))
		end
	end
	
	ball.controller = nil
	Banjoball:SetupPhysicsSettings(ball)

	ball:OnPhysicsFrame(function(unit)
		-- don't perform velocity calculations on the ball if it has a controller.
		if ball.controller then
			ball:SetPhysicsVelocity(Vector(0,0,0))
		end

		Banjoball:OnMyPhysicsFrame(ball)
		Banjoball:OnBallPhysicsFrame(ball)
	end)
	return ball
end

function Banjoball:OnBallReceived( hero, ballVel )
	local ball = Ball.unit
	
	if hero.isUsingPull then Banjoball:BreakPull(hero) end
	
	if ball.pshotInvoke then
		Banjoball:PowerStop()
		hero:EmitSound("Hero_VengefulSpirit.MagicMissileImpact")
		hero:AddPhysicsVelocity(ballVel * 1.05)
	elseif ball.curveshot then
		hero:SetMana(hero:GetMana() + CURVESHOT_MANA_GAIN)
		if hero.password then hero.SprintMult = 1 end
		if ball.curveshotHero:GetTeam() == hero:GetTeam() then 
			ball.curveshotHero:SetMana(ball.curveshotHero:GetMana() + CURVESHOT_MANA_GAIN)
			if hero:GetPlayerID() ~= ball.curveshotHero:GetPlayerID() then
				if ball.curveshotHero:HasModifier("modifier_manareg") then
					ball.curveshotHero:RemoveModifierByName("modifier_manareg")
				end
				ball.curveshotHero:AddNewModifier(ball.curveshotHero,ball.curveshotHero,"modifier_manareg", {duration = MANA_BONUS_TIME})
			end
		else
			ball.curveshotHero:SetMana(ball.curveshotHero:GetMana() - CURVESHOT_MANA_GAIN)
			if ball.curveshotHero:HasModifier("modifier_manareg") then
				ball.curveshotHero:RemoveModifierByName("modifier_manareg")
			end
		end
		local curveshotManaParticle = ParticleManager:CreateParticle( "particles/econ/items/razor/razor_punctured_crest/razor_storm_lightning_strike_blade.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy )
		ParticleManager:SetParticleControl( curveshotManaParticle, 0, hero:GetAbsOrigin())
		ParticleManager:SetParticleControlEnt( curveshotManaParticle, 1, hero, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", hero:GetAbsOrigin(), true )
		hero:EmitSound("Hero_Warlock.ShadowWordCastGood")
		ball.curveshot = false
	end
end

function Banjoball:OnBallPhysicsFrame( ball )
	local ballPos = ball:GetAbsOrigin()
	local ballVel = ball:GetPhysicsVelocity()
	
	local speed = ballVel:Length()
	if speed >= BALL_HOT_THRESHOLD then
		if ball.hotParticleTimerName then
			Timers:RemoveTimer(ball.hotParticleTimerName)
			ball.hotParticleTimerName = nil
		end
		if not ball.hotParticle then
			local playerID = -1
			if ball.lastMovedBy and ball.lastMovedBy.GetPlayerOwnerID then
				playerID = ball.lastMovedBy:GetPlayerOwnerID()
			end
			local effectName = _G.Ball_PlayerChoices[playerID] or "ball_hot"
			local particlePath = GetBallEffectParticleByName(effectName)
			if particlePath and particlePath ~= "" then
				ball.hotParticle = ParticleManager:CreateParticle(particlePath, PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
			end
		end
	elseif speed < BALL_HOT_THRESHOLD and ball.hotParticle then
		if not ball.hotParticleTimerName then
			ball.hotParticleTimerName = Timers:CreateTimer(0.2, function()
				if ball.hotParticle then
					ParticleManager:DestroyParticle(ball.hotParticle, true)
					ParticleManager:ReleaseParticleIndex(ball.hotParticle)
					ball.hotParticle = nil
				end
				ball.hotParticleTimerName = nil
			end)
		end
	end
	
	-- If ball is resting, increase the collision distance
	local ballCollDist = BALL_COLLISION_DIST
	if ballVel:Length() == 0 and not ball.controller then
		ballCollDist = BALL_AT_REST_COLLISION_DIST
		if ball.ballParticle then
			ball.trailColor = COLOR_ARR_WHITE[COLOR_INDEX_BASE]
			ParticleManager:SetParticleControl(ball.ballParticle, 5, ball.trailColor)
		end
	end
	
	for _,hero in ipairs(Banjoball.vHeroes) do
		-- Collision test for the ball range
		local heroBallCollDist = hero.BallCollRadius - BALL_COLLISION_CHANGE

		local heroPos = hero:GetAbsOrigin()
		local ballCatchPos = heroPos + hero:GetForwardVector():Normalized()*BALL_COLLISION_CHANGE

		if hero.goalie or hero:HasModifier("modifier_force_normal_ball_collision") or ball.controller == nil then
			ballCatchPos = heroPos
			heroBallCollDist = hero.BallCollRadius
		end

		heroBallCollDist = heroBallCollDist * BALL_COLLISION_MULT

		local distXY = (Vector(ballCatchPos.x, ballCatchPos.y, 0) - Vector(ballPos.x, ballPos.y, 0)):Length()
		local distZ = ballPos.z - heroPos.z
		local collision = distXY <= heroBallCollDist and (distZ >= BALL_COLLISION_Z_BOT and distZ <= hero.Height)
		if ball.glyphed and not hero.goalie then collision = false end

		local ignore_glaive_collision = false
		if collision and ball.glaive_kick and ball.lastMovedBy and hero:GetTeam() ~= ball.lastMovedBy:GetTeam() and ball.glaive_pass_count and ball.glaive_pass_count > 0 and not hero.goalie then
			ball.glaive_pass_count = ball.glaive_pass_count - 1
			hero:EmitSound("Hero_Silencer.GlaivesOfWisdom.Damage")
			hero:AddNewModifier(hero, nil, "modifier_ball_catching_debuff", {duration=0.2})
			
			local impact_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_silencer/silencer_glaives_of_wisdom_explosion_flash.vpcf", PATTACH_WORLDORIGIN, nil)
			ParticleManager:SetParticleControl(impact_pfx, 0, hero:GetAbsOrigin())
			ParticleManager:SetParticleControl(impact_pfx, 3, hero:GetAbsOrigin())
			ParticleManager:ReleaseParticleIndex(impact_pfx)
			
			if ball.glaive_pass_count <= 0 then
				ball.glaive_kick = false
				if ball.glaive_particle then
					ParticleManager:DestroyParticle(ball.glaive_particle, true)
					ParticleManager:ReleaseParticleIndex(ball.glaive_particle)
					ball.glaive_particle = nil
				end
			end
			ignore_glaive_collision = true
		end

		if not ignore_glaive_collision and not hero.noball and not (ball.lastMovedBy == Referee and hero.goalie and GameRules:GetGameTime() - ball.refereeLastCalled <= REFEREE_GRACE_PERIOD) then
			if hero ~= ball.controller and collision and not (ball.controller and ball.controller:HasModifier("modifier_void_spirit_dissimilate_oow")) and not hero.isUsingOnslaught then
				-- Prevent kick-throughs by removing the flag from the hero.
				if hero:GetName() == "npc_dota_hero_antimage" and ball.controller == nil then
					Banjoball:ManaSteal(hero, ball.lastMovedBy)
				end
				if hero.ballProc and not ball.controller and hero ~= ball.lastMovedBy then 
					hero.ballProc = (heroPos-ballPos):Length() >= BALL_UNDER_PLAYER_DIST
				end

				if ball.hornToss == ball.lastMovedBy then
					return
				elseif ball.ricoshot and ball.riconum and ball.ricoshot ~= 0 and hero:GetTeam() ~= ball.lastMovedBy:GetTeam() then
					ball.riconum = ball.riconum + 1
					ball:SetPhysicsVelocity((heroPos - ballPos):Normalized() * KICK_VELOCITY * -1 * (1 + ball.riconum * RICOSHOT_BOUNCE_ADDVEL))
					ball:EmitSound("Kick" .. RandomInt(1, NUM_KICK_SOUNDS))
					if hero.goalie then
						ball.ricoshot = 0
						if ball.ricoshot_particle then
							ParticleManager:DestroyParticle(ball.ricoshot_particle, true)
							ball.ricoshot_particle = nil
						end
					else
						ball.ricoshot = math.min(ball.ricoshot + 1, RICOSHOT_DURATION)
					end
					-- ball.razNePidoraz = false
				elseif ballPos.z > ABOVE_GROUND_Z_CONST and heroPos.z > ABOVE_GROUND_Z_CONST and (not hero.goalie) and (ball.lastMovedBy:GetTeam() ~= hero:GetTeam()) and hero:GetName() ~= "npc_dota_hero_slark" then 
					-- Removing the capability of the hero to take the ball, so the ball can bounce through that hero. The capability is returned a couple of ticks later.
					hero:AddNewModifier(hero,nil,"modifier_ball_catching_debuff", {duration=0.1})
					-- Dispelling Invoker's powershot.
					if ball.affectedByPowershot then Banjoball:PowerStop() end
					-- Kicking the ball.
					ball:SetPhysicsVelocity(hero:GetForwardVector() * KICK_VELOCITY*KICK_AIR_MULT)
					ball:EmitSound("Kick" .. RandomInt(1, NUM_KICK_SOUNDS))
					Banjoball:RegisterBallHit(hero)
					ball.highestPosition = heroPos.z
					ball.trailColor = hero.ballCol
					if ball.ballParticle then ParticleManager:SetParticleControl(ball.ballParticle, 5, ball.trailColor) end
				else
					if not hero.ballProc then
						-- new controller
						ball:SetPhysicsVelocity(Vector(0,0,0))

						local is_spectre_steal = false
						if hero:GetName() == "npc_dota_hero_spectre" then
							if ball.controller and hero:GetTeam() ~= ball.controller:GetTeam() then
								is_spectre_steal = true
							elseif not ball.controller and ball.lastMovedBy and ball.lastMovedBy ~= Referee and hero:GetTeam() ~= ball.lastMovedBy:GetTeam() and ball.vm >= 300*300 then
								is_spectre_steal = true
							end
						end

						if not ball.affectedByPowershot and not is_spectre_steal then
							ball:EmitSound("Catch" .. RandomInt(1, NUM_CATCH_SOUNDS))
						end
						
						local saved = false
						-- determine if catch was a "SAVE!"
						--and hero:GetTeam() ~= ball.lastMovedBy:GetTeam()
						if hero.goalie and ( (ball.velocityMagnitude > 400*400 or ball.lastMovedBy == ball.controller) and hero:GetTeam() ~= ball.lastMovedBy:GetTeam() or ball.sundered) and hero:GetTeam() ~= ball.lastMovedBy:GetTeam() and ball.lastMovedBy ~= Referee and RoundInProgress then

							hero.savedParticle = ParticleManager:CreateParticle("particles/saved_txt/tusk_rubickpunch_txt.vpcf", PATTACH_ABSORIGIN_FOLLOW, hero)
							ParticleManager:SetParticleControlEnt(hero.savedParticle, 4, hero, 4, "follow_origin", hero:GetAbsOrigin(), true)
							--ParticleManager:SetParticleControl( hero.savedParticle, 2, hero:GetAbsOrigin() )
							EmitGlobalSound("Cheer" .. RandomInt(1, NumCheerSounds))
							hero.numSaves = hero.numSaves + 1
							saved = true
							ball.sundered = false
						end
						
						-- do some stats stuff
						if not ball.controller and not saved and RoundInProgress then
							-- determine if catch was a pass
							if ball.vm < 300*300 then
								hero.pickups = hero.pickups + 1
							else
								if hero:GetTeam() == ball.lastMovedBy:GetTeam() then
									if hero ~= ball.lastMovedBy then
										ball.lastMovedBy.numPasses = ball.lastMovedBy.numPasses + 1
										hero.passesReceived = hero.passesReceived + 1
									end
								else
									if ball.lastMovedBy ~= Referee and not hero.goalie then
										hero.steals = hero.steals + 1
										ball.lastMovedBy.turnovers = ball.lastMovedBy.turnovers + 1
										--EmitGlobalSound("Cheer" .. RandomInt(1, NumCheerSounds))
										Banjoball:text_particle( {caster=hero, stolen=true} )
										if hero:GetName() == "npc_dota_hero_spectre" then
											hero:EmitSound("Spectre.Desolate.Steal")
											hero.just_stolen_ball = true
										end
									end
								end
							end
						end
						
						if ball.controller then ball.controller:AddNewModifier(ball.controller,nil,"modifier_ball_catching_debuff", {duration = RESTEAL_REFRESH_TIME}) end
						BALL_COLLISION_MULT = 0
						Timers:CreateTimer(GLOBAL_RESTRICTION, function()
							BALL_COLLISION_MULT = 1
						end)

						if ball.exploitProc and not ball.exploitExpanded and ball.lastMovedBy == hero then 
							ball.exploitExpanded = true
							ball.timeBecameExploited = GameRules:GetGameTime() - BALL_EXPLOIT_DURATION + BALL_EXPLOIT_EXPAND_TIME
						end

						if ball.last_word_kick then
							ball.last_word_kick = false
							if ball.lastMovedBy and hero:GetTeam() ~= ball.lastMovedBy:GetTeam() and not hero.goalie then
								hero:AddNewModifier(hero, nil, "modifier_orchid_malevolence_debuff", {duration = 1.0})
								
								local locked_mana = hero:GetMana()
								local elapsed = 0
								Timers:CreateTimer(0.03, function()
									if not hero or hero:IsNull() or not hero:IsAlive() then return nil end
									
									local current_mana = hero:GetMana()
									if current_mana > locked_mana then
										hero:SetMana(locked_mana)
									else
										locked_mana = current_mana
									end
									
									elapsed = elapsed + 0.03
									if elapsed >= 1.0 then
										return nil
									end
									return 0.03
								end)
							end
							if ball.last_word_particle then
								ParticleManager:DestroyParticle(ball.last_word_particle, true)
								ParticleManager:ReleaseParticleIndex(ball.last_word_particle)
								ball.last_word_particle = nil
							end
						end

						if ball.glaive_particle then
							ParticleManager:DestroyParticle(ball.glaive_particle, true)
							ParticleManager:ReleaseParticleIndex(ball.glaive_particle)
							ball.glaive_particle = nil
						end
						ball.glaive_kick = false

						ball.controller = hero
						Banjoball:RegisterBallHit(hero)
						SwapAbilities( hero, "glyph", "jump", ABILITY_SLOT_F )
						ball:SetPhysicsAcceleration(GRAVITY)
						if ball.affectedByPowershot then
							-- allow the hero collider to take control and apply collision velocity, by invoking it
							ball.pshotInvoke = true

							ball.affectedByPowershot = false
						end
						hero.ballProc = true
					end
				end
			elseif hero ~= ball.controller and not collision then
				-- Deflag the hero once they leave a distance from the ball.
				if hero.ballProc then
					hero.ballProc = (hero:GetAbsOrigin()-ballPos):Length() <= BALL_DEFLAG_DIST
				end
			elseif hero == ball.controller then
				local fv = hero:GetForwardVector()
				-- reposition ball to in front of controller.
				local handled_offset = hero.BallHandledOffset or BALL_HANDLED_OFFSET
				ball:SetAbsOrigin(hero:GetAbsOrigin() + Vector(fv.x,fv.y,0)*handled_offset)
			end
			
			-- reset the movespeed if this guy isn't the ball handler anymore.
			if ball.controller ~= hero and hero:HasModifier("modifier_ball_controller") then
				if hero:HasModifier("modifier_mod_ball_slow") then
					hero:RemoveModifierByName("modifier_mod_ball_slow")
				end
				hero:RemoveModifierByName("modifier_ball_controller")
				SwapAbilities( hero, "jump", "glyph", ABILITY_SLOT_F )
				if hero.obtainTime + ASSIST_GRACE_PERIOD < GameRules:GetGameTime() then
					hero.interruptTimer = GameRules:GetGameTime()
				end
				hero.assistTimer = GameRules:GetGameTime()
				
				--Check if the ball controller is an enemy -> add steals
				if ball.controller and hero:GetTeam() ~= ball.controller:GetTeam() then
					hero.turnovers = hero.turnovers + 1
					ball.controller.steals = ball.controller.steals + 1
					if not hero.goalie then Banjoball:text_particle( {caster=ball.controller, stolen=true} ) end
					if ball.controller:GetName() == "npc_dota_hero_antimage" then
						Banjoball:ManaSteal(ball.controller, hero, 1)
						-- manadrainamount = hero:GetMana() * 0.60
						-- hero:SetMana(hero:GetMana() - manadrainamount)--:SetMana(hero:GetMana() + (ball.controller:GetMana() * 0.60))
						-- ball.controller:SetMana(ball.controller:GetMana() + manadrainamount)--:SetMana(ball.controller:GetMana() * 0.40)
						-- local curveshotManaParticle = ParticleManager:CreateParticle( "particles/econ/items/razor/razor_punctured_crest/razor_storm_lightning_strike_blade.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy )
						-- ParticleManager:SetParticleControl( curveshotManaParticle, 0, hero:GetAbsOrigin())
						-- ParticleManager:SetParticleControlEnt( curveshotManaParticle, 1, hero, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", hero:GetAbsOrigin(), true )
						-- hero:EmitSound("Hero_Warlock.ShadowWordCastGood")
					elseif ball.controller:GetName() == "npc_dota_hero_spectre" then
						local ability = ball.controller:FindAbilityByName("spectre_passive")
						local mana_restore = ability and ability:GetSpecialValueFor("mana_restore") or 50
						ball.controller:GiveMana(mana_restore)
						ball.controller:EmitSound("Spectre.Desolate.Steal")
						ball.controller.just_stolen_ball = true
					end
				end
			end
		end
	end

	if ball.controller then
		-- it's nice to update this
		ballPos = ball:GetAbsOrigin()
		ball.trailColor = COLOR_ARR_WHITE[COLOR_INDEX_BASE]
		if ball.controller.ballCol then
			ball.trailColor = ball.controller.ballCol
		end
		
		if ball.ballParticle then
			ParticleManager:SetParticleControl(ball.ballParticle, 5, ball.trailColor)
		end

		if ball.lastController ~= ball.controller then
			--print("new ball.lastController")
			ball.lastController = ball.controller
		end
		
		-- slow the movespeed of the controller if we haven't already.
		local controller = ball.controller
		if not controller:HasModifier("modifier_ball_controller") then
			Banjoball:OnBallReceived( controller, ballVel )
			if not controller:HasModifier("modifier_goalspeed") then
				controller:AddNewModifier(controller,nil,"modifier_mod_ball_slow", {duration = 99999})
			end
			GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, controller, "modifier_ball_controller", {})
			controller.obtainTime = GameRules:GetGameTime()

			-- Spectre passive rush on ball capture
			if controller:HasModifier("modifier_spectre_passive") then
				local ability = controller:FindAbilityByName("spectre_passive")
				if ability and ability:GetToggleState() then
					if controller.just_stolen_ball then
						controller.just_stolen_ball = nil
					else
						controller:EmitSound("Hero_Spectre.Reality")
					end
					local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_spectre/spectre_shadow_path.vpcf", PATTACH_ABSORIGIN_FOLLOW, controller)
					
					controller.collisionEnabled = false
					
					local fv = controller:GetForwardVector()
					fv.z = 0
					fv = fv:Normalized()
					
					local dash_range = ability:GetSpecialValueFor("dash_range")
					if dash_range <= 0 then dash_range = 200 end

					local total_ticks = 5
					local dist_per_tick = dash_range / total_ticks
					local tick_count = 0
					
					Timers:CreateTimer(function()
						if not controller or controller:IsNull() or not controller:IsAlive() then
							ParticleManager:DestroyParticle(pfx, false)
							ParticleManager:ReleaseParticleIndex(pfx)
							return nil
						end
						
						if ball.controller ~= controller then
							controller.collisionEnabled = true
							ParticleManager:DestroyParticle(pfx, false)
							ParticleManager:ReleaseParticleIndex(pfx)
							return nil
						end
						
						local current_pos = controller:GetAbsOrigin()
						local target_pos = current_pos + fv * dist_per_tick
						
						if IsPointOnField(target_pos) then
							local enemyTeam = GetHeroEnemy(controller)
							if GetGoalPointIsWithin(target_pos) ~= enemyTeam then
								controller:SetAbsOrigin(target_pos)
							end
						end
						
						tick_count = tick_count + 1
						if tick_count >= total_ticks then
							controller.collisionEnabled = true
							ParticleManager:DestroyParticle(pfx, false)
							ParticleManager:ReleaseParticleIndex(pfx)
							return nil
						end
						
						return 0.03
					end)
				end
			end
		end
		
		if ball.lastMovedBy == Referee then
			ball.lastMovedBy = ball.controller
		end
		
		if ball.controller.isCurveshot then
			-- Break Ball Lightning
			local wasInBallLightning = ball.controller.isInBallLightning
			Banjoball:BallLightningBreak(ball.controller)
		end
		
	else
		ballPos = ball:GetAbsOrigin()
		
		-- Layered for proper else statement executions
		if RoundInProgress and ballPos.z < GOAL_Z then
			local gteam = GetGoalPointIsWithinGoalZone(ballPos)
			-- if ballPos.x < R_SCORE then
			if gteam == DOTA_TEAM_GOODGUYS then
				if not ball.kickedFromRadiantGoal then
					Banjoball:OnGoal("Dire")
				end
			-- elseif ballPos.x > D_SCORE then
			elseif gteam == DOTA_TEAM_BADGUYS then
				if not ball.kickedFromDireGoal then
					Banjoball:OnGoal("Radiant")
				end
			else
				ball.kickedFromRadiantGoal = false
				ball.kickedFromDireGoal = false
			end
		end
	end

	-- move the ball particle dummy, so ball particle displays above ground.
	ball.particleDummy:SetAbsOrigin(Vector(ballPos.x, ballPos.y, ballPos.z+BALL_PARTICLE_Z_OFFSET))
	if ball.invisTime > 0 and not ball.controller then
		if ball.ballParticle then
			ball.ballParticle = ParticleManager:DestroyParticle(ball.ballParticle, true)
		end
		ball.invisTime = ball.invisTime - 0.03
	elseif not ball.ballParticle and not ball.dissimilate_hidden then
		ball.ballParticle = ParticleManager:CreateParticle("particles/ball/ball.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
		ParticleManager:SetParticleControl(ball.ballParticle, 5, ball.trailColor or COLOR_ARR_WHITE[COLOR_INDEX_BASE])
		ball.invisTime = 0
	end

	-- Preventing the ball to be held inside a goal area for too long.
	local ballInside = GetGoalUnitIsWithin(ball) and ball.vVelocity:Length() < 100
	local goalieInside = ball.controller and ball.controller.goalie and GetGoalUnitIsWithin(ball.controller)
	ball.held = ( (ballInside and not ball.controller) or goalieInside ) and RoundInProgress

	-- Initialize accumulated time if nil
	if not ball.hogAccumulatedTimeByGoal then
		ball.hogAccumulatedTimeByGoal = {
			[DOTA_TEAM_GOODGUYS] = 0,
			[DOTA_TEAM_BADGUYS] = 0
		}
	end
	if not ball.hogAccumulatedTime then
		ball.hogAccumulatedTime = 0
	end

	-- Timer entrance
	if (ball.held or ball.hogAccumulatedTime > 0) and not ball.holding_timer then
		ball.holding_timer = true
		ball.lastHogThinkTime = GameRules:GetGameTime()

		-- Show progress bar: over goalie if they hold the ball, otherwise over the ball
		local hogTimerUnit = (ball.controller and ball.controller.goalie) and ball.controller or ball.particleDummy
		ball.hogTimerUnit = hogTimerUnit

		-- Send Panorama timer events with millisecond precision
		Timers:CreateTimer(function()
			if not ball.holding_timer then
				CustomGameEventManager:Send_ServerToAllClients("ballHogTimer", {
					active   = 0,
					timeLeft = 0,
					duration = BALL_HOG_DURATION,
					entIndex = -1,
				})
				return
			end
			local timeLeft = math.max(0, BALL_HOG_DURATION - ball.hogAccumulatedTime)
			local unit = (ball.controller and ball.controller.goalie) and ball.controller or ball.particleDummy
			CustomGameEventManager:Send_ServerToAllClients("ballHogTimer", {
				active   = ball.held and 1 or 0,
				timeLeft = timeLeft,
				duration = BALL_HOG_DURATION,
				entIndex = unit:GetEntityIndex(),
			})
			return 0.01
		end)

		--print("timer started")
		Timers:CreateTimer(function()
			-- If the round ended or we shouldn't be running, stop.
			if not RoundInProgress then
				ball.holding_timer = false
				alarmed = false
				ball.holder = nil
				ball.hogAccumulatedTime = 0
				ball.hogAccumulatedTimeByGoal[DOTA_TEAM_GOODGUYS] = 0
				ball.hogAccumulatedTimeByGoal[DOTA_TEAM_BADGUYS] = 0
				if ball.hogTimerUnit then
					Banjoball:DestroyCountdownTimer(ball.hogTimerUnit)
					ball.hogTimerUnit = nil
				end
				return nil
			end

			-- Calculate time delta
			local now = GameRules:GetGameTime()
			local dt = now - ball.lastHogThinkTime
			ball.lastHogThinkTime = now

			-- ╨Ю╨┐╤А╨╡╨┤╨╡╨╗╤П╨╡╨╝, ╨▓ ╨║╨░╨║╨╕╤Е ╨▓╨╛╤А╨╛╤В╨░╤Е ╨╜╨░╤Е╨╛╨┤╨╕╤В╤Б╤П ╨╝╤П╤З/╨▓╤А╨░╤В╨░╤А╤М ╤Б╨╡╨╣╤З╨░╤Б
			local activeGoal = false
			if ball.held then
				if ball.controller then
					activeGoal = GetGoalUnitIsWithin(ball.controller)
				else
					activeGoal = GetGoalUnitIsWithin(ball)
				end
			end

			-- ╨Х╤Б╨╗╨╕ ╨▓╤А╨░╨╢╨╡╤Б╨║╨╕╨╣ ╨┐╨╛ ╨╛╤В╨╜╨╛╤И╨╡╨╜╨╕╤О ╨║ ╨▓╨╛╤А╨╛╤В╨░╨╝ ╨╕╨│╤А╨╛╨║ ╨║╨╛╨╜╤В╤А╨╛╨╗╨╕╤А╤Г╨╡╤В ╨╝╤П╤З, ╨╝╨│╨╜╨╛╨▓╨╡╨╜╨╜╨╛ ╤Б╨▒╤А╨░╤Б╤Л╨▓╨░╨╡╨╝ ╤В╨░╨╣╨╝╨╡╤А ╤Н╤В╨╕╤Е ╨▓╨╛╤А╨╛╤В ╨▓ 0
			if ball.controller then
				local controllerTeam = ball.controller:GetTeamNumber()
				for team, time in pairs(ball.hogAccumulatedTimeByGoal) do
					if time > 0 and controllerTeam ~= team then
						ball.hogAccumulatedTimeByGoal[team] = 0
					end
				end
			end

			-- ╨Ю╨▒╨╜╨╛╨▓╨╗╤П╨╡╨╝ ╨╜╨░╨║╨╛╨┐╨╗╨╡╨╜╨╜╨╛╨╡ ╨▓╤А╨╡╨╝╤П ╨┤╨╗╤П ╨║╨░╨╢╨┤╤Л╤Е ╨▓╨╛╤А╨╛╤В ╨╛╤В╨┤╨╡╨╗╤М╨╜╨╛
			for team, time in pairs(ball.hogAccumulatedTimeByGoal) do
				if activeGoal == team then
					ball.hogAccumulatedTimeByGoal[team] = math.min(BALL_HOG_DURATION, time + dt)
				else
					ball.hogAccumulatedTimeByGoal[team] = math.max(0, time - 0.8 * dt)
				end
			end

			-- ╨Ф╨╗╤П ╨╛╤В╨╛╨▒╤А╨░╨╢╨╡╨╜╨╕╤П ╨┐╤А╨╛╨│╤А╨╡╤Б╤Б-╨▒╨░╤А╨░ ╨▒╨╡╤А╨╡╨╝ ╨▓╤А╨╡╨╝╤П ╨▓╨╛╤А╨╛╤В, ╨│╨┤╨╡ ╨▒╨╛╨╗╤М╤И╨╡ ╨╜╨░╨║╨╛╨┐╨╗╨╡╨╜╨╛
			local displayGoal = activeGoal
			if not displayGoal then
				if ball.hogAccumulatedTimeByGoal[DOTA_TEAM_GOODGUYS] > ball.hogAccumulatedTimeByGoal[DOTA_TEAM_BADGUYS] then
					displayGoal = DOTA_TEAM_GOODGUYS
				else
					displayGoal = DOTA_TEAM_BADGUYS
				end
			end

			ball.hogAccumulatedTime = ball.hogAccumulatedTimeByGoal[displayGoal]

			-- Spotting a holder (must be a goalie).
			if not ball.holder then
				if ball.controller and ball.controller.goalie then 
					ball.holder = ball.controller 
				end
			end

			-- Notifying about the timer.
			if ball.hogAccumulatedTime >= BALL_HOG_DURATION/2 then
				if not alarmed then
					if ball.controller then Banjoball:text_particle( {caster=ball.controller, exclamation=true} )
					else Banjoball:text_particle( {caster=ball, exclamation=true} ) end
					alarmed = true
				end
			else
				if ball.hogAccumulatedTime < BALL_HOG_DURATION/2 then
					alarmed = false
				end
			end

			-- Check if timer is exceeded and ball is held (Roshan screams and referee gets ball)
			if ball.hogAccumulatedTime >= BALL_HOG_DURATION then
				if ball.vVelocity:Length() <= 10 then
					if RandomInt(1, 2) == 1 then EmitGlobalSound("RoshanDT.Scream")
					else EmitGlobalSound("RoshanDT.Scream2") end
					
					if ball.controller and ball.controller.goalie then ball.controller:AddNewModifier(ball.controller,nil,"modifier_ball_catching_debuff", {duration=1}) end
					Banjoball:GetBallInBounds()
	
					ball.holding_timer = false
					alarmed = false
					ball.holder = nil
					ball.hogAccumulatedTime = 0
					ball.hogAccumulatedTimeByGoal[DOTA_TEAM_GOODGUYS] = 0
					ball.hogAccumulatedTimeByGoal[DOTA_TEAM_BADGUYS] = 0
					if ball.hogTimerUnit then
						Banjoball:DestroyCountdownTimer(ball.hogTimerUnit)
						ball.hogTimerUnit = nil
					end
					return nil
				end
			end

			-- If the accumulated time has fully recovered to 0 in both goals and we are not held anymore, end the timer.
			if ball.hogAccumulatedTimeByGoal[DOTA_TEAM_GOODGUYS] <= 0 and ball.hogAccumulatedTimeByGoal[DOTA_TEAM_BADGUYS] <= 0 and not ball.held then
				ball.holding_timer = false
				alarmed = false
				ball.holder = nil
				ball.hogAccumulatedTime = 0
				ball.hogAccumulatedTimeByGoal[DOTA_TEAM_GOODGUYS] = 0
				ball.hogAccumulatedTimeByGoal[DOTA_TEAM_BADGUYS] = 0
				if ball.hogTimerUnit then
					Banjoball:DestroyCountdownTimer(ball.hogTimerUnit)
					ball.hogTimerUnit = nil
				end
				return nil
			end

			-- If any of the requirements aren't met, go for a new iteration.
			return 0.03
		end)
	end

	if ball.controller then
		if GetHeroEnemy(ball.controller) == HoggCheck(ball.controller) then
			if not ball.exploitProc or ball.lastMovedBy ~= ball.controller then
				ball.lastMovedBy = ball.controller
				ball.timeBecameExploited = GameRules:GetGameTime()
				ball.exploitProc = true
				Banjoball:text_particle( {caster=ball, exclamation=true} )
			elseif GameRules:GetGameTime()-ball.timeBecameExploited >= BALL_EXPLOIT_DURATION then
				local xxx = 2450
				if ball:GetAbsOrigin().x < 0 then xxx = -2450 end
				if ball.controller then ball.controller:AddNewModifier(ball.controller,nil,"modifier_ball_catching_debuff", {duration=1}) end
				ball.controller = nil
				ball:SetPhysicsVelocity( ( Vector(xxx, 0, 0) - ball:GetAbsOrigin() ):Normalized() * 750 )
				ball.exploitProc = false
				ball.exploitExpanded = false
			--elseif GameRules:GetGameTime()-ball.timeBecameExploited <= 1 then print(GameRules:GetGameTime()-ball.timeBecameExploited) 
			end
		elseif not ballInside or (ball.controller and ball.controller.goalie) then 
			ball.exploitProc = false
			ball.exploitExpanded = false
		 end
	end
	local newFV = (ballPos - ball.lastPos):Normalized()
	ball.particleDummy:SetForwardVector(newFV)
	
	if not ball.controller and not IsPointOnField(ballPos) then
		if ball.isOutside >= 20 then
			ball:SetAbsOrigin( ClosestPointOnField(ballPos) ) 
			ball.isOutside = 0
		else
			ball.isOutside = ball.isOutside + 1
		end
	end

	-- rotate the ball depending if it's not moving or what
	ball:Rotate()



	ball.lastPos = ballPos
end

function Banjoball:GetBallInBounds(  )
	local ball = Ball.unit
	local towardsCenter = (Vector(0,0,GroundZ)-ball:GetAbsOrigin()):Normalized()
	local backOfBall = -300*towardsCenter + ball:GetAbsOrigin()
	Referee.Active = true
	ball.lastMovedBy = Referee
	RemoveEndgameRoot(Referee)
	RemoveDisarmed(Referee)

	Referee:SetAbsOrigin(backOfBall)

	Referee:SetForwardVector((ball:GetAbsOrigin()-backOfBall):Normalized())

	Referee:MoveToTargetToAttack(ball)
	
	ball.refereeLastCalled = GameRules:GetGameTime()

	ball.controller = nil
	ball:SetPhysicsVelocity(Vector(0,0,0))
	Referee.Active = false
end

function Banjoball:GetBallInTrueBounds(  )
	local ball = Ball.unit
	ball:SetAbsOrigin(ClosestPointOnField(ball:GetAbsOrigin()))
end
