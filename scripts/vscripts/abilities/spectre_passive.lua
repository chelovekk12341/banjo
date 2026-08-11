spectre_passive = class({})
LinkLuaModifier("modifier_spectre_passive", "abilities/spectre_passive", LUA_MODIFIER_MOTION_NONE)

function spectre_passive:GetIntrinsicModifierName()
	return "modifier_spectre_passive"
end

function spectre_passive:OnToggle()
	-- Проходимость работает всегда, при переключении ничего не делаем
end

modifier_spectre_passive = class({})

function modifier_spectre_passive:IsHidden() return false end
function modifier_spectre_passive:IsDebuff() return false end
function modifier_spectre_passive:IsPurgable() return false end
function modifier_spectre_passive:RemoveOnDeath() return false end

function modifier_spectre_passive:GetTexture()
	return "spectre_haunt"
end

function modifier_spectre_passive:CheckState()
	-- Проходимость сквозь юнитов работает всегда
	return {
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true
	}
end

function modifier_spectre_passive:OnCreated()
	if IsServer() then
		local parent = self:GetParent()
		local ability = self:GetAbility()
		
		-- По умолчанию включаем способность при создании
		if ability and not ability:GetToggleState() then
			ability:ToggleAbility()
		end
		
		-- Устанавливаем HullRadius в 0 всегда
		parent:SetHullRadius(0)
	end
end

function modifier_spectre_passive:OnDestroy()
	if IsServer() then
		local parent = self:GetParent()
		if parent and not parent:IsNull() then
			parent:SetHullRadius(HERO_HULL_SIZE or 16)
		end
	end
end
