glyph = class({})
function glyph:OnSpellStart()
    local ball = Ball.unit

    if ball.glyphParticle then ParticleManager:DestroyParticle(ball.glyphParticle, false) end
    if ball.glyphTimer then Timers:RemoveTimer(ball.glyphTimer) end

    ball.glyphed = true
    ball.glyphParticle = ParticleManager:CreateParticle("particles/abilities/general/glyph/glyph.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy)
    ball.glyphTimer = Timers:CreateTimer(BALL_GLOBAL_IGNORE_TIME_GLYPH, function()
        ball.glyphed = false
        if ball.glyphParticle then ParticleManager:DestroyParticle(ball.glyphParticle, false) end
    end)
end
