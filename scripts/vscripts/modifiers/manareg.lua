LinkLuaModifier( "modifier_manareg", "modifiers/manareg.lua", LUA_MODIFIER_MOTION_NONE )

modifier_manareg = class({})

function modifier_manareg:IsHidden()
	return true
end

function modifier_manareg:IsPurgable()
	return false
end

function modifier_manareg:DeclareFunctions()
    return { MODIFIER_PROPERTY_MANA_REGEN_CONSTANT }
end

function modifier_manareg:GetModifierConstantManaRegen()
	return MANA_REG_STORM_BONUS
end