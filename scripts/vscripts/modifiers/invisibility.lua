LinkLuaModifier( "modifier_invisibility", "modifiers/invisibility.lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------

modifier_invisibility = class({})

function modifier_invisibility:IsHidden()
	return true
end

function modifier_invisibility:IsPurgable()
	return false
end

function modifier_invisibility:OnCreated()
end

function modifier_invisibility:OnDestroy()
end

function modifier_invisibility:CheckState()
	return {[MODIFIER_STATE_INVISIBLE] = true }
end