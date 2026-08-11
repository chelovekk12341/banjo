LinkLuaModifier("modifier_become_tree", "abilities/become_tree", LUA_MODIFIER_MOTION_NONE)

become_tree = class({})

function become_tree:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("duration")
	if not duration or duration <= 0 then
		duration = 1.0
	end
	
	print("[Become Tree] OnSpellStart called on caster: " .. caster:GetUnitName() .. " with duration: " .. tostring(duration))
	Say(nil, "[Become Tree] OnSpellStart called!", false)
	
	caster:AddNewModifier(caster, self, "modifier_become_tree", {duration = duration})
end

-----------------------------------------------------------------------------

modifier_become_tree = class({})

function modifier_become_tree:IsHidden() return false end
function modifier_become_tree:IsDebuff() return false end
function modifier_become_tree:IsPurgable() return false end

function modifier_become_tree:OnCreated(kv)
	print("[Become Tree] modifier_become_tree:OnCreated called")
	Say(nil, "[Become Tree] modifier_become_tree:OnCreated!", false)
	if IsServer() then
		self.caster = self:GetParent()
		self.original_scale = self.caster:GetModelScale()
		
		local ability = self:GetAbility()
		self.duration = ability and ability:GetSpecialValueFor("duration") or 1.0
		self.anim_duration = ability and ability:GetSpecialValueFor("anim_duration") or 0.2
		-- Мы хотим увеличить масштаб в 3 раза. Базовый масштаб умножается на 3.
		self.target_scale_mult = 3.0
		
		self.time_elapsed = 0
		self:StartIntervalThink(0.03)
	end
end

function modifier_become_tree:OnIntervalThink()
	if not IsServer() then return end
	
	self.time_elapsed = self.time_elapsed + 0.03
	local remaining = self.duration - self.time_elapsed
	
	local current_scale = self.original_scale
	
	if self.time_elapsed < self.anim_duration then
		-- Анимация увеличения (0.2 сек)
		local t = self.time_elapsed / self.anim_duration
		current_scale = self.original_scale + (self.original_scale * (self.target_scale_mult - 1)) * t
	elif remaining < self.anim_duration then
		-- Анимация уменьшения (0.2 сек)
		local t = math.max(0, remaining) / self.anim_duration
		current_scale = self.original_scale + (self.original_scale * (self.target_scale_mult - 1)) * t
	else
		-- Пиковое значение (увеличение в 3 раза)
		current_scale = self.original_scale * self.target_scale_mult
	end
	
	self.caster:SetModelScale(current_scale)
end

function modifier_become_tree:OnDestroy()
	print("[Become Tree] modifier_become_tree:OnDestroy called")
	Say(nil, "[Become Tree] modifier_become_tree:OnDestroy!", false)
	if IsServer() then
		if self.caster and not self.caster:IsNull() and self.original_scale then
			self.caster:SetModelScale(self.original_scale)
		end
	end
end

function modifier_become_tree:GetTexture()
	return "furion_sprout"
end
