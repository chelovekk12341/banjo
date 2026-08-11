LinkLuaModifier( "modifier_newsprint", "modifiers/newsprint", LUA_MODIFIER_MOTION_NONE )

modifier_newsprint = class({})

function modifier_newsprint:IsHidden()
	return true
end

function modifier_newsprint:IsPurgable()
	return false
end

function modifier_newsprint:OnCreated()
end

function modifier_newsprint:DeclareFunctions()
	return {MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT , MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT }
end

function modifier_newsprint:GetModifierMoveSpeedBonus_Constant()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return 0 end
	local bonus = caster.SprintBonus or 0
	local mult = caster.SprintMult or 0
	return bonus * mult
end

function modifier_newsprint:GetModifierIgnoreMovespeedLimit()
	return 1
end