ringmaster_box = class({})

LinkLuaModifier("modifier_ringmaster_box_debuff", "abilities/ringmaster_box", LUA_MODIFIER_MOTION_NONE)

function ringmaster_box:GetAbilityTextureName()
	return "ringmaster_the_box"
end

function ringmaster_box:CastFilterResultTarget(target)
	if not target or target:IsNull() then
		return UF_SUCCESS
	end
	if not IsValidEntity(target) or target.IsHero == nil then
		return UF_FAIL_CUSTOM
	end
	if target:GetTeamNumber() == self:GetCaster():GetTeamNumber() then
		return UF_FAIL_FRIENDLY
	end
	if target.goalie then
		return UF_FAIL_CUSTOM
	end
	if Ball and Ball.unit and not Ball.unit:IsNull() and Ball.unit.controller == target then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function ringmaster_box:GetCustomCastErrorTarget(target)
	if not target or target:IsNull() then
		return ""
	end
	if not IsValidEntity(target) or target.IsHero == nil then
		return "#dota_hud_error_cant_cast_on_non_hero"
	end
	if target.goalie then
		return "#dota_hud_error_cant_cast_on_goalie"
	end
	if Ball and Ball.unit and not Ball.unit:IsNull() and Ball.unit.controller == target then
		return "#dota_hud_error_cant_cast_on_ball_holder"
	end
end

function ringmaster_box:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	
	if not target or target:GetTeamNumber() == caster:GetTeamNumber() or target.goalie then return end
	if Ball and Ball.unit and not Ball.unit:IsNull() and Ball.unit.controller == target then return end
	
	local duration = self:GetSpecialValueFor("duration")
	if duration <= 0 then duration = 1.5 end
	target:AddNewModifier(caster, self, "modifier_ringmaster_box_debuff", {duration = duration})
	
	-- Звуки
	EmitSoundOn("Hero_Ringmaster.TheBox.Cast", caster)
	EmitSoundOn("Hero_Ringmaster.TheBox.Target", target)
end

--------------------------------------------------------------------------------

modifier_ringmaster_box_debuff = class({})

function modifier_ringmaster_box_debuff:IsHidden() return false end
function modifier_ringmaster_box_debuff:IsDebuff() return true end
function modifier_ringmaster_box_debuff:IsPurgable() return false end

function modifier_ringmaster_box_debuff:CheckState()
	return {
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
end

function modifier_ringmaster_box_debuff:OnCreated()
	if not IsServer() then return end
	self.parent = self:GetParent()
	
	-- Сохраняем оригинальную модель героя
	self.original_model = self.parent:GetModelName()
	
	-- Меняем модель героя на модель коробки Ringmaster
	self.parent:SetModel("models/heroes/ringmaster/ringmaster_box.vmdl")
	self.parent:SetOriginalModel("models/heroes/ringmaster/ringmaster_box.vmdl")
	
	-- Отключаем ловлю мяча
	self.parent.noball = true
	
	-- Блокируем абсолютно все абилки героя
	self.disabled_abilities = {}
	for i = 0, self.parent:GetAbilityCount() - 1 do
		local abil = self.parent:GetAbilityByIndex(i)
		if abil and abil:IsActivated() then
			abil:SetActivated(false)
			table.insert(self.disabled_abilities, abil)
		end
	end
	
	-- Цикличный жутковатый звук тиканья и ожидания внутри коробки
	EmitSoundOn("Hero_Ringmaster.TheBox.Loop", self.parent)
end

function modifier_ringmaster_box_debuff:OnDestroy()
	if not IsServer() then return end
	
	-- Останавливаем цикличный звук
	self.parent:StopSound("Hero_Ringmaster.TheBox.Loop")
	
	-- Возвращаем оригинальную модель
	if self.original_model then
		self.parent:SetModel(self.original_model)
		self.parent:SetOriginalModel(self.original_model)
	end
	
	-- Включаем ловлю мяча
	self.parent.noball = false
	
	-- Разблокируем абилки
	if self.disabled_abilities then
		for _, abil in ipairs(self.disabled_abilities) do
			if abil and not abil:IsNull() then
				abil:SetActivated(true)
			end
		end
	end
	
	-- Звук окончания
	EmitSoundOn("Hero_Ringmaster.TheBox.End", self.parent)
end
