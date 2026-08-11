LinkLuaModifier("modifier_become_oak", "abilities/become_oak", LUA_MODIFIER_MOTION_NONE)

become_oak = class({})

function become_oak:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("duration")
	if not duration or duration <= 0 then
		duration = 2.0
	end
	
	caster:AddNewModifier(caster, self, "modifier_become_oak", {duration = duration})
end

-----------------------------------------------------------------------------

modifier_become_oak = class({})

function modifier_become_oak:IsHidden() return false end
function modifier_become_oak:IsDebuff() return false end
function modifier_become_oak:IsPurgable() return false end

function modifier_become_oak:OnCreated(kv)
	if IsServer() then
		self.caster = self:GetParent()
		self.original_scale = self.caster:GetModelScale()
		
		local ability = self:GetAbility()
		self.duration = ability and ability:GetSpecialValueFor("duration") or 2.0
		self.anim_duration = ability and ability:GetSpecialValueFor("anim_duration") or 0.3
		
		local scale_pct = ability and ability:GetSpecialValueFor("model_scale") or 100
		self.target_scale_mult = 1.0 + scale_pct / 100
		
		self.ball_collision_dist = ability and ability:GetSpecialValueFor("ball_collision_dist") or 170
		self.ball_handled_offset = ability and ability:GetSpecialValueFor("ball_handled_offset") or 120
		self.ball_catch_height = ability and ability:GetSpecialValueFor("ball_catch_height") or 220
		
		self.time_elapsed = 0
		self:StartIntervalThink(0.03)
	end
end

function modifier_become_oak:OnIntervalThink()
	if not IsServer() then return end
	
	self.time_elapsed = self.time_elapsed + 0.03
	local remaining = self.duration - self.time_elapsed
	
	-- 1. Управление масштабом модели и радиусом коллизии (плавная анимация вырастания за anim_duration сек и уменьшения за anim_duration сек)
	local current_scale = self.original_scale
	local base_hull = HERO_HULL_SIZE or 16
	local current_hull = base_hull
	
	if self.time_elapsed < self.anim_duration then
		local t = self.time_elapsed / self.anim_duration
		current_scale = self.original_scale + (self.original_scale * (self.target_scale_mult - 1)) * t
		current_hull = base_hull + (base_hull * (self.target_scale_mult - 1)) * t
	elseif remaining < self.anim_duration then
		local t = math.max(0, remaining) / self.anim_duration
		current_scale = self.original_scale + (self.original_scale * (self.target_scale_mult - 1)) * t
		current_hull = base_hull + (base_hull * (self.target_scale_mult - 1)) * t
	else
		current_scale = self.original_scale * self.target_scale_mult
		current_hull = base_hull * self.target_scale_mult
	end
	
	self.caster:SetModelScale(current_scale)
	self.caster:SetHullRadius(current_hull)
	
	-- 2. Управление высотой ловли (Z-ось)
	self.caster.Height = self.ball_catch_height

	-- 3. Управление радиусом ловли (XY-плоскость)
	if self.caster:HasModifier("modifier_ball_catching_disable") or 
	   self.caster:HasModifier("modifier_ball_catching_debuff") then
		self.caster.BallCollRadius = 0
	else
		self.caster.BallCollRadius = self.ball_collision_dist
	end
	
	-- 4. Управление смещением ведения мяча
	self.caster.BallHandledOffset = self.ball_handled_offset
end

function modifier_become_oak:OnDestroy()
	if IsServer() then
		if self.caster and not self.caster:IsNull() then
			if self.original_scale then
				self.caster:SetModelScale(self.original_scale)
			end
			self.caster:SetHullRadius(HERO_HULL_SIZE or 16)
			self.caster.Height = self.caster.originalHeight or 110
			self.caster.BallCollRadius = self.caster.originalBallCollRadius or BALL_COLLISION_DIST
			self.caster.BallHandledOffset = self.caster.originalBallHandledOffset or BALL_HANDLED_OFFSET
		end
	end
end

function modifier_become_oak:GetTexture()
	return "furion_sprout"
end
