LinkLuaModifier( "modifier_mod_ball_slow", "modifiers/mod_ball_slow", LUA_MODIFIER_MOTION_NONE )

local BALL_SLOW = -25

modifier_mod_ball_slow = class({})

function modifier_mod_ball_slow:IsHidden()
	return true
end

function modifier_mod_ball_slow:IsPurgable()
	return false
end

function modifier_mod_ball_slow:OnCreated()
	
end

function modifier_mod_ball_slow:DeclareFunctions()
	return {MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE}
end

function modifier_mod_ball_slow:GetModifierMoveSpeedBonus_Percentage()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return 0 end
	
	local sprintMult = caster.SprintMult or 0
	caster.ballSlow = BALL_SLOW - BALL_SLOW*sprintMult

	if caster:GetClassname() == "npc_dota_hero_storm_spirit" then 
		local mult = 1 - (caster:GetMana() or 0)/100
		caster.ballSlow = BALL_SLOW - BALL_SLOW*mult
	end

	return caster.ballSlow or 0
end