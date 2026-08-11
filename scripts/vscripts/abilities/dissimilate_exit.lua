dissimilate_exit = class({})

function dissimilate_exit:OnSpellStart()
    if not IsServer() then return end
    
    local caster = self:GetCaster()
    if caster:HasModifier("modifier_void_spirit_dissimilate_oow") then
        caster:RemoveModifierByName("modifier_void_spirit_dissimilate_oow")
    end
end
