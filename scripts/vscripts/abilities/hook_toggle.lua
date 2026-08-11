hook_toggle = class({})

function hook_toggle:OnToggle()
    local caster = self:GetCaster()
    caster.HookBall = self:GetToggleState()
	print(caster.HookBall)
end
