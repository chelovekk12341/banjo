print('[TEMPEST_DOUBLE] mechanics/tempest_double.lua loaded')

function Banjoball:InitTempestDouble(tempest, caster)
	tempest.isBanjoHero = true
	tempest.pp_collisions = {}
	tempest.owner = caster
	tempest.plyID = caster.plyID or caster:GetPlayerOwnerID()
	tempest.gc = caster.gc
	tempest.playerName = caster.playerName
	
	-- Копируем цвета команды и инициализируем статы/флаги
	tempest.colArr = caster.colArr
	tempest.colHex = caster.colHex
	tempest.colStr = caster.colStr
	tempest.ballCol = caster.ballCol
	tempest.ballProc = false
	tempest.noball = false
	SetupStats(tempest)
	
	-- Настраиваем физику
	self:SetupPhysicsSettings(tempest)
	
	tempest.collisionRadius = HERO_DEFAULT_RADIUS
	tempest.BallCollRadius = BALL_COLLISION_DIST	 
	tempest.kickPower = KICK_VELOCITY
	tempest.kickZ = KICK_Z
	tempest.Height = BALL_COLLISION_Z_TOP
	tempest.collisionEnabled = true
	tempest.lastPPCollisionTime = GameRules:GetGameTime()
	tempest.skewerAffected = 0
	
	-- Коллизии
	tempest.colliderID = DoUniqueString("a")
	self.colliderFilter[tempest.colliderID] = tempest
	self:SetupPersonalColliders(tempest)
	tempest:SetHullRadius(HERO_HULL_SIZE)
	
	-- Способности
	InitAbilities(tempest)

	-- Инициализация параметров спринта и маны
	tempest.SprintBonus = SPRINT_MAXIMAL_BONUS
	tempest.SprintTime = SPRINT_FAST_TIME
	tempest.SprintLast = 0
	tempest.sprintFinihsedAt = -10
	tempest.SprintMult = 0
	tempest.manaMinus = false
	tempest.manaReg = MANA_REG_SPRINT
	tempest.manaDrain = MANA_DRAIN_SPRINT
	tempest.drainMult = 1
	tempest.size = HERO_DEFAULT_RADIUS
	tempest.ballSlow = BALL_SLOW
	tempest.password = true
	
	tempest.sprintBreak = "surge_break"

	-- Гарантируем, что у копии есть все нужные способности
	local surge_abil = tempest:FindAbilityByName("surge")
	if not surge_abil then
		tempest:AddAbility("surge")
		surge_abil = tempest:FindAbilityByName("surge")
	end
	if surge_abil then surge_abil:SetLevel(1) end

	local surge_break_abil = tempest:FindAbilityByName("surge_break")
	if not surge_break_abil then
		tempest:AddAbility("surge_break")
		surge_break_abil = tempest:FindAbilityByName("surge_break")
	end
	if surge_break_abil then surge_break_abil:SetLevel(1) end

	local cross_abil = tempest:FindAbilityByName("cross")
	if not cross_abil then
		tempest:AddAbility("cross")
		cross_abil = tempest:FindAbilityByName("cross")
	end
	if cross_abil then cross_abil:SetLevel(1) end

	local cross_finish_abil = tempest:FindAbilityByName("cross_finish")
	if not cross_finish_abil then
		tempest:AddAbility("cross_finish")
		cross_finish_abil = tempest:FindAbilityByName("cross_finish")
	end
	if cross_finish_abil then cross_finish_abil:SetLevel(1) end

	-- Синхронизируем состояние способностей с создателем
	local casterE = caster:GetAbilityByIndex(ABILITY_SLOT_E)
	local casterE_name = casterE and casterE:GetAbilityName() or "surge"
	
	local casterD = caster:GetAbilityByIndex(ABILITY_SLOT_D)
	local casterD_name = casterD and casterD:GetAbilityName() or "cross"

	-- Настраиваем слот E (спринт)
	if casterE_name == "surge_break" then
		surge_abil:SetHidden(true)
		surge_break_abil:SetHidden(false)
		SwapAbilities(tempest, "surge_break", "surge", ABILITY_SLOT_E)
	else
		surge_break_abil:SetHidden(true)
		surge_abil:SetHidden(false)
		SwapAbilities(tempest, "surge", "surge_break", ABILITY_SLOT_E)
	end

	-- Настраиваем слот D (навес)
	if casterD_name == "cross_finish" then
		cross_abil:SetHidden(true)
		cross_finish_abil:SetHidden(false)
		SwapAbilities(tempest, "cross_finish", "cross", ABILITY_SLOT_D)
	else
		cross_finish_abil:SetHidden(true)
		cross_abil:SetHidden(false)
		SwapAbilities(tempest, "cross", "cross_finish", ABILITY_SLOT_D)
	end
	
	-- Подключение к физике фреймов
	tempest:OnPhysicsFrame(function(unit)
		Banjoball:OnMyPhysicsFrame(tempest)
	end)
	
	-- Метод OnThink для копии (защита от stuck)
	tempest.StuckTicks = 0
	tempest.OnThink = function(hero)
		if hero.tempremoved then return end
		local pos = hero:GetAbsOrigin()
		
		-- Проверка выхода за пределы поля
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
	end

	-- Добавляем в vHeroes для взаимодействия с мячом и UpdateMana
	local found = false
	for _, h in ipairs(self.vHeroes) do
		if h == tempest then
			found = true
			break
		end
	end
	if not found then
		table.insert(self.vHeroes, tempest)
	end
end

function Banjoball:RemoveTempestDouble(tempest)
	if not tempest or tempest:IsNull() then return end
	
	-- Удаляем из vHeroes
	for i = #self.vHeroes, 1, -1 do
		if self.vHeroes[i] == tempest then
			table.remove(self.vHeroes, i)
			break
		end
	end
	
	-- Удаляем из colliderFilter
	if tempest.colliderID then
		self.colliderFilter[tempest.colliderID] = nil
	end
end
