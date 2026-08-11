banjoball_tackle = class({})

function banjoball_tackle:OnSpellStart()
    local caster = self:GetCaster()
    local target_point = self:GetCursorPosition()

    local direction = target_point - caster:GetAbsOrigin()
    direction.z = 0

    if direction:Length2D() <= 1 then
        direction = caster:GetForwardVector()
        direction.z = 0
    end

    direction = direction:Normalized()

    caster.tackle_direction = direction
    caster.tackle_end_time = GameRules:GetGameTime() + self:GetSpecialValueFor("duration")
    caster.isUsingTackle = true

    caster:SetForwardVector(direction)

    -- Отключаем обычные столкновения с игроками
    caster.collisionEnabled = false

    self:StartTackle(caster)
end


function banjoball_tackle:StartTackle(caster)
    local speed = self:GetSpecialValueFor("speed")
    local radius = self:GetSpecialValueFor("radius")

    local tick_rate = 0.03
    local distance_per_tick = speed * tick_rate

    Timers:CreateTimer(function()

        if not caster or caster:IsNull() or not caster:IsAlive() then
            return nil
        end

        if not caster.isUsingTackle then
            caster.collisionEnabled = true
            caster:SetPhysicsVelocity(Vector(0, 0, 0))
            return nil
        end

        local current_time = GameRules:GetGameTime()

        if current_time >= caster.tackle_end_time then
            caster.isUsingTackle = false
            caster.collisionEnabled = true
            caster:SetPhysicsVelocity(Vector(0, 0, 0))
            return nil
        end

        local direction = caster.tackle_direction
        local current_pos = caster:GetAbsOrigin()
        local next_pos = current_pos + direction * distance_per_tick

        -- Не позволяем выехать за пределы футбольного поля
        if not IsPointOnField(next_pos) then
            caster.isUsingTackle = false
            caster.collisionEnabled = true
            caster:SetPhysicsVelocity(Vector(0, 0, 0))
            return nil
        end

        caster:SetAbsOrigin(next_pos)
        caster:SetForwardVector(direction)

        -- Ищем игроков рядом с подкатом
        local enemies = FindUnitsInRadius(
            caster:GetTeam(),
            next_pos,
            nil,
            radius,
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_HERO,
            DOTA_UNIT_TARGET_FLAG_NONE,
            FIND_ANY_ORDER,
            false
        )

        for _, enemy in ipairs(enemies) do
            if enemy
                and not enemy:IsNull()
                and enemy:IsAlive()
                and enemy ~= caster
            then

                local ball = Ball.unit

                -- Именно этот противник сейчас владеет мячом
                if ball
                    and not ball:IsNull()
                    and ball.controller == enemy
                then

                    -- Выбиваем мяч в направлении подката
                    KickBall({
                        hero = caster,
                        xy_velocity = 650,
                        z_velocity = 30,
                        direction = direction,
                        type = 3,
                        keys = {
                            target_points = {
                                ball:GetAbsOrigin() + direction * 100
                            }
                        }
                    })

                    -- Небольшой запрет на мгновенный обратный подбор
                    enemy:AddNewModifier(
                        enemy,
                        nil,
                        "modifier_ball_catching_debuff",
                        {duration = 0.25}
                    )

                    -- Подкат заканчивается после успешного отбора
                    caster.isUsingTackle = false
                    caster.collisionEnabled = true
                    caster:SetPhysicsVelocity(Vector(0, 0, 0))

                    return nil
                end
            end
        end

        return tick_rate
    end)
end