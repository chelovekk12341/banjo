hoodwink_scurry_shot = class({})
hoodwink_scurry_shot_release = class({})

function hoodwink_scurry_shot:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_projectile.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_hoodwink.vsndevts", context)
end

-- Вызывается в начале заряда (CHANNELLED)
function hoodwink_scurry_shot:OnSpellStart()
	if not IsServer() then return end
	local caster = self:GetCaster()

	self.start_charge_time = GameRules:GetGameTime()
	self.shot_origin = caster:GetAbsOrigin()
	self.shot_dir = (self:GetCursorPosition() - caster:GetAbsOrigin()):Normalized()
	self.shot_dir.z = 0
	if self.shot_dir:Length2D() < 0.1 then
		self.shot_dir = caster:GetForwardVector()
	end
	self.shot_fired = false

	-- Разворачиваем героя в сторону выстрела
	caster:SetForwardVector(self.shot_dir)

	-- Подменяем способность: повторное нажатие R = выстрел
	caster:SwapAbilities("hoodwink_scurry_shot", "hoodwink_scurry_shot_release", false, true)

	caster:EmitSound("Hero_Hoodwink.AcornShot.Cast")
end

-- Вызывается при завершении канала (по времени → выстрел на максимуме)
-- или при внешнем прерывании (стан и т.п. → не стреляем)
function hoodwink_scurry_shot:OnChannelFinish(bInterrupted)
	if not IsServer() then return end
	local caster = self:GetCaster()

	-- Возвращаем основную способность
	if caster:HasAbility("hoodwink_scurry_shot_release") then
		caster:SwapAbilities("hoodwink_scurry_shot_release", "hoodwink_scurry_shot", false, true)
	end

	caster:StopSound("Hero_Hoodwink.AcornShot.Cast")

	if bInterrupted and not self.shot_fired then
		-- Внешнее прерывание — не стреляем, убираем кулдаун
		self:EndCooldown()
		return
	end

	if not self.shot_fired then
		self:DoFire(caster)
	end
end

-- Логика выстрела
function hoodwink_scurry_shot:DoFire(caster)
	self.shot_fired = true

	local optimal_channel_time = self:GetSpecialValueFor("optimal_channel_time")
	local min_push_force = self:GetSpecialValueFor("min_push_force")
	local max_push_force = self:GetSpecialValueFor("max_push_force")
	local proj_speed = self:GetSpecialValueFor("proj_speed")
	local proj_radius = self:GetSpecialValueFor("proj_radius")

	if optimal_channel_time <= 0 then optimal_channel_time = 3.0 end
	if min_push_force <= 0 then min_push_force = 100 end
	if max_push_force <= 0 then max_push_force = 2000 end
	if proj_speed <= 0 then proj_speed = 1400 end
	if proj_radius <= 0 then proj_radius = 100 end

	local charge_elapsed = GameRules:GetGameTime() - (self.start_charge_time or GameRules:GetGameTime())
	local t = math.min(charge_elapsed / optimal_channel_time, 1.0)
	local push_force = min_push_force + t * (max_push_force - min_push_force)

	local origin = self.shot_origin or caster:GetAbsOrigin()
	local dir = self.shot_dir or caster:GetForwardVector()

	caster:EmitSound("Hero_Hoodwink.ScurryShot.Fire")

	local vel = dir * proj_speed
	local proj = Banjoball:CreateProjectile(PROJECTILE_INDEX_SWAP, caster, proj_radius, vel, NO_FRICTION, origin + dir * 80, true)

	proj.projParticle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_hoodwink/hoodwink_acorn_shot_projectile.vpcf",
		PATTACH_RENDERORIGIN_FOLLOW, proj)

	local hit = false

	proj.onProjectileCollision = function(collided)
		if hit then return end
		hit = true

		ParticleManager:DestroyParticle(proj.projParticle, true)
		if Banjoball:IsProjectileActive(proj) then
			Banjoball:DestroyProjectile(proj)
		end

		if not collided then return end

		local hit_pos = collided:GetAbsOrigin()
		local push_dir = (hit_pos - origin):Normalized()
		if push_dir:Length2D() < 0.1 then push_dir = dir end

		if collided.isBall then
			collided.controller = nil
			collided:SetPhysicsVelocity(push_dir * push_force)
		elseif not collided.goalie then
			collided:SetPhysicsVelocity(push_dir * push_force)
		end
	end

	Timers:CreateTimer(2.5, function()
		if proj and Banjoball:IsProjectileActive(proj) then
			ParticleManager:DestroyParticle(proj.projParticle, true)
			Banjoball:DestroyProjectile(proj)
		end
	end)
end

-- =====================================================
-- Release ability: нажатие R во время заряда → стрелять
-- =====================================================
function hoodwink_scurry_shot_release:OnSpellStart()
	if not IsServer() then return end
	local caster = self:GetCaster()

	-- Возвращаем основную способность
	caster:SwapAbilities("hoodwink_scurry_shot_release", "hoodwink_scurry_shot", false, true)

	local shotAbility = caster:FindAbilityByName("hoodwink_scurry_shot")
	if shotAbility and not shotAbility:IsNull() then
		shotAbility.shot_fired = true  -- предотвращаем повторный выстрел в OnChannelFinish
		shotAbility:DoFire(caster)
	end

	-- Прерываем канал (вызовет OnChannelFinish(true), но shot_fired уже true)
	caster:InterruptChannel()
end
