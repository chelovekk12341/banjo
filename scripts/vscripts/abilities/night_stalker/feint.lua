feint = class({})

function feint:OnSpellStart()
    -- Getting positions
    local caster = self:GetCaster()
    local casterPos = caster:GetAbsOrigin()
    local cursorPos = self:GetCursorPosition()
    cursorPos.z = casterPos.z

    local feintDir = cursorPos - casterPos
    local distance = feintDir:Length()

    local dir = caster:GetForwardVector()
    if distance > 1 then
        dir = feintDir:Normalized()
    end

    caster:Stop()
    caster:SetForwardVector(dir)
    caster:FaceTowards(cursorPos)

    -- Propel the hero directly towards the cursor
    caster:AddPhysicsVelocity(dir * FEINT_PUSH)

    print("Feint Casted")
end

function feint:GetCastRange(vLocation, hTarget)
    return self:GetSpecialValueFor("pushDistance")
end
