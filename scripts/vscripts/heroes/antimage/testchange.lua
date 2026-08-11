testchange = testchange or class({})
LinkLuaModifier("modifier_testchange", "heroes/antimage/testchange", LUA_MODIFIER_MOTION_NONE)


function testchange:GetIntrinsicModifierName()
	return "modifier_testchange"
end


modifier_testchange = modifier_testchange or class({})


function modifier_testchange:IsPurgable() return false end
function modifier_testchange:RemoveOnDeath() return false end


function modifier_testchange:OnCreated()
	local caster = self:GetCaster()
	print(caster)
	if caster then
		caster.CVH = (caster.CVH or 100) + 100
		print(caster.CVH)
	end
end

