LinkLuaModifier("modifier_void_spirit_dissimilate_oow", "abilities/dissimilate", LUA_MODIFIER_MOTION_NONE)

dissimilate = class({})

function dissimilate:Precache(context)
    PrecacheResource("particle", "particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate_dmg.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate_exit.vpcf", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_void_spirit.vsndevts", context)
end

function dissimilate:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()

    -- Если уже активен модификатор dissimilate, значит это повторное нажатие для выхода
    if caster:HasModifier("modifier_void_spirit_dissimilate_oow") then
        caster:RemoveModifierByName("modifier_void_spirit_dissimilate_oow")
        return
    end

    -- Ручная проверка кулдауна (обходит WTF-модификатор)
    if not _wtf_mode and self._cd_expires and GameRules:GetGameTime() < self._cd_expires then
        return
    end

    local position = caster:GetAbsOrigin()
    
    local portals = self:GetSpecialValueFor("portals_per_ring") or 6
    local angle = self:GetSpecialValueFor("angle_per_ring_portal") or 60
    local distance = self:GetSpecialValueFor("first_ring_distance_offset") or 450
    local direction = caster:GetForwardVector()
    local rings = self:GetSpecialValueFor("outer_rings") or 1
    local phaseDuration = self:GetSpecialValueFor("phase_duration") or 1.3
    
    self.portals = {}
    
    -- Создаем центральный портал (активный по умолчанию)
    self:CreatePortal(position, true)
    
    -- Создаем порталы внешнего кольца
    local currDist = 0
    for i = 1, rings do
        currDist = currDist + distance
        for j = 1, portals do
            direction = RotateVector2D(direction, math.rad(angle))
            local newPos = position + direction * currDist
            self:CreatePortal(newPos, false)
        end
    end

    caster:Stop()
    caster:Interrupt()
    caster:Hold()

    -- Запускаем стандартный кулдаун (для UI). В WTF обнуляется, но ручной блок выше всё равно работает.
    local cd = self:GetSpecialValueFor("cooldown") or 32
    if _wtf_mode then
        self:StartCooldown(0)
        self._cd_expires = nil
    else
        self:StartCooldown(cd)
        self._cd_expires = GameRules:GetGameTime() + cd
    end

    caster:AddNewModifier(caster, self, "modifier_void_spirit_dissimilate_oow", {duration = phaseDuration})
    EmitSoundOn("Hero_VoidSpirit.Dissimilate.Cast", caster)
end

function dissimilate:CreatePortal(position, active)
    local caster = self:GetCaster()
    local radius = self:GetSpecialValueFor("portal_radius")
    if radius <= 0 then radius = self:GetSpecialValueFor("damage_radius") end
    if radius <= 0 then radius = 275 end
    local caster_team = caster:GetTeamNumber()
    
    -- Блокируем создание порталов только у вражеских ворот (предел по X = 2500)
    if caster_team == DOTA_TEAM_GOODGUYS and position.x > 2500 then
        return
    elseif caster_team == DOTA_TEAM_BADGUYS and position.x < -2500 then
        return
    end

    local ground_pos = GetGroundPosition(position, caster)
    
    -- Создаем партикль только для своей команды (активный/неактивный в зависимости от аргумента active)
    local fx = ParticleManager:CreateParticleForTeam("particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate.vpcf", PATTACH_WORLDORIGIN, caster, caster_team)
    ParticleManager:SetParticleControl(fx, 0, ground_pos)
    ParticleManager:SetParticleControl(fx, 1, Vector(radius, 0, 0))
    ParticleManager:SetParticleControl(fx, 2, Vector(active and 1 or 0, 0, 0))
    
    -- Создаем партикль для вражеской команды (всегда неактивный)
    local enemy_team = (caster_team == DOTA_TEAM_GOODGUYS) and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS
    local fx_enemy = ParticleManager:CreateParticleForTeam("particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate.vpcf", PATTACH_WORLDORIGIN, caster, enemy_team)
    ParticleManager:SetParticleControl(fx_enemy, 0, ground_pos)
    ParticleManager:SetParticleControl(fx_enemy, 1, Vector(radius, 0, 0))
    ParticleManager:SetParticleControl(fx_enemy, 2, Vector(0, 0, 0)) -- всегда выключен (враги не видят подсветку)
    
    self.portals[fx] = {position = ground_pos, active = active, enemy_fx = fx_enemy}
end

function dissimilate:PhaseIn(position, parent, bTeleport)
    local caster = self:GetCaster()
    local radius = self:GetSpecialValueFor("portal_radius")
    if radius <= 0 then radius = self:GetSpecialValueFor("damage_radius") end
    if radius <= 0 then radius = 275 end
    
    -- Выбиваем мяч, если он в радиусе и не имеет контроллера (закомментировано по требованию)
    -- local ball = Ball.unit
    -- if ball and not ball.controller then
    --     local to_ball = ball:GetAbsOrigin() - position
    --     local dist = to_ball:Length()
    --     if dist <= radius then
    --         local push_dir = to_ball:Normalized()
    --         if dist < 10 then push_dir = caster:GetForwardVector() end
    --         
    --         if not ball.SetPhysicsVelocity then
    --             Banjoball:SetupPhysicsSettings(ball)
    --         end
    --         ball:AddPhysicsVelocity(push_dir * 1200 + Vector(0, 0, 400))
    --     end
    -- end
    
    -- Эффекты урона и телепорта
    local fx_dmg = ParticleManager:CreateParticle("particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate_dmg.vpcf", PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(fx_dmg, 0, position)
    ParticleManager:SetParticleControl(fx_dmg, 1, Vector(radius/2, 1, 1))
    ParticleManager:ReleaseParticleIndex(fx_dmg)
    
    local fx_exit = ParticleManager:CreateParticle("particles/units/heroes/hero_void_spirit/dissimilate/void_spirit_dissimilate_exit.vpcf", PATTACH_POINT_FOLLOW, parent or caster)
    ParticleManager:ReleaseParticleIndex(fx_exit)
    
    if bTeleport == true or bTeleport == nil then
        FindClearSpaceForUnit(parent or caster, position, true)
        EmitSoundOn("Hero_VoidSpirit.Dissimilate.TeleportIn", parent or caster)
    end
end

--------------------------------------------------------------------------------

modifier_void_spirit_dissimilate_oow = class({})

function modifier_void_spirit_dissimilate_oow:IsHidden() return true end

function modifier_void_spirit_dissimilate_oow:CheckState()
    return {
        [MODIFIER_STATE_ROOTED] = true,
        [MODIFIER_STATE_DISARMED] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_OUT_OF_GAME] = true,
        [MODIFIER_STATE_UNTARGETABLE] = true,
        [MODIFIER_STATE_INVULNERABLE] = true,
    }
end

function modifier_void_spirit_dissimilate_oow:OnCreated()
    if not IsServer() then return end
    
    local caster = self:GetCaster()
    caster:AddNoDraw()

    -- Добавляем вспомогательную способность выхода и делаем её активной
    local exit_abil = caster:FindAbilityByName("dissimilate_exit")
    if not exit_abil then
        exit_abil = caster:AddAbility("dissimilate_exit")
        if exit_abil then exit_abil:SetLevel(1) end
    end
    
    if exit_abil then
        caster:SwapAbilities("dissimilate", "dissimilate_exit", false, true)
    end

    -- Деактивируем все способности, кроме resonant_pulse и dissimilate_exit
    for i = 0, caster:GetAbilityCount() - 1 do
        local ability = caster:GetAbilityByIndex(i)
        if ability then
            local name = ability:GetAbilityName()
            if name ~= "resonant_pulse" and name ~= "dissimilate_exit" then
                ability:SetActivated(false)
            end
        end
    end
    
    local ball = Ball.unit
    if ball and not ball:IsNull() and ball.controller == caster then
        ball:AddNoDraw()
        if ball.particleDummy then
            ball.particleDummy:AddNoDraw()
        end
        if ball.ballParticle then
            ParticleManager:DestroyParticle(ball.ballParticle, true)
            ball.ballParticle = nil
        end
        ball.dissimilate_hidden = true
        self.had_ball = true
    end
end

function modifier_void_spirit_dissimilate_oow:OnDestroy()
    if not IsServer() then return end
    
    local caster = self:GetCaster()
    local ability = self:GetAbility()
    
    caster:RemoveNoDraw()

    -- Возвращаем основную способность Dissimilate на панель
    if caster:FindAbilityByName("dissimilate_exit") then
        caster:SwapAbilities("dissimilate_exit", "dissimilate", false, true)
        caster:RemoveAbility("dissimilate_exit")
    end
    
    -- Включаем все способности обратно
    for i = 0, caster:GetAbilityCount() - 1 do
        local abilityObj = caster:GetAbilityByIndex(i)
        if abilityObj then
            abilityObj:SetActivated(true)
        end
    end
    
    -- Явно активируем Dissimilate на всякий случай
    local dissimilate_ability = caster:FindAbilityByName("dissimilate")
    if dissimilate_ability then
        dissimilate_ability:SetActivated(true)
    end
    
    local ball = Ball.unit
    if ball and not ball:IsNull() and self.had_ball then
        ball:RemoveNoDraw()
        if ball.particleDummy then
            ball.particleDummy:RemoveNoDraw()
        end
        ball.dissimilate_hidden = nil
    end
    
    -- Телепортируем в активный портал и очищаем эффекты
    if ability and not ability:IsNull() and ability.portals then
        for portalFx, portalData in pairs(ability.portals) do
            if portalData.active then
                ability:PhaseIn(portalData.position)
            end
            ParticleManager:DestroyParticle(portalFx, true)
            ParticleManager:ReleaseParticleIndex(portalFx)

            if portalData.enemy_fx then
                ParticleManager:DestroyParticle(portalData.enemy_fx, true)
                ParticleManager:ReleaseParticleIndex(portalData.enemy_fx)
            end
        end
    end
    
end

function modifier_void_spirit_dissimilate_oow:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ORDER
    }
end

function modifier_void_spirit_dissimilate_oow:OnOrder(params)
    if params.unit == self:GetParent() then
        if params.order_type == DOTA_UNIT_ORDER_STOP or params.order_type == DOTA_UNIT_ORDER_HOLD_POSITION then
            self:Destroy()
        elseif params.new_pos ~= Vector(0, 0, 0) or params.target then
            local ability = self:GetAbility()
            if not ability or ability:IsNull() or not ability.portals then return end
            
            -- Вычисляем позицию клика
            local position = params.new_pos
            if not position or (position.x == 0 and position.y == 0 and position.z == 0) then
                position = params.unit:GetLastMovePosition()
            end
            
            -- Находим ближайший портал
            local nearestPortal
            local nearestDistance = 99999
            for fx, portalData in pairs(ability.portals) do
                portalData.active = false
                ParticleManager:SetParticleControl(fx, 2, Vector(0, 0, 0))
                local dist = (portalData.position - position):Length()
                if dist < nearestDistance then
                    nearestPortal = fx
                    nearestDistance = dist
                end
            end
            
            -- Делаем его активным
            if nearestPortal then
                ability.portals[nearestPortal].active = true
                ParticleManager:SetParticleControl(nearestPortal, 2, Vector(1, 0, 0))
            end
        end
    end
end
