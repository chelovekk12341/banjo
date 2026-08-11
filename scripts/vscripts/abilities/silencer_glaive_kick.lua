silencer_glaive_kick = class({})

function silencer_glaive_kick:OnSpellStart()
	local caster = self:GetCaster()
	local ball = Ball.unit

	-- Проверка на владение мячом
	if caster ~= ball.controller then return end

	-- Обычный пинок мяча
	local kickPower = self:GetSpecialValueFor("kickPower") or 1600
	local kickZ = KICK_Z or 200

	-- Запускаем глефу на мяче
	ball.glaive_kick = true
	ball.glaive_pass_count = 1

	-- Создаем партикл глефы, следующий за мячом
	if ball.glaive_particle then
		ParticleManager:DestroyParticle(ball.glaive_particle, true)
		ParticleManager:ReleaseParticleIndex(ball.glaive_particle)
	end
	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_silencer/silencer_glaives_of_wisdom.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
	ParticleManager:SetParticleControl(particle, 0, ball:GetAbsOrigin())
	ParticleManager:SetParticleControlEnt(particle, 1, ball.particleDummy, PATTACH_ABSORIGIN_FOLLOW, "", ball.particleDummy:GetAbsOrigin(), true)
	ParticleManager:SetParticleControl(particle, 2, Vector(kickPower, 0, 0))
	ball.glaive_particle = particle

	-- Исчезновение эффекта глефы через 2 секунды
	Timers:CreateTimer(2.0, function()
		if ball.glaive_particle and ball.glaive_kick then
			ParticleManager:DestroyParticle(ball.glaive_particle, true)
			ParticleManager:ReleaseParticleIndex(ball.glaive_particle)
			ball.glaive_particle = nil
			ball.glaive_kick = false
		end
	end)

	KickBall({
		keys = { target_points = { self:GetCursorPosition() } },
		hero = caster,
		xy_velocity = kickPower,
		z_velocity = kickZ,
		type = 1,
		gravity = KICK_GRAVITY
	})

	ball:EmitSound("Hero_Silencer.GlaivesOfWisdom")
end

function silencer_glaive_kick:CastFilterResultLocation(vLoc)
	if not IsServer() then return end
	local caster = self:GetCaster()
	local ball = Ball.unit
	if caster ~= ball.controller then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function silencer_glaive_kick:GetCustomCastErrorLocation(vLoc)
	return "dota_hud_error_must_have_ball"
end
