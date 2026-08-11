LinkLuaModifier("modifier_borrow_time", "abilities/borrow_time.lua", LUA_MODIFIER_MOTION_NONE)

borrow_time = class({})

-- Предварительный кэш ресурсов для способности
function borrow_time:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_abaddon/abaddon_borrowed_time.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_abaddon/abaddon_aphotic_shield.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_abaddon.vsndevts", context)
end

function borrow_time:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("duration")
	if duration == 0 then duration = 3.0 end

	-- Воспроизводим звук ульты Абаддона
	caster:EmitSound("Hero_Abaddon.BorrowedTime")

	-- Создаем светящийся щит Абаддона (Aphotic Shield) для гарантированного визуального свечения
	local pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_abaddon/abaddon_aphotic_shield.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(pfx, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
	ParticleManager:SetParticleControl(pfx, 1, Vector(75, 75, 75)) -- Задает размер/радиус щита

	-- Накладываем модификатор
	local mod = caster:AddNewModifier(caster, self, "modifier_borrow_time", { duration = duration })
	if mod then
		mod.pfx = pfx
	end

	-- Перезаряжаем первую способность (mist_coil)
	local mist_coil_abil = caster:FindAbilityByName("mist_coil")
	if mist_coil_abil then
		mist_coil_abil:EndCooldown()
	end

	-- Если бег (спринт) выключен, принудительно активируем его
	if not caster.surgeOn then
		local sprint_abil = caster:FindAbilityByName("surge")
		if sprint_abil then
			caster:CastAbilityNoTarget(sprint_abil, 0)
		end
	end
end

--------------------------------------------------------------------------------

modifier_borrow_time = class({})

function modifier_borrow_time:IsHidden()
	return false -- Отображаем иконку баффа на панели
end

function modifier_borrow_time:IsDebuff()
	return false
end

function modifier_borrow_time:IsPurgable()
	return false
end

function modifier_borrow_time:GetTexture()
	return "abaddon_borrowed_time"
end

-- Дополнительно оставляем стандартный эффект Borrowed Time (если он вдруг сработает на модели)
function modifier_borrow_time:GetEffectName()
	return "particles/units/heroes/hero_abaddon/abaddon_borrowed_time.vpcf"
end

function modifier_borrow_time:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_borrow_time:OnDestroy()
	if IsServer() and self.pfx then
		ParticleManager:DestroyParticle(self.pfx, false)
		ParticleManager:ReleaseParticleIndex(self.pfx)
	end
end
