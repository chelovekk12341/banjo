LinkLuaModifier("modifier_unlimited_casting", "modifiers/modifier_unlimited_casting", LUA_MODIFIER_MOTION_NONE)

modifier_unlimited_casting = class({})

function modifier_unlimited_casting:IsHidden() return false end
function modifier_unlimited_casting:IsPurgable() return false end
function modifier_unlimited_casting:RemoveOnDeath() return false end

function modifier_unlimited_casting:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
	}
end

function modifier_unlimited_casting:GetModifierPercentageCooldown()
	return 100
end
