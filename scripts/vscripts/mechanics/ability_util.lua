--[[
	CreateCountdownTimer
	Creates a countdown particle over the head of the specified unit.
	player = Player that the countdown is visible to
	unit = Unit with particle overhead
	path = Path of the particle effect
	countdownTime = Total time the countdown will occur for
	predicate() = Predicate function checking if countdown is still 
		needed (for example, to check if the spell it's being used for
		is still active). Returns true or false depending on whether 
		to keep it active.
		
]]--
function Banjoball:CreateCountdownTimer(  unit, path, countdownTime, predicate, team, head, tickInterval )
	-- Display the time counter particle for the player
	local secondsCount = countdownTime
	local tick = tickInterval or 0.25
	if team then
		unit.counterParticle = ParticleManager:CreateParticleForTeam(path, PATTACH_OVERHEAD_FOLLOW, unit, team)
	else
		unit.counterParticle = ParticleManager:CreateParticle(path, PATTACH_OVERHEAD_FOLLOW, unit)
	end
	ParticleManager:SetParticleControl(unit.counterParticle, 1, Vector(0,secondsCount,0))
	--ParticleManager:SetParticleControl(unit.counterParticle, 0, Vector(0,0,400))
	local followby = head and PATTACH_OVERHEAD_FOLLOW or PATTACH_POINT_FOLLOW
	print(followby)
	ParticleManager:SetParticleControlEnt(unit.counterParticle, 2, unit, followby, nil, unit:GetAbsOrigin(), true)
	
	Timers:CreateTimer(tick, function()
		secondsCount = secondsCount - tick
		
		--Banjoball:DestroyCountdownTimer(unit)
		print('pomp', unit, secondsCount, followby, unit.counterParticle)
		-- Break if the countdown is complete or if the predicate is false
		if not predicate() or secondsCount <= 0 then 
			Banjoball:DestroyCountdownTimer(unit)
			return 
		end
		
		--unit.counterParticle = ParticleManager:CreateParticleForPlayer(path, PATTACH_OVERHEAD_FOLLOW, unit, player)
		if unit and unit.counterParticle then
			ParticleManager:SetParticleControl(unit.counterParticle, 1, Vector(0,secondsCount,0))
		else
			return
		end
		return tick
	end)
end

--[[
	DestroyCountdownTimer
		Destroys the countdown particle effect
		unit = Unit that has the particle overhead
]]--
function Banjoball:DestroyCountdownTimer( unit )
	if unit.counterParticle then
		ParticleManager:DestroyParticle(unit.counterParticle, true)
		unit.counterParticle = nil
	end
end

--[[
	Banjoball:SlamNearby
	Slam function so that any slam-like spells don't need to be copy pasted.
	Returns the number of entities affected by slam.
		hero = Unit casting slamlike
		location = Origin of the slam (hero:GetAbsOrigin(), most likely)
		radius = Radius of the slam
		slam_xy = Horizontal slam force
		slam_z = Vertical slam force
	
	Additionally, a function is called to obtain the knockback velocity and 
	additional effects. Returns the knockback of the slamlike ability.
	getKnockback( hero, entity, direction, slam_xy, slam_z)
		hero = Unit casting slamlike
		entity = Entity being slammed
		direction = Direction of the slam
		slam_xy = Horizontal slam force
		slam_z = Vertical slam force
]]--
function Banjoball:SlamNearby( hero, location, radius, slam_xy, slam_z, noHeroRadius, getKnockback)
	local ball = Ball.unit
	local affected = 0
	local direction = 0
	for i, entity in ipairs(GetUnitsInTrueRadius(location, radius)) do
		if IsPhysicsUnit(entity) and (entity.isBanjoHero or entity.isBall or Banjoball:IsProjectile(entity)) then
			direction = (entity:GetAbsOrigin()-location):Normalized()
			if noHeroRadius and not (#GetUnitsInTrueRadius(location, noHeroRadius) > 1) then
				direction = -direction
			end
			local dist = (entity:GetAbsOrigin()-location):Length()
			if hero then
				local hero = hero
				if Banjoball:IsProjectile(hero) then
					hero = hero.hero
				end
				if entity == ball or entity == ball.controller then
					-- Gives the hero the score marker or an assist
					hero.spellAssistTimer = GameRules:GetGameTime()
				end
			end
			
			local tempSlamXY = slam_xy
			local tempSlamZ = slam_z
			local knockback = Vector(0,0,0)
			if getKnockback then
				knockback = getKnockback(hero, entity, direction, tempSlamXY, tempSlamZ)
			elseif not (entity == ball and ball.controller) and entity ~= hero then
				-- If it's the ball and ball has a controller, don't move the ball.
				-- If it's the slammer, don't move him
				knockback = direction*slam_xy + Vector(0,0,slam_z)
			end
			
			entity:AddPhysicsVelocity(knockback)
			if knockback ~= Vector(0,0,0) then
				entity.noBounce = false
				affected = affected + 1
			end
		end
	end
	
	return affected
end

-- Takes a unit and breaks any cast-necessary channelling spells they're using. 
-- Use this before silencing anyone.
function SafeBreakChannels( hero, friendly )
	local ball = Ball.unit
	
	-- Hero specific channels
	if hero.isSprinter then
	elseif hero.isNinja then
	elseif hero.isPowershot then
		if not friendly then
			Banjoball:powershotCancel(hero)
		end
	elseif hero.isSlam then
	elseif hero.isPull then
		if hero:HasAbility("pull_break") then
			hero:CastAbilityNoTarget(hero:FindAbilityByName("pull_break"), 0)
		end
	elseif hero.isTackle then
	elseif hero.isBlink then
	elseif hero.isSwap then
	elseif hero.isDemon then
	elseif hero.isHook then
	elseif hero.isCurveshot then
	elseif hero.isWeaver then
	end
	
	-- Check for Surge
	if hero.surgeOn then
		hero:CastAbilityNoTarget(hero:FindAbilityByName(hero.sprintBreak), 0)
	end
	if hero.isChargingCross then
		hero.isChargingCross = false
	end
end

--[[
	Banjoball:ShowCastBar()
		Shows the hero's health bar and sets their health to 1.
		hero - Unit to show the health bar of.
]]--
function Banjoball:ShowCastBar(hero, health)
	hero:SetMaxHealth(health)
	hero:SetHealth(1)
end

--[[
	Banjoball:HideCastBar()
		Hides the hero's health bar and sets their health to max health.
		hero - Unit to hide the health bar of.
]]--
function Banjoball:HideCastBar( hero )
	hero:SetMaxHealth(100)
	hero:SetHealth(100)
end

--[[
	Banjoball:UpdateMana()
		Update the given hero's mana.
		hero - Unit to update mana of.
]]--
function Banjoball:UpdateMana(hero)
	-- Break Sprint if the hero doesn't exist.
	if GameRules:IsGamePaused() then return nil end

	if _inf_mana then
		hero:SetMana(hero:GetMaxMana())
	end
		
	local ball = Ball.unit
	local currMana = hero:GetMana()
	local maxMana = hero:GetMaxMana()
	local currHealth = hero:GetHealth()
	local maxHealth = hero:GetMaxHealth()
	local manaDrain = hero.manaDrain
	local manaReg = hero.manaReg
	
	if hero.password then
		local gain = hero.surgeOn and GAIN or DECREASE
		if hero.goalie then gain = hero.surgeOn and GAIN_GK or DECREASE_GK end
		if hero == ball.controller then gain = hero.surgeOn and GAIN_BALL or DECREASE_BALL end
		hero.SprintMult = math.max( math.min(hero.SprintMult + gain, 1), 0 )
		hero.drainMult = hero == ball.controller and math.max(hero.SprintMult^SPRINT_MANA_DRAIN_POWER*SPRINT_MANA_DRAIN_BALL, SPRINT_DRAIN_MULT_MIN) or hero.goalie and SPRINT_MANA_DRAIN_GOALIE or math.max(hero.SprintMult^SPRINT_MANA_DRAIN_POWER, SPRINT_DRAIN_MULT_MIN)
		hero.ballSlow = BALL_SLOW - BALL_SLOW * hero.SprintMult
	end

	local is_borrow_time = hero:HasModifier("modifier_borrow_time")

	if is_borrow_time then
		-- В Borrow Time пассивная регенерация маны никогда не отключается
		local reg = (currMana < maxMana) and manaReg or 0
		if hero.pritaica then
			hero:SetMana(math.min(maxMana, currMana + MANA_DRAIN_NINJA + reg))
		elseif hero.surgeOn then
			hero:SetMana(math.min(maxMana, currMana + manaDrain*hero.drainMult + reg))
		else
			hero:SetMana(math.min(maxMana, currMana + reg))
		end
	else
		if hero.pritaica then
			if currMana <= 0 then
				hero:CastAbilityNoTarget(hero:FindAbilityByName("ninja_invis_sprint_break"), 0)
			else
				hero:SetMana(currMana - MANA_DRAIN_NINJA)
			end
		elseif hero.surgeOn then
			if currMana <= 0 then
				hero:CastAbilityNoTarget(hero:FindAbilityByName(hero.sprintBreak), 0)
			else
				hero:SetMana(currMana - manaDrain*hero.drainMult)
			end
		elseif currMana < maxMana then
			if not hero:HasModifier("modifier_mist_coil_debuff") then
				hero:SetMana(currMana + manaReg)
			else
				-- Логируем блокировку регенерации раз в 1 секунду игрового времени
				local game_time = GameRules:GetGameTime()
				if not hero.last_coil_log_time or (game_time - hero.last_coil_log_time >= 1.0) then
					hero.last_coil_log_time = game_time
					print(string.format("[UpdateMana] Регенерация маны для %s ЗАБЛОКИРОВАНА дебаффом. Текущая мана = %.2f", hero:GetUnitName(), currMana))
				end
			end
		end
	end
end

--	Find the closest point in the field for the hero
function Banjoball:ClosestPointInField( point )
	local newPoint = point
	if point.x > X_MIN - X_BUFFER and point.x < X_MAX + X_BUFFER then
		-- They're within the normal playing field width.
			if point.x < X_MIN then
			newPoint.x = X_MIN
		elseif point.x > X_MAX then
			newPoint.x = X_MAX
		end
		
		if point.y < Y_MIN then
			newPoint.y = Y_MIN
		elseif
			point.y > Y_MAX then
			newPoint.y = Y_MAX
		end
	else
		-- Either in a goal box or out of the field.
		if point.x < -BORDER_GOAL_X then
			newPoint.x = -BORDER_GOAL_X
		elseif point.x > BORDER_GOAL_X then
			newPoint.x = BORDER_GOAL_X
		end
		
		if point.y < -BORDER_GOAL_Y then
			newPoint.y = -BORDER_GOAL_Y
		elseif point.y > BORDER_GOAL_Y then
			newPoint.y = BORDER_GOAL_Y
		end
	end
	return newPoint
end

function Banjoball:IsPointSafeForHero( hero, point )
	if not IsPointOnField(point) then
		return false
	end
	for i, entity in ipairs(GetUnitsInTrueRadius(point, HERO_DEFAULT_RADIUS / 2)) do
		if entity ~= hero then
			return false
		end
	end
	return true
end