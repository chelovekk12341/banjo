resonant_pulse = class({})

function resonant_pulse:Precache(context)
    PrecacheResource("particle", "particles/units/heroes/hero_void_spirit/pulse/void_spirit_pulse.vpcf", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_void_spirit.vsndevts", context)
end

function resonant_pulse:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()
    local radius = self:GetSpecialValueFor("radius") or 500
    local speed = self:GetSpecialValueFor("speed") or 1200
    local pull_force = self:GetSpecialValueFor("pull_force") or 900
    local ball_pull_force = self:GetSpecialValueFor("ball_pull_force") or 1100

    local origin = caster:GetAbsOrigin()
    
    -- Если активен Dissimilate, используем координаты выбранного портала в качестве центра волны
    if caster:HasModifier("modifier_void_spirit_dissimilate_oow") then
        local dissimilate_ability = caster:FindAbilityByName("dissimilate")
        if dissimilate_ability and dissimilate_ability.portals then
            for _, portalData in pairs(dissimilate_ability.portals) do
                if portalData.active then
                    origin = portalData.position
                    break
                end
            end
        end
    end

    -- Звуки каста
    caster:EmitSound("Hero_VoidSpirit.Pulse")
    caster:EmitSound("Hero_VoidSpirit.Pulse.Cast")

    -- Партикль расширяющегося импульса (создаем в мировых координатах, чтобы его не скрывало при AddNoDraw)
    local pulse_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_void_spirit/pulse/void_spirit_pulse.vpcf", PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(pulse_pfx, 0, origin)
    ParticleManager:SetParticleControl(pulse_pfx, 1, Vector(radius, speed, 0))

    local current_radius = 0
    local hit_units = {}
    local time_step = 0.03
    local max_time = 0.75 -- Волна держится на 20% дольше предыдущего времени (0.625 * 1.2)
    local elapsed_time = 0

    local ball = Ball.unit

    Timers:CreateTimer(time_step, function()
        if not caster or caster:IsNull() or not caster:IsAlive() then
            ParticleManager:DestroyParticle(pulse_pfx, true)
            ParticleManager:ReleaseParticleIndex(pulse_pfx)
            return nil
        end

        elapsed_time = elapsed_time + time_step
        current_radius = speed * elapsed_time
        if current_radius > radius then
            current_radius = radius
        end

        -- Обновляем origin на каждом шаге таймера, чтобы щит следовал за героем
        origin = caster:GetAbsOrigin()
        if caster:HasModifier("modifier_void_spirit_dissimilate_oow") then
            local dissimilate_ability = caster:FindAbilityByName("dissimilate")
            if dissimilate_ability and dissimilate_ability.portals then
                for _, portalData in pairs(dissimilate_ability.portals) do
                    if portalData.active then
                        origin = portalData.position
                        break
                    end
                end
            end
        end

        ParticleManager:SetParticleControl(pulse_pfx, 0, origin)

        -- Поиск врагов в текущем радиусе расширения относительно вычисленного центра
        local enemies = FindUnitsInRadius(
            caster:GetTeamNumber(),
            origin,
            nil,
            current_radius,
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
            DOTA_UNIT_TARGET_FLAG_NONE,
            FIND_ANY_ORDER,
            false
        )

        for _, enemy in ipairs(enemies) do
            if enemy ~= ball and not hit_units[enemy] then
                hit_units[enemy] = true
                
                -- Вратаря не отталкиваем, а также никого во вражеских воротах (в своих отталкиваем)
                local enemy_goal_team = GetGoalUnitIsWithin(enemy)
                local is_in_enemy_goal = (enemy_goal_team and enemy_goal_team ~= caster:GetTeamNumber())
                if enemy:IsHero() and not (enemy.goalie or (enemy.HasModifier and enemy:HasModifier("modifier_goalie"))) and not is_in_enemy_goal then
                    local dir = (enemy:GetAbsOrigin() - origin):Normalized()
                    
                    if not enemy.SetPhysicsVelocity then
                        Banjoball:SetupPhysicsSettings(enemy)
                    end
                    enemy:AddPhysicsVelocity(dir * pull_force)

                    -- Восстанавливаем 30 маны за оттолкнутого героя
                    caster:GiveMana(30)
                    print(string.format("[ResonantPulse] Pushed enemy %s, restored 30 mana. Caster mana: %d", enemy:GetUnitName(), caster:GetMana()))
                end

                -- Звук попадания
                EmitSoundOn("Hero_VoidSpirit.Pulse.Target", enemy)
            end
        end

        -- Поиск и притягивание свободного мяча относительно вычисленного центра
        local ball_goal_team = GetGoalUnitIsWithin(ball)
        local ball_in_enemy_goal = (ball_goal_team and ball_goal_team ~= caster:GetTeamNumber())
        if ball and not ball:IsNull() and not hit_units[ball] and not ball.controller and not ball_in_enemy_goal then
            local to_ball = ball:GetAbsOrigin() - origin
            local dist = to_ball:Length()
            if dist <= current_radius then
                hit_units[ball] = true

                local pull_dir = -to_ball:Normalized() -- в сторону вычисленного центра

                if not ball.SetPhysicsVelocity then
                    Banjoball:SetupPhysicsSettings(ball)
                end
                
                -- Притягиваем мяч к вычисленному центру
                ball:AddPhysicsVelocity(pull_dir * ball_pull_force)

                -- Восстанавливаем 30 маны за притянутый мяч
                caster:GiveMana(30)
                print(string.format("[ResonantPulse] Pulled ball, restored 30 mana. Caster mana: %d", caster:GetMana()))
                
                EmitSoundOn("Hero_VoidSpirit.Pulse.Target", ball)
            end
        end

        if elapsed_time >= max_time then
            ParticleManager:DestroyParticle(pulse_pfx, false)
            ParticleManager:ReleaseParticleIndex(pulse_pfx)
            return nil
        end

        return time_step
    end)
end
