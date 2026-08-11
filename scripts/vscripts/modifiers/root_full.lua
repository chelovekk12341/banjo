LinkLuaModifier("modifier_root_full", "modifiers/root_full.lua", LUA_MODIFIER_MOTION_NONE)

modifier_root_full = class({})

function modifier_root_full:CheckState()
    return {
        [MODIFIER_STATE_ROOTED] = true
    }
end

function modifier_root_full:IsDebuff()
	return true
end

function modifier_root_full:IsPurgable()
	return true
end

function modifier_root_full:GetTexture()
	return "spectre_spectral_dagger"
end
