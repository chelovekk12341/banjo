cmiuc = class({})

function cmiuc:OnSpellStart()
	local caster = self:GetCaster()
	local ball = Ball.unit
	local cmiucabil = caster:FindAbilityByName("cmiuc")
	local duration = 0
	ball.cmiucUsed = false
		
	if CMIUC_RADIUS <= (ball:GetAbsOrigin() - caster:GetAbsOrigin()):Length() then
		return
	end

	local CmiucParticle = ParticleManager:CreateParticle( "particles/econ/items/enchantress/enchantress_2021_immortal/enchantress_2021_immortal_14_imps.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy )
	ParticleManager:SetParticleControl( CmiucParticle, 0, ball:GetAbsOrigin())
	ParticleManager:SetParticleControlEnt( CmiucParticle, 1, ball.particleDummy, PATTACH_ABSORIGIN_FOLLOW, "", ball.particleDummy:GetAbsOrigin(), true )
	duration = GameRules:GetGameTime() + CMIUC_HERO_DURATION
	Timers:CreateTimer(0, function()
		if (ball.controller or ball:GetPhysicsVelocity() == Vector(0,0,0) ) and duration <= GameRules:GetGameTime() and ball.cmiucUsed == true then 
			ParticleManager:DestroyParticle(CmiucParticle, true)
			ball.cmiucUsed = false
		else
			ball:AddPhysicsVelocity(ball:GetPhysicsVelocity() * -CMIUC_SLOW)
			ball.cmiucUsed = true
			return 0.1
		end
		return
	end)
end