LinkLuaModifier( "modifier_shukuchi", "modifiers/shukuchi.lua", LUA_MODIFIER_MOTION_NONE )

modifier_shukuchi = class({})

function modifier_shukuchi:IsHidden()
	return true
end

function modifier_shukuchi:IsPurgable()
	return false
end

function modifier_shukuchi:OnCreated()
end

function modifier_shukuchi:DeclareFunctions()
	return {MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT , MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT }
end

function modifier_shukuchi:GetModifierMoveSpeedBonus_Constant()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return 0 end
	local ball = Ball.unit
	local sprintedAt = caster.sprintedAt or GameRules:GetGameTime()
	local timeSprinting = GameRules:GetGameTime() - sprintedAt
	local mult = math.min(timeSprinting * (WEAVER_GAIN or 0), 1)
	caster.SprintMult = mult
	print( string.format("mult = %.2f", mult), "", string.format("at %.2f", timeSprinting) )
	local bonus = caster.SprintBonus or 0
	return bonus * mult
end

function modifier_shukuchi:GetModifierIgnoreMovespeedLimit()
	return 1
end