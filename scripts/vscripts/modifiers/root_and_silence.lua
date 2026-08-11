LinkLuaModifier("modifier_root_and_silence", "modifiers/root_and_silence.lua", LUA_MODIFIER_MOTION_NONE)

modifier_root_and_silence = class({})

function modifier_root_and_silence:CheckState()
    return {
        [MODIFIER_STATE_SILENCED] = true,
        [MODIFIER_STATE_ROOTED] = true,
    }
end
