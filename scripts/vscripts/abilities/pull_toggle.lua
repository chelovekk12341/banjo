pull_toggle = class({})

function pull_toggle:OnToggle()
    local caster = self:GetCaster()

    if self:GetToggleState() then
        caster.pullPower = PULL_ACCEL_FORCE * PULL_DASH_MULT
        caster:EmitSound("lina_accel")
    else
        caster.pullPower = PULL_ACCEL_FORCE
    end
end
