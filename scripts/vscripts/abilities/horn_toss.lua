horn_toss = class({})

function horn_toss:GetCastRange(vLocation, hTarget)
	return 350
end

function horn_toss:GetAOERadius()
	return 350
end

function horn_toss:OnSpellStart()
    local caster = self:GetCaster()
	local ball = Ball.unit
	
	Timers:CreateTimer(HORN_TOSS_DELAY, function()
		local casterPos = caster:GetAbsOrigin()
		local dir = caster:GetForwardVector()
		local perp = Vector(-dir.y, dir.x, 0):Normalized()
		local corners = {}

		corners[0] = casterPos - (perp * HORN_TOSS_NEAR_WIDTH / 2)
		corners[1] = casterPos + (perp * HORN_TOSS_NEAR_WIDTH / 2)
		corners[2] = casterPos + (perp * HORN_TOSS_FAR_WIDTH / 2) + (dir * HORN_TOSS_LENGTH)
		corners[3] = casterPos - (perp * HORN_TOSS_FAR_WIDTH / 2) + (dir * HORN_TOSS_LENGTH)


		local targets = {}
		local targetCount = 0
		-- Test for heroes
		for _,hero in ipairs(Banjoball.vHeroes) do
			if hero ~= caster then
				local heroPos = hero:GetAbsOrigin()
				if isUnitInHitbox(hero, corners) and (heroPos.z >= casterPos.z - HORN_TOSS_Z_DOWN and heroPos.z <= casterPos.z + HORN_TOSS_Z_UP) then
					table.insert(targets, hero)
					targetCount = targetCount + 1
				end
			end
		end
		
		Banjoball:IterateProjectiles( function( proj )
			local projPos = proj:GetAbsOrigin()
			if isUnitInHitbox(proj, corners) and (projPos.z >= casterPos.z - HORN_TOSS_Z_DOWN and projPos.z <= casterPos.z + HORN_TOSS_Z_UP) then
				table.insert(targets, proj)
				targetCount = targetCount + 1
			end
		end)
		
		local ballPos = ball:GetAbsOrigin()
		if not ball.controller and isUnitInHitbox(ball, corners)  and (ballPos.z >= casterPos.z - HORN_TOSS_Z_DOWN and ballPos.z <= casterPos.z + HORN_TOSS_Z_UP)then
			table.insert(targets, ball)
			caster.spellAssistTimer = GameRules:GetGameTime() -- Set assist
			targetCount = targetCount + 1
		end
		
		caster:EmitSound("horn_toss")

		-- Apply force to everything being smashed
		if targetCount > 0 then
			for _, target in ipairs(targets) do
				if target == ball then
					ball.hornToss = caster
					Timers:CreateTimer(0.33, function()
						ball.hornToss = nil	
					end)
					local balvel = ball:GetPhysicsVelocity()
						--print(Vector(balvel.x,balvel.y,0))
					target:AddPhysicsVelocity(dir * (HORN_TOSS_FORCE_BALL + Vector(balvel.x,balvel.y,0):Length() /4 ) * (-1) + Vector(0,0,HORN_TOSS_UP_KICK_BALL_Z) - balvel)	
					Banjoball:RegisterBallHit(caster)
				else
					target:AddPhysicsVelocity(dir * HORN_TOSS_FORCE *(-1) + Vector(0,0,HORN_TOSS_UP_KICK_Z))
					local smashCracks = ParticleManager:CreateParticle("particles/units/heroes/hero_nevermore/nevermore_requiemofsouls_ground_cracks.vpcf", PATTACH_CUSTOMORIGIN, target)
					ParticleManager:SetParticleControl(smashCracks, 0, target:GetAbsOrigin())
					-- Remove no bounce you slimy bastards
					target.noBounce = false
					if target == ball.controller then
						-- Give Magnus assists if he hit the ball-carrier.
						caster.assistTimer = GameRules:GetGameTime()
					end
				end
			end
		end
	end)
end
