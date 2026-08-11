LinkLuaModifier("modifier_metamorphosis", "modifiers/metamorphosis.lua", LUA_MODIFIER_MOTION_NONE)

modifier_metamorphosis = class({})

function modifier_metamorphosis:OnCreated()
	local parent = self:GetParent()
	if not parent or parent:IsNull() then return end

	if IsServer() then
		parent:StartGestureWithFadeAndPlaybackRate(ACT_DOTA_CAST_ABILITY_3, 0, 1, 1)
	end
	parent.kickPower = META_KICK
end

function modifier_metamorphosis:OnDestroy()
	local parent = self:GetParent()
	if not parent or parent:IsNull() then return end

	if IsServer() then
		parent:StartGesture(ACT_DOTA_CAST_ABILITY_3_END)
	end
	parent.kickPower = KICK_VELOCITY
end

function modifier_metamorphosis:DeclareFunctions()
	return { MODIFIER_PROPERTY_MODEL_CHANGE, MODIFIER_PROPERTY_MODEL_SCALE }
end

function modifier_metamorphosis:GetModifierModelChange()
	return "models/heroes/terrorblade/demon.vmdl"
end

function modifier_metamorphosis:GetModifierModelScale()
	return META_MODEL_SCALE
end