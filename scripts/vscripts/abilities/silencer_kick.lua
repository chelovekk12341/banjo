silencer_kick = class({})

function silencer_kick:OnSpellStart()
	local caster = self:GetCaster()
	local ball = Ball.unit

	-- Проверка на владение мячом
	if caster ~= ball.controller then return end

	-- Обычный пинок мяча
	local kickPower = self:GetSpecialValueFor("kickPower") or 1600
	local kickZ = KICK_Z or 200

	-- Помечаем мяч как Last Word
	ball.last_word_kick = true

	-- Создаем партикл проклятия, следующий за мячом
	if ball.last_word_particle then
		ParticleManager:DestroyParticle(ball.last_word_particle, true)
		ParticleManager:ReleaseParticleIndex(ball.last_word_particle)
	end
	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_silencer/silencer_curse.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
	ParticleManager:SetParticleControlEnt(particle, 0, ball.particleDummy, PATTACH_ABSORIGIN_FOLLOW, "", ball.particleDummy:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(particle, 1, ball.particleDummy, PATTACH_ABSORIGIN_FOLLOW, "", ball.particleDummy:GetAbsOrigin(), true)
	ball.last_word_particle = particle

	KickBall({
		keys = { target_points = { self:GetCursorPosition() } },
		hero = caster,
		xy_velocity = kickPower,
		z_velocity = kickZ,
		type = 1,
		gravity = KICK_GRAVITY
	})

	ball:EmitSound("Hero_Silencer.LastWord.Cast")
end
