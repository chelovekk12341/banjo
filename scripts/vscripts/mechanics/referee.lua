function Banjoball:OnRefereeAttacked( keys )
	--print("OnRefereeAttacked")
	local attacked = keys.target
	local ball = Ball.unit

	if not attacked == ball then return end

	local towardsCenter = (Vector(0,0,GroundZ)-ball:GetAbsOrigin()):Normalized()
	
	-- Check to see if it's in a goal at the moment
	local ballPos = ball:GetAbsOrigin()
	if ballPos.x < R_SCORE or ballPos.x > D_SCORE then
		goaliePunished = ball.controller
	end
	
	-- ball is going out of hands of the ref
	ball.controller = nil
	
	ball.lastMovedBy = Referee

	ball:SetAbsOrigin(Vector(ballPos.x, ballPos.y, GROUND_Z))
	if ball.affectedByPowershot == true then 
		Banjoball:PowerStop()
	end
	ball:SetPhysicsVelocity(towardsCenter*REF_OOB_HIT_VEL)
	Banjoball:GetBallInTrueBounds()
	local caster = keys.caster -- Referee

	-- reset pos of ref
	Timers:CreateTimer(.5, function()
		--FindClearSpaceForUnit(Referee, RefereeSpawnPos, false)
		Referee:SetAbsOrigin(RefereeSpawnPos)
		Timers:CreateTimer(.06, function()
			AddEndgameRoot(Referee)
			AddDisarmed(Referee)
		end)
	end)

	ball:SetHealth(ball:GetMaxHealth())
end
