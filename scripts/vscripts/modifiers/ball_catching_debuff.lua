LinkLuaModifier( "modifier_ball_catching_debuff", "modifiers/ball_catching_debuff.lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------

modifier_ball_catching_debuff = class({})

function modifier_ball_catching_debuff:IsHidden()
	return true
end

function modifier_ball_catching_debuff:IsPurgable()
	return false
end

function modifier_ball_catching_debuff:OnCreated()
	local parent = self:GetParent()
	if parent and parent.BallCollRadius then
		parent.BallCollRadius = parent.BallCollRadius - BALL_COLLISION_DIST
	end
end

function modifier_ball_catching_debuff:OnDestroy()
	local parent = self:GetParent()
	if parent and parent.BallCollRadius then
		parent.BallCollRadius = parent.BallCollRadius + BALL_COLLISION_DIST
	end
end