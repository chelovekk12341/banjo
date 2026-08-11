LinkLuaModifier( "modifier_ninjainvis", "modifiers/ninjainvis.lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------

modifier_ninjainvis = class({})

function modifier_ninjainvis:IsHidden()
	return true
end

function modifier_ninjainvis:IsPurgable()
	return false
end

function modifier_ninjainvis:OnCreated()
end

function modifier_ninjainvis:OnDestroy()
end

function modifier_ninjainvis:CheckState()
	return {[MODIFIER_STATE_INVISIBLE] = true }
end