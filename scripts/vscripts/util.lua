--[[
	ExecuteOrderFromTable({
		UnitIndex = caster:GetEntityIndex(),
		AbilityIndex = caster:FindAbilityByName("queenofpain_blink_datadriven"):GetEntityIndex(),
		OrderType = DOTA_UNIT_ORDER_CAST_POSITION, 
		Position = caster.newPos,
		Queue = true })
]]

function GetGoalUnitIsWithin( unit )
	local pos = unit:GetAbsOrigin()
	
	if (pos.y > -GOAL_OUTER_Y and pos.y < GOAL_OUTER_Y) then
		if pos.x < R_OUTWARDNESS then
			return DOTA_TEAM_GOODGUYS
		elseif pos.x > D_OUTWARDNESS then
			return DOTA_TEAM_BADGUYS
		end
	end
	return false
end

function HoggCheck( unit )
	if not unit then return nil end
	local pos = unit:GetAbsOrigin()
	
	if (pos.y > -EXPLOIT_Y and pos.y < EXPLOIT_Y) then
		if pos.x < -EXPLOIT_X then
			return DOTA_TEAM_GOODGUYS
		elseif pos.x > EXPLOIT_X then
			return DOTA_TEAM_BADGUYS
		end
	end
	return nil
end


function GetGoalPointIsWithin( pos )
	
	if (pos.y > -GOAL_OUTER_Y and pos.y < GOAL_OUTER_Y) then
		if pos.x < R_OUTWARDNESS then
			return DOTA_TEAM_GOODGUYS
		elseif pos.x > D_OUTWARDNESS then
			return DOTA_TEAM_BADGUYS
		end
	end
	return nil
end

function GetGoalPointIsWithinGoalZone( pos )
	
	if (pos.y > -GOAL_Y and pos.y < GOAL_Y) then
		if pos.x < R_SCORE then
			return DOTA_TEAM_GOODGUYS
		elseif pos.x > D_SCORE then
			return DOTA_TEAM_BADGUYS
		end
	end
	return nil
end

function GetHeroEnemy(hero)
	if not hero then return nil end
	local enemyTeam
	if hero:GetTeam() == DOTA_TEAM_GOODGUYS then
		enemyTeam = DOTA_TEAM_BADGUYS
	else
		enemyTeam = DOTA_TEAM_GOODGUYS
	end
	return enemyTeam
end

function IsPointInRectangle(point, xMin, xMax, yMin, yMax)
	return point.x > xMin and point.x < xMax and point.y > yMin and point.y < yMax
end

function IsPointOnField( point )
	if IsPointInRectangle(point, X_MIN, X_MAX, Y_MIN, Y_MAX) then -- In the playing field
		return true
	elseif IsPointInRectangle(point, -BORDER_GOAL_X, BORDER_GOAL_X, -BORDER_GOAL_Y, BORDER_GOAL_Y) then -- In a goal
		return true
	end
	return false -- Out of Field
end

function ClosestPointInRectangle(point, xMin, xMax, yMin, yMax)
	return Vector(math.max(math.min(xMax, point.x), xMin), math.max(math.min(yMax, point.y), yMin), point.z)
end

function ClosestPointOnField( point )
	local closestOnPlayingField = ClosestPointInRectangle(point, X_MIN, X_MAX, Y_MIN, Y_MAX)
	-- techinically not exactly a goal, but a rectangle including both goals and the part of field between them
	local closestInGoal = ClosestPointInRectangle(point, -BORDER_GOAL_X, BORDER_GOAL_X, -BORDER_GOAL_Y, BORDER_GOAL_Y)
	if (point - closestOnPlayingField):Length() < (point - closestInGoal):Length() then
		return closestOnPlayingField
	else
		return closestInGoal
	end
end
function isUnitInHitbox( unit, box )
	local unitPos = unit:GetAbsOrigin()
	for i=0, 3 do
		local v1 = Vector(box[i].x - unitPos.x, box[i].y - unitPos.y, unitPos.z)
		local v2 = Vector(box[(i+1)%4].x - unitPos.x, box[(i+1)%4].y - unitPos.y, unitPos.z)
		
		if (v2.x * v1.y - v1.x * v2.y) < 0 then
			return false
		end
	end
	return true
end

function GetUnitsInRadius( location, radius )
	local affected = {}
	for i, ent in ipairs(Entities:FindAllInSphere(location, radius)) do
		if IsPhysicsUnit(ent) and (ent.isBanjoHero or ent.isBall or Banjoball:IsProjectile(ent)) then
			table.insert(affected, ent)
		end
	end
	
	return affected
end

-- This function lists all heroes inside a put radius.
function GetUnitsInTrueRadius( position, radius )
	local affected = {}
	for i, hero in ipairs(Banjoball.vHeroes) do
		if not hero.tempremoved and (position - hero:GetAbsOrigin()):Length() <= radius then table.insert(affected, hero) end
	end
	
	return affected
end

function IsUnitInTrueRadius( hero, target, radius )
	
	return ((hero.x - target.x)^2+(hero.y - target.y)^2)^0.5 <= radius
end--
--TIPPPS
registered_custom_listeners = {}
function RegisterCustomEventListener(event_name, callback, context)
	if not callback then
		error("Invalid / nil callback passed in RegisterCustomEventListener")
		return
	end

	local listener_id = CustomGameEventManager:RegisterListener(event_name, function(_, args)
		if context then
			callback(context, args)
		else
			callback(args, context)
		end
	end)

	table.insert(registered_custom_listeners, listener_id)
end

function DisplayError(player_id, message)
	local player = PlayerResource:GetPlayer(player_id)
	if player then
		CustomGameEventManager:Send_ServerToPlayer(player, "display_custom_error", { message = message })
	end
end

function DisplayErrorWithValue(player_id, message, values)
	local player = PlayerResource:GetPlayer(player_id)
	if player then
		CustomGameEventManager:Send_ServerToPlayer(player, "display_custom_error_with_value", { message = message, values = values })
	end
end

--[[
	Honestly just a series of debug messages in case we want to do anything
	special with them.
]]--
function PrintDebugMessage( message )
	print( message )
end

--[[
	SwapAbilities()
	Swap the abilities of the given hero safely.
	hero 			= Unit. 		Hero whose abilities are to be swapped.
	activeSpell	= String. 	Name of spell to make active.
	hiddenSpell	= String. 	Name of spell to hide.
	slot 			= Integer	Slot of spell.
	
	Returns true if successful, false otherwise.
]]--
function SwapAbilities( hero, activeSpell, hiddenSpell, slot )
	-- Break if the hero doesn't have one of the spells,
	if not hero:HasAbility( activeSpell ) or not hero:HasAbility( hiddenSpell ) then
		local active = hero:HasAbility( activeSpell )
		local hidden = hero:HasAbility( hiddenSpell )
		if not active and not hidden then
			PrintDebugMessage( hero.playerName .. " has neither " .. activeSpell .. " nor " .. hiddenSpell .. " to swap." )
		elseif not active then
			PrintDebugMessage( hero.playerName .. " does not have " .. activeSpell .. " to swap with " .. hiddenSpell .. "." )
		else
			PrintDebugMessage( hero.playerName .. " does not have " .. hiddenSpell .. " to swap with " .. activeSpell .. "." )
		end
		return false
	end
	
	-- Break if the spell is already in the right slot.
	if hero:GetAbilityByIndex( slot ):GetAbilityName() == activeSpell then
	--	PrintDebugMessage( hero.playerName .. " already has " .. activeSpell .. " active." )
		return false
	end
	
	hero:SwapAbilities(activeSpell, hiddenSpell, true, false)
	return true
end

function AddHiddenAbility( hero, abilityName )
	hero:AddAbility( abilityName )
	local ability = hero:FindAbilityByName( abilityName )
	ability:SetLevel( 1 )
	ability:SetHidden( true )
end

-- function AddReadyAbility(unit, ability_name)
	-- if not IsValidEntity(unit) then return end
	-- if unit:HasAbility(ability_name) then return end
	-- local new_ability = unit:AddAbility(ability_name)
	-- new_ability:SetLevel(1)
	-- new_ability:SetHidden(false)
-- end

-- function AddTempAbility( hero, abilityName, temp )
	-- hero:AddAbility( abilityName )
	-- local ability = hero:FindAbilityByName( abilityName )
	-- ability:SetLevel( 1 )
	-- hero.remainingTimer = Timers:CreateTimer(function()
		-- if temp <= 0 then
			-- hero:RemoveAbility( abilityName )
			-- return
		-- end
		-- temp = temp - 1
		-- return 1
	-- end)
-- end

--[[
	Banjoball:SetSharedControl()
	Gives or removes control of one player from another player.
	owner - Integer. 				Player ID sharing/removing control.
	teammate - Integer. 			Player ID taking/losing control.
	sharedControl - Boolean. 	Setting to control shared state.
]]--
function SetSharedControl(owner, teammate, sharedControl)
	-- Eventually I should set those to constants.
	PlayerResource:SetUnitShareMaskForPlayer(owner, teammate, 1, sharedControl)
	PlayerResource:SetUnitShareMaskForPlayer(owner, teammate, 2, sharedControl)
end

function OnShareControl( event, args )
	print( "Sharing control of " .. args['owner'] .. " to " .. args['other'] .. "." )
	local owner = args['owner']
	local other = args['other']
	SetSharedControl(owner, other, true)
end
CustomGameEventManager:RegisterListener( "share_control", OnShareControl )

function OnRemoveControl( event, args )
	print( "Removing control of " .. args['owner'] .. " from " .. args['other'] .. "." )
	local owner = args['owner']
	local other = args['other']
	SetSharedControl(owner, other, false)
end
CustomGameEventManager:RegisterListener( "remove_control", OnRemoveControl )

function GetSystemTimeTableCustom()
	local date_str = GetSystemDate() or ""
	local time_str = GetSystemTime() or ""
	
	local hr, min, sec = string.match(time_str, "(%d+):(%d+):(%d+)")
	hr = tonumber(hr) or 0
	min = tonumber(min) or 0
	sec = tonumber(sec) or 0
	
	local y, m, d
	-- 1. Формат YYYY-MM-DD
	y, m, d = string.match(date_str, "(%d%d%d%d)[-%/](%d+)[-%/](%d+)")
	if y then
		return { year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = hr, min = min, sec = sec }
	end
	
	-- 2. Формат DD.MM.YYYY или DD.MM.YY
	local p1, p2, p3 = string.match(date_str, "(%d+)%.(%d+)%.(%d+)")
	if p1 then
		d = tonumber(p1)
		m = tonumber(p2)
		y = tonumber(p3)
		if y < 100 then y = y + 2000 end
		return { year = y, month = m, day = d, hour = hr, min = min, sec = sec }
	end
	
	-- 3. Формат MM/DD/YY или MM/DD/YYYY
	p1, p2, p3 = string.match(date_str, "(%d+)/(%d+)/(%d+)")
	if p1 then
		m = tonumber(p1)
		d = tonumber(p2)
		y = tonumber(p3)
		if y < 100 then y = y + 2000 end
		return { year = y, month = m, day = d, hour = hr, min = min, sec = sec }
	end
	
	return { year = 2026, month = 7, day = 2, hour = hr, min = min, sec = sec }
end

function GetUnixTime(t)
	if not t then return 0 end
	local y = t.year
	local m = t.month
	local d = t.day
	
	local days_in_months = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
	
	local function is_leap_year(year)
		return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
	end
	
	local total_days = 0
	for year = 1970, y - 1 do
		total_days = total_days + (is_leap_year(year) and 366 or 365)
	end
	
	for month = 1, m - 1 do
		if month == 2 and is_leap_year(y) then
			total_days = total_days + 29
		else
			total_days = total_days + days_in_months[month]
		end
	end
	
	total_days = total_days + (d - 1)
	
	local seconds = total_days * 86400 + t.hour * 3600 + t.min * 60 + t.sec
	return seconds
end

function ParseISO8601(str)
	if not str or str == "" then return 0 end
	-- Поддерживает разделители дефис/слэш/точку в дате, пробел/Т между датой и временем
	local y, m, d, hr, min, sec = string.match(str, "(%d%d%d%d)[-%/%.:](%d+)[-%/%.:](%d+)[T%s](%d+):(%d+):(%d+)")
	if not y then return 0 end
	
	local t = {
		year = tonumber(y),
		month = tonumber(m),
		day = tonumber(d),
		hour = tonumber(hr),
		min = tonumber(min),
		sec = tonumber(sec)
	}
	return GetUnixTime(t)
end

function GetISO8601Time(t)
	if not t then return nil end
	return string.format("%04d-%02d-%02dT%02d:%02d:%02dZ", t.year, t.month, t.day, t.hour, t.min, t.sec)
end

function OnDoubleDownRequest( event, args )
	local pID = args.PlayerID
	if not pID or not PlayerResource:IsValidPlayerID(pID) then return end

	local current_time = GetUnixTime(GetSystemTimeTableCustom())
	local last_time = 0
	if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
		last_time = Banjoball.vFullinfo[pID].last_double_down_unix or 0
	end
	
	local current_day = math.floor((current_time - 25200) / 86400)
	local last_day = math.floor((last_time - 25200) / 86400)
	
	local last_reset_unix = math.floor((current_time - 25200) / 86400) * 86400 + 25200
	local next_reset_unix = last_reset_unix + 86400
	local cooldown_seconds = next_reset_unix - current_time

	-- Временно отключено по просьбе пользователя
	-- if current_day <= last_day then
	if false then
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(pID), "display_custom_error", { message = "Вы уже удваивали рейтинг сегодня!" })
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(pID), "double_down_status", { 
			is_active = false, 
			is_available = false,
			cooldown_seconds = cooldown_seconds
		})
		return
	end

	-- Проверяем время (GetDOTATime возвращает секунды с начала матча)
	local dota_time = GameRules:GetDOTATime(false, false)
	local state = GameRules:State_Get()
	local is_early_game = (dota_time <= 60) or (state < DOTA_GAMERULES_STATE_GAME_IN_PROGRESS)

	if is_early_game then
		if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
			if not Banjoball.vFullinfo[pID].double_down then
				Banjoball.vFullinfo[pID].double_down = true
				print("[DoubleDown] Player " .. pID .. " activated Double Down!")
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(pID), "double_down_status", { 
					is_active = true, 
					is_available = false,
					cooldown_seconds = cooldown_seconds
				})
				
				local player_name = PlayerResource:GetPlayerName(pID)
				if player_name == nil or player_name == "" then
					player_name = "Игрок " .. (pID + 1)
				end
				local msg = string.format("<font color='#ffd700'>%s</font> удвоил рейтинг в этой игре", player_name)
				GameRules:SendCustomMessage(msg, -1, 0)
			end
		end
	else
		CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(pID), "display_custom_error", { message = "Удвоить рейтинг можно только в начале игры!" })
	end
end
if _G.DoubleDownRequestListenerId then
	CustomGameEventManager:UnregisterListener(_G.DoubleDownRequestListenerId)
end
_G.DoubleDownRequestListenerId = CustomGameEventManager:RegisterListener( "double_down_request", OnDoubleDownRequest )

function OnDoubleDownCheckStatus( event, args )
	local pID = args.PlayerID
	if not pID or not PlayerResource:IsValidPlayerID(pID) then return end
	
	local is_active = false
	local is_available = true
	
	local current_time = GetUnixTime(GetSystemTimeTableCustom())
	local last_reset_unix = math.floor((current_time - 25200) / 86400) * 86400 + 25200
	local next_reset_unix = last_reset_unix + 86400
	local cooldown_seconds = next_reset_unix - current_time

	if Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
		is_active = Banjoball.vFullinfo[pID].double_down == true
		
		local last_time = Banjoball.vFullinfo[pID].last_double_down_unix or 0
		local current_day = math.floor((current_time - 25200) / 86400)
		local last_day = math.floor((last_time - 25200) / 86400)
		
		print(string.format("[DoubleDown] Status check player %d: current_time=%d, last_time=%d, current_day=%d, last_day=%d",
			pID, current_time, last_time, current_day, last_day))
		
		-- Временно отключено по просьбе пользователя
		-- if current_day <= last_day then
		if false then
			is_available = false
		end
	end
	
	CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(pID), "double_down_status", { 
		is_active = is_active,
		is_available = is_available,
		cooldown_seconds = cooldown_seconds
	})
end

if _G.DoubleDownStatusListenerId then
	CustomGameEventManager:UnregisterListener(_G.DoubleDownStatusListenerId)
end
_G.DoubleDownStatusListenerId = CustomGameEventManager:RegisterListener( "double_down_check_status", OnDoubleDownCheckStatus )

if modifier_hide_healthbar == nil then
	modifier_hide_healthbar = class({})
end

function modifier_hide_healthbar:IsHidden() return true end
function modifier_hide_healthbar:IsPurgable() return false end
function modifier_hide_healthbar:RemoveOnDeath() return false end

function modifier_hide_healthbar:CheckState()
	return {
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
	}
end

LinkLuaModifier("modifier_hide_healthbar", "util.lua", LUA_MODIFIER_MOTION_NONE)



g_SelfHealthHidden = false
g_AllyHealthHidden = false
g_EnemyHealthHidden = false

-- Функция применения/удаления модификаторов на основе текущих состояний тоглов
function UpdateAllHeroesHealthBars()
	local allHeroes = HeroList:GetAllHeroes()
	for _, hero in ipairs(allHeroes) do
		if hero and not hero:IsNull() and hero:IsRealHero() then
			local playerID = hero:GetPlayerOwnerID()
			local localPlayerID = 0 -- Для простоты в локальном лобби, либо берем первого игрока. 
			-- Так как игра 5х5, и скрытие хитбара - это серверный модификатор (скрывает для всех), 
			-- мы определяем скрывать ли хитбар конкретного героя на основе общих глобальных флагов.
			
			local isSelf = (playerID == localPlayerID)
			local isAlly = false
			if not isSelf and playerID ~= -1 then
				-- В Banjoball две команды: GOODGUYS (Blue) и BADGUYS (Red).
				-- Проверяем команду относительно игрока с ID 0 (или хоста)
				local hostTeam = PlayerResource:GetTeam(localPlayerID)
				if hostTeam then
					isAlly = (hero:GetTeam() == hostTeam)
				end
			end
			local isEnemy = not isSelf and not isAlly

			local shouldHide = false
			if isSelf and g_SelfHealthHidden then
				shouldHide = true
			elseif isAlly and g_AllyHealthHidden then
				shouldHide = true
			elseif isEnemy and g_EnemyHealthHidden then
				shouldHide = true
			end

			if shouldHide then
				if not hero:HasModifier("modifier_hide_healthbar") then
					hero:AddNewModifier(hero, nil, "modifier_hide_healthbar", {})
				end
			else
				hero:RemoveModifierByName("modifier_hide_healthbar")
			end
		end
	end
end


function OnToggleAllyAbilities( event, args )
	local pID = args['playerID']
	local hidden = (args['hidden'] == 1)
	if pID and Banjoball.vFullinfo and Banjoball.vFullinfo[pID] then
		Banjoball.vFullinfo[pID]["ally_abilities_hidden"] = hidden
	end
	print("[AllyAbilityToggle] hidden=" .. tostring(hidden))
end
CustomGameEventManager:RegisterListener( "toggle_ally_abilities", OnToggleAllyAbilities )




-----------------------------------------------------------------------------

function DummyCastBlink(caster, startPos, endPos )
	local dummy = CreateUnitByName("dummy", startPos, false, nil, nil, caster:GetTeam())
	dummy:AddAbility("queenofpain_blink_datadriven")
	local blinkAbil = dummy:FindAbilityByName("queenofpain_blink_datadriven")
	blinkAbil:SetLevel(1)
	Timers:CreateTimer(.03, function()
		dummy:SetForwardVector((endPos-startPos):Normalized())
		Timers:CreateTimer(.03, function()
			dummy:CastAbilityOnPosition(endPos, blinkAbil, 0)
		end)
	end)

	Timers:CreateTimer(2, function()
		dummy:ForceKill(true)
	end)
end

function MergeTables( tableOfTables )
	local index = 1
	local newTable = {}
	for i,t in ipairs(tableOfTables) do
		if type(t) == "table" then
			for i2,val in ipairs(t) do
				newTable[index] = val
				index = index + 1
			end
		end
	end
	return newTable
end

-- ty noya
function PlayCentaurBloodEffect( unit )
	local centaur_blood_fx = "particles/units/heroes/hero_centaur/centaur_double_edge_bloodspray_src.vpcf"
	local targetLoc = unit:GetAbsOrigin()
	local blood = ParticleManager:CreateParticle(centaur_blood_fx, PATTACH_CUSTOMORIGIN, unit)
	ParticleManager:SetParticleControl(blood, 0, targetLoc)
	ParticleManager:SetParticleControl(blood, 2, targetLoc+RandomVector(RandomInt(20,100)))
	ParticleManager:SetParticleControl(blood, 4, targetLoc+RandomVector(RandomInt(20,100)))
	ParticleManager:SetParticleControl(blood, 5, targetLoc+RandomVector(RandomInt(20,100)))
end

function CreateNeutralParticle( particle, pos, attach_type, duration )
	local handler = CreateUnitByName("dummy", pos, false, nil, nil, DOTA_TEAM_NEUTRALS)
	local part = ParticleManager:CreateParticle(particle, attach_type, handler)

	Timers:CreateTimer(duration, function()
		handler:ForceKill(true)
	end)

	return part
end

function AddStun( unit )
	if not unit:HasAbility("stun_passive") then
		unit:AddAbility("stun_passive")
		unit:FindAbilityByName("stun_passive"):SetLevel(1)
	end
end

function RemoveStun( unit )
	if unit:HasAbility("stun_passive") then
		unit:RemoveAbility("stun_passive")
		unit:RemoveModifierByName("modifier_stun_passive")
	end
end

function AddSilence( unit )
	if not unit:HasModifier("modifier_endround_silenced_passive") then
		EndRoundDummy.endround_passive:ApplyDataDrivenModifier(EndRoundDummy, unit, "modifier_endround_silenced_passive", {})
	end
end

function RemoveSilence( unit )
	if unit:HasModifier("modifier_endround_silenced_passive") then
		unit:RemoveModifierByName("modifier_endround_silenced_passive")
	end
end

function AddEndgameRoot( unit )
	if not unit:HasModifier("modifier_endround_rooted_passive") then
		EndRoundDummy.endround_passive:ApplyDataDrivenModifier(EndRoundDummy, unit, "modifier_endround_rooted_passive", {})
	end
end

function RemoveEndgameRoot( unit )
	if unit:HasModifier("modifier_endround_rooted_passive") then
		unit:RemoveModifierByName("modifier_endround_rooted_passive")
	end
end

function AddDisarmed( unit )
	if unit:HasModifier("modifier_disarmed_off") then
		unit:RemoveModifierByName("modifier_disarmed_off")
	end
	GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, unit, "modifier_disarmed_on", {})
end

function RemoveDisarmed( unit )
	if unit:HasModifier("modifier_disarmed_on") then
		unit:RemoveModifierByName("modifier_disarmed_on")
	end
	GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, unit, "modifier_disarmed_off", {})
end

function InitAbility( ... )
	local t = {...}
	local sAbilName = t[1]
	local unit = t[2]
	local fun = t[3]
	local remove = t[4]

	unit:AddAbility(sAbilName)
	local abil = unit:FindAbilityByName(sAbilName)
	abil:SetLevel(1)

	if fun then
		Timers:CreateTimer(.03, function()
			fun(abil)
			Timers:CreateTimer(.03, function()
				if remove then
					unit:RemoveAbility(sAbilName)
				end
			end)
		end)
	else
		return abil
	end
end

function GetTeammates( hero )
	local teammates = {}
	for i=0,9 do
		local ply = PlayerResource:GetPlayer(i)
			if ply then
			local hero2 = ply:GetAssignedHero()
			if hero2 and hero2:GetTeam() == hero:GetTeam() and hero2 ~= hero then
				table.insert(teammates, hero2)
			end
		end
	end
	return teammates
end

function EmitSoundAtPosition( ... )
	local t = {...}
	local soundName = t[1]
	local pos = t[2]

	if type(pos) ~= "userdata" and IsValidEntity(pos) then
		pos = pos:GetAbsOrigin()
	end

	local duration = t[3]
	local soundDummy = CreateUnitByName("dummy", pos, false, nil, nil, DOTA_TEAM_GOODGUYS)
	soundDummy:EmitSound(soundName)
	if not duration then
		soundDummy:ForceKill(true)
	else
		local soundObj = {}
		soundObj.dummy = soundDummy
		soundObj.timer = Timers:CreateTimer(duration, function()
			soundDummy:StopSound(soundName)
			soundDummy:ForceKill(true)
		end)
		return soundObj
	end
end

function ShowQuickMessages( linesTable, durBetweenLines )
	for i,line in ipairs(linesTable) do
		if i == 1 then GameRules:SendCustomMessage(line, 0, 0)
		else
			local delay = (i-1)*durBetweenLines
			Timers:CreateTimer(delay, function()
				GameRules:SendCustomMessage(line, 0, 0)
			end)
		end
	end
end

function ShowErrorMsg( unit, msg )
	if not unit or not unit:GetPlayerOwner() then return end
	if not unit.lastErrorPopupTime or (GameRules:GetGameTime()-unit.lastErrorPopupTime > 1) then
		unit.lastErrorPopupTime = GameRules:GetGameTime()
		local player = unit:GetPlayerOwner()
		if player then
			CustomGameEventManager:Send_ServerToPlayer(player, "display_custom_error", { message = msg })
		end
	end
end

function Length3DSq(v) 
    return v.x * v.x + v.y * v.y + v.z * v.z
end

function VectorDistanceSq(v1, v2) 
    return (v1.x - v2.x) * (v1.x - v2.x) + (v1.y - v2.y) * (v1.y - v2.y) + (v1.z - v2.z) * (v1.z - v2.z)
end

function ValidAndAlive( ent )
	return IsValidEntity(ent) and ent:IsAlive()
end

function ShowCenterMsg( msg, dur )
      local msgTable = {
        message = msg,
        duration = dur
      }
end

-- Returns a shallow copy of the passed table.
function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function AbilityIterator(unit, callback)
    for i=0, unit:GetAbilityCount()-1 do
        local abil = unit:GetAbilityByIndex(i)
        if abil ~= nil then
            callback(abil)
        end
    end
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

function VectorString(v)
  return 'x: ' .. v.x .. ' y: ' .. v.y .. ' z: ' .. v.z
end

function TableLength( t )
    if t == nil or t == {} then
        return 0
    end
    local len = 0
    for k,v in pairs(t) do
        len = len + 1
    end
    return len
end

-- Remove all abilities on a unit.
function ClearAbilities( unit )
	if not unit or not unit.GetAbilityCount or unit:GetAbilityCount() < 1 then return end
	
	for i=0, unit:GetAbilityCount()-1 do
		local abil = unit:GetAbilityByIndex(i)
		if abil ~= nil then
			unit:RemoveAbility(abil:GetAbilityName())
		end
	end
	-- we have to put in dummies and remove dummies so the ability icon changes.
	-- it's stupid but volvo made us
	for i=1,6 do
		unit:AddAbility("banjoball_empty" .. tostring(i))
	end
	for i=0, unit:GetAbilityCount()-1 do
		local abil = unit:GetAbilityByIndex(i)
		if abil ~= nil then
			unit:RemoveAbility(abil:GetAbilityName())
		end
	end
end

-- goes through a unit's abilities and sets the abil's level to 1,
-- spending an ability point if possible.
function InitAbilities( hero )
	for i=0, hero:GetAbilityCount()-1 do
		local abil = hero:GetAbilityByIndex(i)
		if abil ~= nil then
			if hero:IsRealHero() and hero:GetAbilityPoints() > 0 then
				hero:UpgradeAbility(abil)
			else
				abil:SetLevel(1)
			end
		end
	end
end

function GetOppositeTeam( unit )
	if unit:GetTeam() == DOTA_TEAM_GOODGUYS then
		return DOTA_TEAM_BADGUYS
	else
		return DOTA_TEAM_GOODGUYS
	end
end

-- returns true 50% of the time.
function CoinFlip(  )
	return RollPercentage(50)
end

-- theta is in radians.
function RotateVector2D(v,theta)
	local xp = v.x*math.cos(theta)-v.y*math.sin(theta)
	local yp = v.x*math.sin(theta)+v.y*math.cos(theta)
	return Vector(xp,yp,v.z):Normalized()
end

function PrintVector(v)
	print('x: ' .. v.x .. ' y: ' .. v.y .. ' z: ' .. v.z)
end

-- Given element and list, returns true if element is in the list.
function TableContains( list, element )
	if list == nil then return false end
	for k,v in pairs(list) do
		if k == element then
			return true
		end
	end
	return false
end

-- Given element and list, returns the position of the element in the list.
-- Returns -1 if element was not found, or if list is nil.
function GetIndex(list, element)
	if list == nil then return -1 end
	for i=1,#list do
		if list[i] == element then
			return i
		end
	end
	return -1
end

-- useful with GameRules:SendCustomMessage
function ColorIt( ... )
	local t = {...}
	local sStr = t[1] or "Unknown"
	local sColor = t[2] or "white"

	local real = t[3]
	--Default is cyan.
	local color = "00FFFF"

	-- so basically, i find that some colors don't look that great in dota. so unless real==true, i'm using my own
	-- shades of green, shades of blue, shades of red, etc.
	if real then
		if sColor == "green" then
			color = "008000"
		elseif sColor == "purple" then
			color = "800080"
		elseif sColor == "blue" then
			color = "0000FF"
		elseif sColor == "orange" then
			color = "FFA500"
		elseif sColor == "pink" then
			color = "FFC0CB"
		elseif sColor == "red" then
			color = "FF0000"
		elseif sColor == "cyan" then
			color = "00FFFF"
		elseif sColor == "yellow" then
			color = "FFFF00"
		elseif sColor == "brown" then
			color = "A52A2A"
		elseif sColor == "magenta" then
			color = "FF00FF"
		elseif sColor == "teal" then
			color = "008080"
		elseif sColor == "light_green" then
			color = "90EE90"
		elseif sColor == "sky_blue" then
			color = "87CEEB"
		elseif sColor == "dark_green" then
			color = "006400"
		end
	else
		if sColor == "green" then
			color = "22fd23"
		elseif sColor == "purple" then
			color = "ba10bb"
		elseif sColor == "blue" then
			color = "347dee"
		elseif sColor == "orange" then
			color = "fa771f"
		elseif sColor == "pink" then
			color = "f88dbb"
		elseif sColor == "red" then
			color = "fd0618"
		elseif sColor == "cyan" then
			color = "75fbc6"
		elseif sColor == "yellow" then
			color = "ecf739"
		elseif sColor == "brown" then
			color = "a16f26"
		elseif sColor == "magenta" then
			color = "FF00FF"
		elseif sColor == "teal" then
			color = "008080"
		elseif sColor == "light_green" then
			color = "a0b453"
		elseif sColor == "sky_blue" then
			color = "6edee9"
		elseif sColor == "dark_green" then
			color = "087d2f"
		end
	end

	return "<font color='#" .. color .. "'>" .. sStr .. "</font>"
end

--[[
	p: the raw point (Vector)
	center: center of the square. (Vector)
	length: length of 1 side of square. (Float)
]]
function IsPointWithinSquare(p, center, halfLength)
	if (p.x > center.x-halfLength and p.x < center.x+halfLength) and 
		(p.y > center.y-halfLength and p.y < center.y+halfLength) then
		return true
	end
	return false
end

function IsPointWithinCube(p, center, halfLength)
	return (p.x > center.x-halfLength and p.x < center.x+halfLength) and 
		(p.y > center.y-halfLength and p.y < center.y+halfLength) and
		(p.z > center.z-halfLength and p.z < center.z+halfLength)
end

function circle_circle_collision(p1Origin, p2Origin, p1Radius, p2Radius)
  if ((p1Origin.x - p2Origin.x)*(p1Origin.x - p2Origin.x) + (p1Origin.y - p2Origin.y)*(p1Origin.y - p2Origin.y)) <= (p1Radius+p2Radius)*(p1Radius+p2Radius) then
    return true
  else
    return false
  end
end

--[[
  Continuous collision algorithm for circular 2D bodies, see
  http://www.gvu.gatech.edu/people/official/jarek/graphics/material/collisionFitzgeraldForsthoefel.pdf
  
  body1 and body2 are tables that contain:
  v: velocity (Vector)
  c: center (Vector)
  r: radius (Float)

  Returns the time-till-collision.
]]
function TimeTillCollision(body1,body2)
	local W = body2.v-body1.v
	local D = body2.c-body1.c
	local A = DotProduct(W,W)
	local B = 2*DotProduct(D,W)
	local C = DotProduct(D,D)-(body1.r+body2.r)*(body1.r+body2.r)
	local d = B*B-(4*A*C)
	if d>=0 then
		local t1=(-B-math.sqrt(d))/(2*A)
		if t1<0 then t1=2 end
		local t2=(-B+math.sqrt(d))/(2*A)
		if t2<0 then t2=2 end
		local m = math.min(t1,t2)
		--if ((-0.02<=m) and (m<=1.02)) then
		return m
			--end
	end
	return 2
end

function round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

function DotProduct(v1,v2)
  return (v1.x*v2.x)+(v1.y*v2.y)
end

function PrintTable(t, indent, done)
	--print ( string.format ('PrintTable type %s', type(keys)) )
	if type(t) ~= "table" then return end

	done = done or {}
	done[t] = true
	indent = indent or 0

	local l = {}
	for k, v in pairs(t) do
		table.insert(l, k)
	end

	table.sort(l)
	for k, v in ipairs(l) do
		-- Ignore FDesc
		if v ~= 'FDesc' then
			local value = t[v]

			if type(value) == "table" and not done[value] then
				done [value] = true
				print(string.rep ("\t", indent)..tostring(v)..":")
				PrintTable (value, indent + 2, done)
			elseif type(value) == "userdata" and not done[value] then
				done [value] = true
				print(string.rep ("\t", indent)..tostring(v)..": "..tostring(value))
				PrintTable ((getmetatable(value) and getmetatable(value).__index) or getmetatable(value), indent + 2, done)
			else
				if t.FDesc and t.FDesc[v] then
					print(string.rep ("\t", indent)..tostring(t.FDesc[v]))
				else
					print(string.rep ("\t", indent)..tostring(v)..": "..tostring(value))
				end
			end
		end
	end
end



--============ Copyright (c) Valve Corporation, All rights reserved. ==========
--
--
--=============================================================================

--/////////////////////////////////////////////////////////////////////////////
-- Debug helpers
--
--  Things that are really for during development - you really should never call any of this
--  in final/real/workshop submitted code
--/////////////////////////////////////////////////////////////////////////////

-- if you want a table printed to console formatted like a table (dont we already have this somewhere?)
scripthelp_LogDeepPrintTable = "Print out a table (and subtables) to the console"
logFile = "log/log.txt"

function LogDeepSetLogFile( file )
	logFile = file
end

function LogEndLine ( line )
	AppendToLogFile(logFile, line .. "\n")
end

function _LogDeepPrintMetaTable( debugMetaTable, prefix )
	_LogDeepPrintTable( debugMetaTable, prefix, false, false )
	if getmetatable( debugMetaTable ) ~= nil and getmetatable( debugMetaTable ).__index ~= nil then
		_LogDeepPrintMetaTable( getmetatable( debugMetaTable ).__index, prefix )
	end
end

function _LogDeepPrintTable(debugInstance, prefix, isOuterScope, chaseMetaTables )
	prefix = prefix or ""
	local string_accum = ""
	if debugInstance == nil then
		LogEndLine( prefix .. "<nil>" )
		return
	end
	local terminatescope = false
	local oldPrefix = ""
	if isOuterScope then  -- special case for outer call - so we dont end up iterating strings, basically
		if type(debugInstance) == "table" then
			LogEndLine( prefix .. "{" )
			oldPrefix = prefix
			prefix = prefix .. "   "
			terminatescope = true
	else
		LogEndLine( prefix .. " = " .. (type(debugInstance) == "string" and ("\"" .. debugInstance .. "\"") or debugInstance))
	end
	end
	local debugOver = debugInstance

	-- First deal with metatables
	if chaseMetaTables == true then
		if getmetatable( debugOver ) ~= nil and getmetatable( debugOver ).__index ~= nil then
			local thisMetaTable = getmetatable( debugOver ).__index
			if vlua.find(_LogDeepprint_alreadyseen, thisMetaTable ) ~= nil then
				LogEndLine( string.format( "%s%-32s\t= %s (table, already seen)", prefix, "metatable", tostring( thisMetaTable ) ) )
			else
				LogEndLine(prefix .. "metatable = " .. tostring( thisMetaTable ) )
				LogEndLine(prefix .. "{")
				table.insert( _LogDeepprint_alreadyseen, thisMetaTable )
				_LogDeepPrintMetaTable( thisMetaTable, prefix .. "   ", false )
				LogEndLine(prefix .. "}")
			end
		end
	end

	-- Now deal with the elements themselves
	-- debugOver sometimes a string??
	for idx, data_value in pairs(debugOver) do
		if type(data_value) == "table" then
			if vlua.find(_LogDeepprint_alreadyseen, data_value) ~= nil then
				LogEndLine( string.format( "%s%-32s\t= %s (table, already seen)", prefix, idx, tostring( data_value ) ) )
			else
				local is_array = #data_value > 0
				local test = 1
				for idx2, val2 in pairs(data_value) do
					if type( idx2 ) ~= "number" or idx2 ~= test then
						is_array = false
						break
					end
					test = test + 1
				end
				local valtype = type(data_value)
				if is_array == true then
					valtype = "array table"
				end
				LogEndLine( string.format( "%s%-32s\t= %s (%s)", prefix, idx, tostring(data_value), valtype ) )
				LogEndLine(prefix .. (is_array and "[" or "{"))
				table.insert(_LogDeepprint_alreadyseen, data_value)
				_LogDeepPrintTable(data_value, prefix .. "   ", false, true)
				LogEndLine(prefix .. (is_array and "]" or "}"))
			end
		elseif type(data_value) == "string" then
			LogEndLine( string.format( "%s%-32s\t= \"%s\" (%s)", prefix, idx, data_value, type(data_value) ) )
		else
			LogEndLine( string.format( "%s%-32s\t= %s (%s)", prefix, idx, tostring(data_value), type(data_value) ) )
		end
	end
	if terminatescope == true then
		LogEndLine( oldPrefix .. "}" )
	end
end


function LogDeepPrintTable( debugInstance, prefix, isPublicScriptScope )
	prefix = prefix or ""
	_LogDeepprint_alreadyseen = {}
	table.insert(_LogDeepprint_alreadyseen, debugInstance)
	_LogDeepPrintTable(debugInstance, prefix, true, isPublicScriptScope )
end


--/////////////////////////////////////////////////////////////////////////////
-- Fancy new LogDeepPrint - handles instances, and avoids cycles
--
--/////////////////////////////////////////////////////////////////////////////

-- @todo: this is hideous, there must be a "right way" to do this, im dumb!
-- outside the recursion table of seen recurses so we dont cycle into our components that refer back to ourselves
_LogDeepprint_alreadyseen = {}


-- the inner recursion for the LogDeep print
function _LogDeepToString(debugInstance, prefix)
	local string_accum = ""
	if debugInstance == nil then
		return "LogDeep Print of NULL" .. "\n"
	end
	if prefix == "" then  -- special case for outer call - so we dont end up iterating strings, basically
		if type(debugInstance) == "table" or type(debugInstance) == "table" or type(debugInstance) == "UNKNOWN" or type(debugInstance) == "table" then
			string_accum = string_accum .. (type(debugInstance) == "table" and "[" or "{") .. "\n"
			prefix = "   "
	else
		return " = " .. (type(debugInstance) == "string" and ("\"" .. debugInstance .. "\"") or debugInstance) .. "\n"
	end
	end
	local debugOver = type(debugInstance) == "UNKNOWN" and getclass(debugInstance) or debugInstance
	for idx, val in pairs(debugOver) do
		local data_value = debugInstance[idx]
		if type(data_value) == "table" or type(data_value) == "table" or type(data_value) == "UNKNOWN" or type(data_value) == "table" then
			if vlua.find(_LogDeepprint_alreadyseen, data_value) ~= nil then
				string_accum = string_accum .. prefix .. idx .. " ALREADY SEEN " .. "\n"
			else
				local is_array = type(data_value) == "table"
				string_accum = string_accum .. prefix .. idx .. " = ( " .. type(data_value) .. " )" .. "\n"
				string_accum = string_accum .. prefix .. (is_array and "[" or "{") .. "\n"
				table.insert(_LogDeepprint_alreadyseen, data_value)
				string_accum = string_accum .. _LogDeepToString(data_value, prefix .. "   ")
				string_accum = string_accum .. prefix .. (is_array and "]" or "}") .. "\n"
			end
		else
			--string_accum = string_accum .. prefix .. idx .. "\t= " .. (type(data_value) == "string" and ("\"" .. data_value .. "\"") or data_value) .. "\n"
			string_accum = string_accum .. prefix .. idx .. "\t= " .. "\"" .. tostring(data_value) .. "\"" .. "\n"
		end
	end
	if prefix == "   " then
		string_accum = string_accum .. (type(debugInstance) == "table" and "]" or "}") .. "\n" -- hack for "proving" at end - this is DUMB!
	end
	return string_accum
end


scripthelp_LogDeepString = "Convert a class/array/instance/table to a string"

function LogDeepToString(debugInstance, prefix)
	prefix = prefix or ""
	_LogDeepprint_alreadyseen = {}
	table.insert(_LogDeepprint_alreadyseen, debugInstance)
	return _LogDeepToString(debugInstance, prefix)
end


scripthelp_LogDeepPrint = "Print out a class/array/instance/table to the console"

function LogDeepPrint(debugInstance, prefix)
	prefix = prefix or ""
	LogEndLine(LogDeepToString(debugInstance, prefix))
end

function find_closest_point_on_square_boundary(min_x, min_y, max_x, max_y, point)
    -- Шаг 1: Определение координат заданной точки внутри квадрата
    local x, y = point[1], point[2]
    
    -- Шаг 2: Нахождение ближайшей стороны к точке
    local side = math.min(x - min_x, max_x - x, y - min_y, max_y - y)
    
    -- Шаг 3: Определение расстояния от точки до каждой стороны
    local distance_to_top = y - min_y
    local distance_to_bottom = max_y - y
    local distance_to_left = x - min_x
    local distance_to_right = max_x - x
    
    -- Шаг 4: Нахождение точки на стороне с равным расстоянием
    if side == distance_to_top then
        return {x, min_y, Vector(0,-1,0)}
    elseif side == distance_to_bottom then
        return {x, max_y, Vector(0,1,0)}
    elseif side == distance_to_left then
        return {min_x, y, Vector(-1,0,0)}
    elseif side == distance_to_right then
        return {max_x, y, Vector(1,0,0)}
    end
end

function calculateNormal(min_x, min_y, max_x, max_y, point)
    local x, y = point[1], point[2]

    -- Находим центр квадрата
    local center_x, center_y = (min_x + max_x) / 2, (min_y + max_y) / 2

    -- Вычисляем вектор от центра к точке
    local normal_x = x - center_x
    local normal_y = y - center_y

    -- Определяем, к какой стороне квадрата ближе точка, и нормализуем вектор
    if math.abs(normal_x) > math.abs(normal_y) then
        normal_y = 0
    else
        normal_x = 0
    end

    -- Нормализация вектора
    local length = math.sqrt(normal_x^2 + normal_y^2)
    if length > 0 then
        normal_x = normal_x / length
        normal_y = normal_y / length
    end

    return {normal_x, normal_y}
end

local ActiveRangeIndicators = {} -- player_id -> { ability_name -> particle_id }

function OnToggleAbilityRangeIndicator(event, args)
	local pID = args.PlayerID or args.playerID
	if not pID then return end
	
	local ability_entindex = args.ability_entindex
	if not ability_entindex then return end
	
	local ability = EntIndexToHScript(ability_entindex)
	if not ability or ability:IsNull() then return end
	
	local caster = ability:GetCaster()
	if not caster or caster:IsNull() then return end
	
	-- Verify ownership
	if caster:GetPlayerOwnerID() ~= pID then return end
	
	local player = PlayerResource:GetPlayer(pID)
	if not player then return end
	
	local abilityName = ability:GetAbilityName()
	
	ActiveRangeIndicators[pID] = ActiveRangeIndicators[pID] or {}
	
	if ActiveRangeIndicators[pID][abilityName] then
		-- Remove existing indicator
		ParticleManager:DestroyParticle(ActiveRangeIndicators[pID][abilityName], true)
		ParticleManager:ReleaseParticleIndex(ActiveRangeIndicators[pID][abilityName])
		ActiveRangeIndicators[pID][abilityName] = nil
		print("[RangeIndicator] Removed range indicator for " .. abilityName .. " on player " .. pID)
	else
		-- Create new indicator
		local radius = ability:GetCastRange(caster:GetAbsOrigin(), nil)
		if radius <= 0 then
			radius = ability:GetSpecialValueFor("radius")
		end
		if radius <= 0 then
			radius = ability:GetSpecialValueFor("range")
		end
		if radius <= 0 then
			-- Fallback
			radius = 600
		end
		
		local choice = "custom_range_display_green"
		if _G.Range_PlayerChoices and _G.Range_PlayerChoices[pID] then
			choice = _G.Range_PlayerChoices[pID]
		end
		local pPath = "particles/ui_mouseactions/" .. choice .. "/custom_range_display.vpcf"
		local pfx = ParticleManager:CreateParticleForPlayer(pPath, PATTACH_ABSORIGIN_FOLLOW, caster, player)
		ParticleManager:SetParticleControl(pfx, 1, Vector(radius, 0, 0))
		
		ActiveRangeIndicators[pID][abilityName] = pfx
		print("[RangeIndicator] Created range indicator with radius " .. radius .. " for " .. abilityName .. " on player " .. pID)
	end
end
CustomGameEventManager:RegisterListener("toggle_ability_range_indicator", OnToggleAbilityRangeIndicator)

function OnCustomPingAbility(event, args)
	if not args then return end
	local pID = args.PlayerID or args.playerID
	if not pID then return end
	
	local abilityName = args.abilityName
	local targetPlayerID = args.targetPlayerID or args.targetPlayerid
	local cooldownRemaining = args.cooldownRemaining or 0
	local status = args.status
	
	if not abilityName or not targetPlayerID or not status then 
		print("[OnCustomPingAbility] missing arguments", abilityName, targetPlayerID, status)
		return 
	end
	
	local senderPlayer = PlayerResource:GetPlayer(pID)
	if not senderPlayer then return end
	
	local senderTeam = senderPlayer:GetTeam()
	
	-- Рассылаем событие только игрокам той же команды
	for id = 0, DOTA_MAX_PLAYERS - 1 do
		if PlayerResource:IsValidPlayerID(id) then
			local targetPlayer = PlayerResource:GetPlayer(id)
			if targetPlayer and targetPlayer:GetTeam() == senderTeam then
				CustomGameEventManager:Send_ServerToPlayer(targetPlayer, "custom_ability_ping_client", {
					senderPlayerID = pID,
					targetPlayerID = targetPlayerID,
					abilityName = abilityName,
					cooldownRemaining = cooldownRemaining,
					status = status
				})
			end
		end
	end
end
CustomGameEventManager:RegisterListener("custom_ping_ability", OnCustomPingAbility)

local _time_ping_cooldowns = {}

function OnCustomPingTime(event, args)
	local pID = args.PlayerID or args.playerID
	if not pID then return end
	
	local timeText = args.time
	if not timeText then return end
	
	local now = GameRules:GetGameTime()
	if _time_ping_cooldowns[pID] and (now - _time_ping_cooldowns[pID]) < 5 then
		return
	end
	_time_ping_cooldowns[pID] = now
	
	local player = PlayerResource:GetPlayer(pID)
	if not player then return end
	
	local hero = player:GetAssignedHero()
	local text = "► " .. timeText
	Say(hero, text, true)
end
CustomGameEventManager:RegisterListener("custom_ping_time", OnCustomPingTime)

-- =============================================================================
-- Tools Panel Handlers
-- =============================================================================

_wtf_mode = false
_inf_mana = false
_infinite_goal_limit = false
_no_goal_respawn = false
_forced_training_mode = false

function IsTrainingMode()
	return _forced_training_mode == true
end

local function SendWtfState(player)
	local is_training = IsTrainingMode()
	local data = {
		active = _wtf_mode,
		inf_mana = _inf_mana,
		infinite_goal_limit = _infinite_goal_limit,
		no_goal_respawn = _no_goal_respawn,
		is_debug_allowed = is_training,
		open_panels_by_default = is_training,
	}
	CustomNetTables:SetTableValue("player_physics_stats", "wtf", data)
end

CustomGameEventManager:RegisterListener("toggle_wtf_mode", function(_, args)
	_wtf_mode = not _wtf_mode
	-- WTF: нулевые кулдауны
	local heroes = HeroList:GetAllHeroes()
	for _, hero in ipairs(heroes) do
		if _wtf_mode then
			hero:AddNewModifier(hero, nil, "modifier_unlimited_casting", {})
			hero:SetAbilityPoints(10)
			
			-- Сразу обновляем ману и КД абилок у всех
			hero:SetMana(hero:GetMaxMana())
			for i = 0, hero:GetAbilityCount() - 1 do
				local abil = hero:GetAbilityByIndex(i)
				if abil then abil:EndCooldown() end
			end
		else
			hero:RemoveModifierByName("modifier_unlimited_casting")
		end
	end
	SendWtfState(nil)
end)

CustomGameEventManager:RegisterListener("toggle_inf_mana", function(_, args)
	_inf_mana = not _inf_mana
	SendWtfState(nil)
end)

CustomGameEventManager:RegisterListener("set_infinite_goal_limit", function(_, args)
	_infinite_goal_limit = not _infinite_goal_limit
	if _infinite_goal_limit then
		SCORE_TO_WIN = 9999
	else
		SCORE_TO_WIN = 10
	end
	SendWtfState(nil)
end)

CustomGameEventManager:RegisterListener("toggle_no_goal_respawn", function(_, args)
	_no_goal_respawn = not _no_goal_respawn
	if _no_goal_respawn then
		Banjoball.saved_time_till_next_round = TIME_TILL_NEXT_ROUND
		TIME_TILL_NEXT_ROUND = 0.5
	else
		TIME_TILL_NEXT_ROUND = Banjoball.saved_time_till_next_round or 9
	end
	SendWtfState(nil)
end)

CustomGameEventManager:RegisterListener("trigger_refresh", function(_, args)
	local pID = args.PlayerID
	if not pID then return end
	local player = PlayerResource:GetPlayer(pID)
	if not player then return end
	local hero = player:GetAssignedHero()
	if not hero then return end
	local target = EntIndexToHScript(args.selected_unit or -1)
	if not target or target:IsNull() then
		target = hero
	end
	-- Сбрасываем кулдауны и восстанавливаем ману
	target:SetMana(target:GetMaxMana())
	for i = 0, target:GetAbilityCount() - 1 do
		local abil = target:GetAbilityByIndex(i)
		if abil then abil:EndCooldown() end
	end
end)

CustomGameEventManager:RegisterListener("teleport_to_ball", function(_, args)
	local pID = args.PlayerID
	if not pID then return end
	local player = PlayerResource:GetPlayer(pID)
	if not player then return end
	local hero = player:GetAssignedHero()
	if not hero then return end
	local target = EntIndexToHScript(args.selected_unit or -1)
	if not target or target:IsNull() then
		target = hero
	end
	local ball = Ball and Ball.unit
	if ball and not ball:IsNull() then
		FindClearSpaceForUnit(target, ball:GetAbsOrigin(), true)
	end
end)

CustomGameEventManager:RegisterListener("teleport_ball_to_hero", function(_, args)
	local pID = args.PlayerID
	if not pID then return end
	local player = PlayerResource:GetPlayer(pID)
	if not player then return end
	local hero = player:GetAssignedHero()
	if not hero then return end
	local target = EntIndexToHScript(args.selected_unit or -1)
	if not target or target:IsNull() then
		target = hero
	end
	local ball = Ball and Ball.unit
	if ball and not ball:IsNull() then
		-- Телепортируем мяч чуть впереди героя, а не прямо в него
		-- Это предотвращает мгновенную коллизию и странный удар по герою
		local fv = target:GetForwardVector()
		local targetPos = target:GetAbsOrigin() + Vector(fv.x, fv.y, 0) * 80
		targetPos.z = GROUND_Z + 20

		-- Сбрасываем физику перед телепортом
		ball:StopPhysicsSimulation()
		ball:SetAbsOrigin(targetPos)

		-- Сбрасываем velocity через физику
		if ball.velocity then
			ball.velocity = Vector(0, 0, 0)
		end

		-- Сбрасываем lastPos чтобы SetForwardVector на следующем тике не получил Z-скачок
		ball.lastPos = targetPos

		if ball.controller ~= target then
			ball.controller = nil
		end
		ball.lastMovedBy = target
		ball.lastHitHero = target
		ball.lastHitTime = GameRules:GetGameTime()

		-- Возобновляем физику
		Timers:CreateTimer(0.05, function()
			ball:StartPhysicsSimulation()
			ball:SetPhysicsVelocity(Vector(0, 0, 0))
			ball:SetPhysicsAcceleration(GRAVITY)
		end)
	end
end)

local function GetFreeDummyHeroName()
	local dummyHeroes = {
		"npc_dota_hero_wisp",
		"npc_dota_hero_chen",
		"npc_dota_hero_visage",
		"npc_dota_hero_enigma",
		"npc_dota_hero_techies",
		"npc_dota_hero_crystal_maiden",
		"npc_dota_hero_dazzle",
		"npc_dota_hero_disruptor"
	}
	local heroes = HeroList:GetAllHeroes()
	for _, dummy in ipairs(dummyHeroes) do
		local found = false
		for _, h in ipairs(heroes) do
			if h:GetUnitName() == dummy then
				found = true
				break
			end
		end
		if not found then
			return dummy
		end
	end
	return "npc_dota_hero_wisp"
end

CustomGameEventManager:RegisterListener("spawn_debug_hero", function(_, args)
	local pID = args.PlayerID
	if not pID then return end
	local team = args.team
	local heroName = args.hero_name
	if not heroName then return end

	local now = GameRules:GetGameTime()
	if _G.LastSpawnDebugHeroTime and (now - _G.LastSpawnDebugHeroTime < 0.1) then
		print("[SPAWN] Throttled duplicate spawn event for", heroName)
		return
	end
	_G.LastSpawnDebugHeroTime = now

	local spawnTeam = (team == "ally") and PlayerResource:GetTeam(pID) or (PlayerResource:GetTeam(pID) == DOTA_TEAM_GOODGUYS and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS)
	local spawnPos = Vector(0, 0, 0)
	local player = PlayerResource:GetPlayer(pID)
	if player then
		local hero = player:GetAssignedHero()
		if hero then spawnPos = hero:GetAbsOrigin() + RandomVector(200) end
	end

	local heroes = HeroList:GetAllHeroes()
	local teamHeroCount = 0
	for _, h in ipairs(heroes) do
		if h:IsRealHero() and h:GetTeam() == spawnTeam and not h.tempremoved and h:IsAlive() then
			local pid = h:GetPlayerOwnerID()
			local isActive = false
			if pid and pid ~= -1 then
				isActive = (PlayerResource:GetSelectedHeroEntity(pid) == h)
			end
			if isActive then
				teamHeroCount = teamHeroCount + 1
			end
		end
	end
	if teamHeroCount >= 5 then
		GameRules:SendCustomMessage("#banjoball_debug_error_team_limit", 0, 0)
		return
	end

	local dummyHero = GetFreeDummyHeroName()
	_G.SpawningDebugHeroName = dummyHero
	_G.TargetDebugHeroName = heroName
	_G.SpawningDebugHeroTeam = spawnTeam
	_G.SpawningDebugHeroPos = spawnPos

	-- Разрешаем выбор одинаковых героев и сбрасываем размер команды на 5
	GameRules:SetSameHeroSelectionEnabled(true)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, 5)
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 5)

	local teamStr = (spawnTeam == DOTA_TEAM_GOODGUYS) and "radiant" or "dire"
	local ok, err = pcall(function()
		Tutorial:AddBot(dummyHero, teamStr, "", true)
	end)

	if ok then
		print(string.format("[SPAWN_BOT] Tutorial:AddBot %s to team %s", heroName, teamStr))
		local playerName = PlayerResource:GetPlayerName(pID) or "Игрок"
		local cleanName = heroName:gsub("npc_dota_hero_", "")
		cleanName = cleanName:sub(1,1):upper() .. cleanName:sub(2)
		local chatTeamStr = (spawnTeam == DOTA_TEAM_GOODGUYS) and "Radiant" or "Dire"
		local chatMsg = string.format("%s создал бота %s за %s", playerName, cleanName, chatTeamStr)
		GameRules:SendCustomMessage(chatMsg, 0, 0)
	else
		print(string.format("[SPAWN_BOT] FAILED to add bot %s: %s", heroName, tostring(err)))
		GameRules:SendCustomMessage("#banjoball_debug_error_spawn_failed", 0, 0)
	end
end)

CustomGameEventManager:RegisterListener("remove_selected_bot", function(_, args)
	local pID = args.PlayerID
	if not pID then return end
	local entindex = args.selected_unit
	if not entindex then return end

	local hero = EntIndexToHScript(entindex)
	if hero and not hero:IsNull() and hero.isBanjoHero then
		local botPlayerID = hero:GetPlayerOwnerID()
		
		-- Проверяем, что это не реальный игрок-человек
		local isRealPlayer = false
		if botPlayerID and botPlayerID ~= -1 then
			if PlayerResource:IsValidPlayerID(botPlayerID) and not PlayerResource:IsFakeClient(botPlayerID) then
				isRealPlayer = true
			end
		end

		if isRealPlayer then
			GameRules:SendCustomMessage("#banjoball_debug_error_remove_player", 0, 0)
			return
		end

		if botPlayerID and botPlayerID ~= -1 then
			local removed = CustomNetTables:GetTableValue("game_state", "removed_bots") or {}
			removed[tostring(botPlayerID)] = 1
			CustomNetTables:SetTableValue("game_state", "removed_bots", removed)
		end

		if Ball.unit and Ball.unit.controller == hero then
			Ball.unit.controller = nil
			Ball.unit.lastMovedBy = nil
		end

		if hero.colliderID and Banjoball.colliderFilter then
			Banjoball.colliderFilter[hero.colliderID] = nil
		end

		if hero.teamGlow then
			ParticleManager:DestroyParticle(hero.teamGlow, true)
			ParticleManager:ReleaseParticleIndex(hero.teamGlow)
		end
		if hero.shadow then
			ParticleManager:DestroyParticle(hero.shadow, true)
			ParticleManager:ReleaseParticleIndex(hero.shadow)
		end
		if hero.trackedParticle then
			ParticleManager:DestroyParticle(hero.trackedParticle, true)
			ParticleManager:ReleaseParticleIndex(hero.trackedParticle)
		end

		for i = #Banjoball.vHeroes, 1, -1 do
			if Banjoball.vHeroes[i] == hero then
				table.remove(Banjoball.vHeroes, i)
				break
			end
		end

		local playerName = PlayerResource:GetPlayerName(pID) or "Игрок"
		local heroNameClean = hero:GetUnitName():gsub("npc_dota_hero_", "")
		heroNameClean = heroNameClean:sub(1,1):upper() .. heroNameClean:sub(2)

		hero:SetAbsOrigin(Vector(-3100, 2000, 0))
		UTIL_Remove(hero)

		GameRules:SendCustomMessage(string.format("%s удалил бота %s", playerName, heroNameClean), 0, 0)
		
		CustomGameEventManager:Send_ServerToAllClients("update_hero_bar", {})
	else
		GameRules:SendCustomMessage("#banjoball_debug_error_remove_only_bots", 0, 0)
	end
end)

-- Инициализируем WTF-флаги как только PlayerResource заполнен (игроки зарегистрированы).
-- Polling каждые 0.5с гарантирует срабатывание ДО спавна героев,
-- в отличие от game_rules_state_change который может прийти позже.
local _wtf_init_done = false
Timers:CreateTimer(0.5, function()
	if _wtf_init_done then return end

	-- Считаем зарегистрированных игроков
	local real_players = 0
	for i = 0, 23 do
		if PlayerResource:IsValidPlayerID(i) and not PlayerResource:IsBroadcaster(i) then
			real_players = real_players + 1
		end
	end

	-- Ждём пока появится хотя бы 1 игрок и закончится фаза выбора героев (перейдем в PRE_GAME)
	if real_players == 0 or GameRules:State_Get() < DOTA_GAMERULES_STATE_PRE_GAME then
		return 0.5 -- повторить через 0.5с
	end

	_wtf_init_done = true

	if _forced_training_mode then
		GameRules:SendCustomMessage("Активирован принудительный режим тренировки по голосованию!", 0, 0)
		_wtf_mode = DEFAULT_WTF_MODE == true
		_inf_mana = DEFAULT_INF_MANA == true
		_no_goal_respawn = DEFAULT_NO_GOAL_RESPAWN == true
		_infinite_goal_limit = DEFAULT_INFINITE_GOAL_LIMIT == true

		if _wtf_mode then
			-- WTF: нулевые кулдауны
			local heroes = HeroList:GetAllHeroes()
			for _, hero in ipairs(heroes) do
				hero:AddNewModifier(hero, nil, "modifier_unlimited_casting", {})
				hero:SetAbilityPoints(10)
				hero:SetMana(hero:GetMaxMana())
				for i = 0, hero:GetAbilityCount() - 1 do
					local abil = hero:GetAbilityByIndex(i)
					if abil then abil:EndCooldown() end
				end
			end
		end

		if _infinite_goal_limit then
			SCORE_TO_WIN = 9999
		else
			SCORE_TO_WIN = 10
		end

		if _no_goal_respawn then
			if Banjoball then
				Banjoball.saved_time_till_next_round = TIME_TILL_NEXT_ROUND
			end
			TIME_TILL_NEXT_ROUND = 0.5
		end
	else
		_wtf_mode = false
		_inf_mana = false
		_no_goal_respawn = false
		_infinite_goal_limit = false
		SCORE_TO_WIN = 10
	end

	SendWtfState(nil)
end)

CustomGameEventManager:RegisterListener("toggle_pause", function(_, args)
	local isPaused = GameRules:IsGamePaused()
	PauseGame(not isPaused)
end)


CustomGameEventManager:RegisterListener("pause_one_tick", function(_, args)
	_G.TicksToPause = 5
	PauseGame(false)
end)


