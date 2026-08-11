LinkLuaModifier( "modifier_ball_catching_disable", "modifiers/ball_catching_disable.lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------

modifier_ball_catching_disable = class({})

function modifier_ball_catching_disable:IsHidden()
	return true
end

function modifier_ball_catching_disable:IsPurgable()
	return false
end

function modifier_ball_catching_disable:OnCreated()
	local parent = self:GetParent()
	if parent and parent.BallCollRadius then
		parent.BallCollRadius = parent.BallCollRadius - BALL_COLLISION_DIST
	end
end

function modifier_ball_catching_disable:OnDestroy()
	local parent = self:GetParent()
	if parent and parent.BallCollRadius then
		parent.BallCollRadius = parent.BallCollRadius + BALL_COLLISION_DIST
	end
end