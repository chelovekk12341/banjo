ringmaster_unicycle = class({})

LinkLuaModifier("modifier_ringmaster_unicycle_buff", "abilities/ringmaster_unicycle", LUA_MODIFIER_MOTION_NONE)

function ringmaster_unicycle:GetAbilityTextureName()
	return "ringmaster_summon_unicycle"
end

function ringmaster_unicycle:OnSpellStart()
	local caster = self:GetCaster()
	
	-- Накладываем бафф ускорения на 5 секунд
	caster:AddNewModifier(caster, self, "modifier_ringmaster_unicycle_buff", {duration = 5.0})
	
	-- Звук старта
	EmitSoundOn("Hero_Ringmaster.Unicycle.Cast", caster)
end

--------------------------------------------------------------------------------

modifier_ringmaster_unicycle_buff = class({})

function modifier_ringmaster_unicycle_buff:IsHidden() return false end
function modifier_ringmaster_unicycle_buff:IsDebuff() return false end
function modifier_ringmaster_unicycle_buff:IsPurgable() return false end

function modifier_ringmaster_unicycle_buff:GetTexture()
	return "ringmaster_summon_unicycle"
end

function modifier_ringmaster_unicycle_buff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_MOVESPEED_LIMIT,
		MODIFIER_PROPERTY_TRANSLATE_ACTIVITY_MODIFIERS,
		MODIFIER_PROPERTY_VISUAL_Z_DELTA,
	}
end

function modifier_ringmaster_unicycle_buff:GetModifierIgnoreMovespeedLimit()
	return 1
end

function modifier_ringmaster_unicycle_buff:GetModifierMoveSpeedLimit()
	return 800
end

function modifier_ringmaster_unicycle_buff:GetActivityTranslationModifiers()
	return "unicycle"
end

-- Рутим героя на время действия, отключая WASD и навигатор (по аналогии со спринтом Антимага)
function modifier_ringmaster_unicycle_buff:CheckState()
	return {
		[MODIFIER_STATE_ROOTED] = true,
	}
end

-- Визуально приподнимаем героя на 70 единиц вверх
function modifier_ringmaster_unicycle_buff:GetVisualZDelta()
	return 70
end

function modifier_ringmaster_unicycle_buff:OnCreated()
	if not IsServer() then return end
	self.parent = self:GetParent()
	
	-- Спавним проп моноколеса и прикрепляем его к ногам героя
	-- Смещаем проп на -70 вниз, чтобы колесо оставалось на земле при приподнятом герое
	self.prop = SpawnEntityFromTableSynchronous("prop_dynamic", {
		model = "models/heroes/ringmaster/ringmaster_prop_unicycle.vmdl"
	})
	if self.prop then
		self.prop:SetParent(self.parent, "attach_origin")
		self.prop:SetLocalOrigin(Vector(0, 0, -70))
		self.prop:SetLocalAngles(0, 0, 0)
	end
	
	-- Стартовое ускорение (по аналогии со спринтом Антимага)
	local forward = self.parent:GetForwardVector()
	forward.z = 0
	forward = forward:Normalized()
	self.parent:AddPhysicsVelocity(forward * 300)
	
	-- Цикличный звук движения колеса
	EmitSoundOn("Hero_Ringmaster.Unicycle.Loop", self.parent)
	
	-- Запускаем физический синк каждую 0.03 сек
	self:StartIntervalThink(0.03)
end

function modifier_ringmaster_unicycle_buff:OnIntervalThink()
	if not IsServer() then return end
	if not self.parent or self.parent:IsNull() or not self.parent:IsAlive() then return end
	
	local forward = self.parent:GetForwardVector()
	forward.z = 0
	forward = forward:Normalized()
	
	-- Каждую итерацию добавляем скорость вперед (по аналогии со спринтом Антимага)
	self.parent:AddPhysicsVelocity(forward * 80)
	
	-- Ограничиваем максимальную скорость до 800 с плавным затуханием (инерцией)
	local vel = self.parent:GetPhysicsVelocity()
	local speed = vel:Length()
	if speed > 800 then
		local decay = 0.94
		local new_speed = math.max(800, speed * decay)
		self.parent:SetPhysicsVelocity(vel:Normalized() * new_speed)
	end
end

function modifier_ringmaster_unicycle_buff:OnDestroy()
	if not IsServer() then return end
	
	-- Останавливаем звук движения
	self.parent:StopSound("Hero_Ringmaster.Unicycle.Loop")
	
	-- Воспроизводим звук окончания
	EmitSoundOn("Hero_Ringmaster.Unicycle.End", self.parent)
	
	-- Удаляем проп моноколеса
	if self.prop and not self.prop:IsNull() then
		self.prop:Destroy()
		self.prop = nil
	end
	
	-- Создаем партикль взрыва/исчезновения моноколеса
	local end_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_ringmaster/ringmaster_unicycle_end.vpcf", PATTACH_ABSORIGIN, self.parent)
	ParticleManager:SetParticleControl(end_pfx, 0, self.parent:GetAbsOrigin())
	ParticleManager:ReleaseParticleIndex(end_pfx)
end
