demonic_sprint = class({})

function demonic_sprint:CastFilterResult()
	local caster = self:GetCaster()
	local ball = Ball.unit
	if not ball or ball.controller ~= caster then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function demonic_sprint:GetCustomCastError()
	return "#dota_hud_error_must_have_ball"
end

function demonic_sprint:OnToggle()
    local caster = self:GetCaster()
    local toggled = self:GetToggleState()

    if toggled then
        caster.surgeOn = true

        caster:AddNewModifier(caster,caster,"modifier_demonic_sprint", {duration = 999})
    else
        caster.surgeOn = false

        if caster:HasModifier("modifier_demonic_sprint") then caster:RemoveModifierByName("modifier_demonic_sprint") end
    end

end
