LinkLuaModifier( "modifier_night_speed", "modifiers/night_speed.lua", LUA_MODIFIER_MOTION_NONE )

modifier_night_speed = class({})

function modifier_night_speed:IsHidden()
	return true
end

function modifier_night_speed:IsPurgable()
	return false
end

function modifier_night_speed:OnCreated()
end

function modifier_night_speed:DeclareFunctions()
	return {MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT , MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT }
end

function modifier_night_speed:GetModifierMoveSpeedBonus_Constant()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return 0 end
	return caster.speeding or 0
end

function modifier_night_speed:GetModifierIgnoreMovespeedLimit()
	return 1
end