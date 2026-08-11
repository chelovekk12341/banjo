LinkLuaModifier( "modifier_clockcog_slow", "modifiers/clockcog_slow.lua", LUA_MODIFIER_MOTION_NONE )

modifier_clockcog_slow = class({})

function modifier_clockcog_slow:IsHidden()
	return true
end

function modifier_clockcog_slow:IsPurgable()
	return false
end

function modifier_clockcog_slow:OnCreated()
	
end

function modifier_clockcog_slow:DeclareFunctions()
	return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE}
end

function modifier_clockcog_slow:GetModifierMoveSpeedBonus_Percentage()

	return -50
end