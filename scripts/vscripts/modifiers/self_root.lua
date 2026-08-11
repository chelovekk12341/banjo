LinkLuaModifier( "modifier_self_root", "modifiers/self_root", LUA_MODIFIER_MOTION_NONE )

modifier_self_root = class({})

function modifier_self_root:IsHidden()
	return true
end

function modifier_self_root:IsPurgable()
	return false
end

function modifier_self_root:OnCreated()
end

function modifier_self_root:CheckState()
	return {[MODIFIER_STATE_ROOTED] = true }
end