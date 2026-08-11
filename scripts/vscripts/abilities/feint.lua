feint = class({})

function feint:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()
    local cursor = self:GetCursorPosition()

    -- Эффект финта (Phantom Assassin Active Start Streak)
    local p_idx = ParticleManager:CreateParticle("particles/heroes/night_stalker/phantom_assassin_active_start_streak.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
    ParticleManager:ReleaseParticleIndex(p_idx)

    -- Направление к курсору (только XY)
    local dir = cursor - caster:GetAbsOrigin()
    dir.z = 0
    if dir:Length() < 1 then return end
    dir = dir:Normalized()

    -- Приказ идти к точке курсора (переопределяет старый приказ)
    ExecuteOrderFromTable({
        UnitIndex = caster:GetEntityIndex(),
        OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        Position  = cursor,
        Queue     = false,
    })

    -- Лёгкий толчок в направлении финта
    local impulse = self:GetSpecialValueFor("impulse") or 150
    local curVel = caster:GetPhysicsVelocity()
    caster:SetPhysicsVelocity(Vector(
        curVel.x + dir.x * impulse,
        curVel.y + dir.y * impulse,
        curVel.z
    ))

    -- Удерживаем разворот несколько тиков, пока физика не выровняет направление по скорости
    local ticks = 6
    Timers:CreateTimer(0, function()
        ticks = ticks - 1
        if ticks <= 0 or not caster or caster:IsNull() then return end
        caster:SetForwardVector(dir)
        return FRAME_TIME
    end)
end