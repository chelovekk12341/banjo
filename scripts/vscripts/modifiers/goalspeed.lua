goalspeed = class({})
LinkLuaModifier( "modifier_goalspeed", "modifiers/goalspeed.lua", LUA_MODIFIER_MOTION_NONE )

function goalspeed:GetIntrinsicModifierName()
	return "modifier_goalspeed"
end

--------------------------------------------------------------------------

modifier_goalspeed = class({})

function modifier_goalspeed:IsHidden()
	return true
end

function modifier_goalspeed:IsPurgable()
	return false
end

function modifier_goalspeed:OnCreated()
end

function modifier_goalspeed:DeclareFunctions()
	return {MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT , MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT }
end

function modifier_goalspeed:GetModifierMoveSpeedBonus_Constant()
	if Banjoball then
		local caster = self:GetCaster()
		if not caster or caster:IsNull() then return 0 end

		-- if team is RADIANT, then we take the multiplier for SF RADIANT; else we take the multiplier for SF DIRE:
		local mult = (caster:GetTeam() == 2 and Banjoball.forSFRadiant) or Banjoball.forSFDire or 0
		if not caster:HasModifier("modifier_night_speed") then caster:SetMana(34*mult) end
		caster.speeding = 350 - (SPEED_PER_GOAL or 0)*mult
		return (SPEED_PER_GOAL or 0) * mult
	end
	return 0
end

-- New global variables were declared: self.forSFRadiant and self.forSFDire in banjoball.lua
-- These variables were used in goal.lua

function modifier_goalspeed:GetModifierIgnoreMovespeedLimit()
	return 1
end
