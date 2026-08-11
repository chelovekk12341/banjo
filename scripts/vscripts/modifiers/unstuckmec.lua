
LinkLuaModifier( "modifier_unstuckmec", "modifiers/unstuckmec.lua", LUA_MODIFIER_MOTION_NONE )

modifier_unstuckmec = class({})

function modifier_unstuckmec:IsHidden()
	return true
end

function modifier_unstuckmec:IsPurgable()
	return false
end

function modifier_unstuckmec:OnCreated()
	
end

function modifier_unstuckmec:CheckState()
	return {[MODIFIER_STATE_NO_UNIT_COLLISION] = true }
end