LinkLuaModifier( "modifier_demonic_sprint", "modifiers/demonic_sprint.lua", LUA_MODIFIER_MOTION_NONE )

modifier_demonic_sprint = class({})

function modifier_demonic_sprint:IsHidden()
	return true
end

function modifier_demonic_sprint:IsPurgable()
	return false
end

function modifier_demonic_sprint:OnCreated()
end

function modifier_demonic_sprint:DeclareFunctions()
	return {MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT , MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT }
end

function modifier_demonic_sprint:GetModifierMoveSpeedBonus_Constant()
	return SPRINT_BONUS_DEMON
end

function modifier_demonic_sprint:GetModifierIgnoreMovespeedLimit()
	return 1
end