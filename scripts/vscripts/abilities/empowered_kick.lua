empowered_kick = class({})

function empowered_kick:OnSpellStart()
    local caster = self:GetCaster()
	local ball = Ball.unit

	-- Preventing usage without the ball.
	if caster ~= ball.controller then return end

	-- Kicking the ball.
	KickBall({keys = { target_points = { self:GetCursorPosition() } }, hero = caster, xy_velocity = EMPOWERED_KICK_VELOCITY, z_velocity = 0, type = 1, gravity = KICK_GRAVITY})
	ball.invisTime = INVIS_TIME
	
	ParticleManager:CreateParticle("particles/enhanced_kick/nightstalker_black_nihility_void_hit.vpcf", PATTACH_ABSORIGIN, ball.particleDummy)
	-- ParticleManager:CreateParticle("particles/econ/items/nightstalker/nightstalker_black_nihility/nightstalker_black_nihility_void_hit_ray.vpcf", PATTACH_ABSORIGIN, ball.particleDummy)
	
	
	ball:EmitSound("Hero_Nightstalker.Void")
end