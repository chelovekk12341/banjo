remote_mine = class({})

function remote_mine:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorPosition()
	target.z = caster:GetAbsOrigin().z
	
	local dir = (target - caster:GetAbsOrigin()):Normalized()
	local dist = (target - caster:GetAbsOrigin()):Length()
	if (dist < REMOTE_MINE_MIN_THROW) then
		dist = REMOTE_MINE_MIN_THROW
	elseif (dist > REMOTE_MINE_MAX_THROW) then
		dist = REMOTE_MINE_MAX_THROW
	end
	local throwVel = REMOTE_MINE_THROW_VELOCITY
	local vel = dir * throwVel
	
	caster:EmitSound("Hero_Techies.RemoteMine.Toss")
	
	local remoteMine = Banjoball:CreateProjectile(PROJECTILE_INDEX_REMOTE_MINE, caster, REMOTE_MINE_COLLISION_RADIUS, vel, NO_FRICTION, nil, true, true)
	caster.remoteMine = remoteMine
	remoteMine.bombParticle = ParticleManager:CreateParticleForTeam(PARTICLE_REMOTE_MINE, PATTACH_RENDERORIGIN_FOLLOW, remoteMine, caster:GetTeam())
	remoteMine:SetPhysicsVelocity(vel)
	remoteMine:SetForwardVector(dir)
	local distCounter = math.ceil((dist / REMOTE_MINE_THROW_VELOCITY) / 0.03)
	remoteMine.rollTimer = Timers:CreateTimer(function()
		if not remoteMine.bombParticle or distCounter <= 0 then return end
		distCounter = distCounter - 1
		if distCounter == 0 then
			remoteMine:SetPhysicsVelocity(Vector(0,0,0))
			remoteMine:SetPhysicsFriction(GROUND_FRICTION)
		end
		local velocity = remoteMine:GetPhysicsVelocity()
		local vel = velocity:Length()
		local rotateVel = distCounter * 100

		if vel > 0 then
			-- ParticleManager:SetParticleControl(remoteMine.bombParticle, 10,
				-- Vector(0,rotateVel,0))
			ParticleManager:SetParticleControl(remoteMine.bombParticle, 5,
				remoteMine:GetAbsOrigin()+velocity:Normalized())
			--remoteMine:SetForwardVector(velocity:Normalized())
		else return end
		return 0.03
	end)
	remoteMine:EmitSound("Hero_Techies.RemoteMine.Plant")

	-- Remote Mine doesn't collide, yo.
	remoteMine.onProjectileCollision = function( collided )
		return false
	end
	
	SwapAbilities( caster, "remote_mine_detonate", "remote_mine", ABILITY_SLOT_Q )
	local detonate = caster:FindAbilityByName("remote_mine_detonate")
	detonate:StartCooldown(REMOTE_MINE_DETONATE_START_DELAY)
	
	-- Display the time counter particle for the player, above the remote mine
	Banjoball:CreateCountdownTimer( remoteMine, REMOTE_MINE_COUNTDOWN_TIMER_PATH, REMOTE_MINE_DETONATE_DELAY + REMOTE_MINE_DETONATE_FINAL_DELAY, function() return Banjoball:IsProjectileActive(remoteMine) end, caster:GetTeam())
	
	-- Explode the remote mine after a brief delay
	Timers:CreateTimer(REMOTE_MINE_DETONATE_DELAY, function()
		-- Break if already exploded
		if not Banjoball:IsProjectileActive(remoteMine) then return end
		detonateRemoteMine(caster, false)
	end)
end

remote_mine_detonate = class({})

function remote_mine_detonate:OnSpellStart()
	detonateRemoteMine(self:GetCaster(), true)
end

-- Detonates the mine
function detonateRemoteMine( caster, casted )
	local remoteMine = caster.remoteMine
	local ball = Ball.unit
	local ballPos = ball:GetAbsOrigin()
	
	-- Break if already exploded and block double detonates
	if not Banjoball:IsProjectileActive(remoteMine) then return end
	Banjoball:DisableProjectile(remoteMine)
	Banjoball:DestroyCountdownTimer(remoteMine)
	
	Timers:CreateTimer(REMOTE_MINE_DETONATE_FINAL_DELAY, function()
		local detonateParticle = ParticleManager:CreateParticle("particles/units/heroes/hero_techies/techies_remote_mines_detonate.vpcf", PATTACH_CUSTOMORIGIN, remoteMine)
		ParticleManager:SetParticleControl(detonateParticle, 0, remoteMine:GetAbsOrigin())
		remoteMine:EmitSound("Hero_Techies.RemoteMine.Detonate")
		
		Banjoball:SlamNearby(caster, remoteMine:GetAbsOrigin(), REMOTE_MINE_DETONATE_RADIUS, REMOTE_MINE_DETONATE_XY, REMOTE_MINE_DETONATE_Z, nil, function(caster, entity, direction, slam_xy, slam_z)
			local mult = 1
			if entity:GetAbsOrigin().z > GROUND_Z then mult = REMOTE_MINE_AIR_MINUS end
			
			-- Preventing slamming of the caster, the ball and any units in the air.
			if entity ~= Ball.unit and not entity.goalie then return ( direction*slam_xy + Vector(0, 0, slam_z*mult) ) end
			
			return Vector(0, 0, 0)
		end)

		-- Slamshoting logic, that depends on distance to the nearest goal area.
		if ( ball:GetAbsOrigin() - remoteMine:GetAbsOrigin() ):Length() <= DETONATE_RADIUS and ball:GetAbsOrigin().z <= DETONATE_HEIGHT and not ball.controller then 
			local heroPos = remoteMine:GetAbsOrigin()
			local ballVelocity = ball:GetPhysicsVelocity()
			local direction = ( ballPos - heroPos ):Normalized()
			local coordinate = (caster:GetTeam() == DOTA_TEAM_GOODGUYS and DETONATE_COORDINATE_X ) or -1 * DETONATE_COORDINATE_X
			
			if caster:GetTeam() == DOTA_TEAM_GOODGUYS and heroPos.x >= coordinate or caster:GetTeam() == DOTA_TEAM_BADGUYS and heroPos.x <= coordinate then heroPos.x = coordinate end
			if math.abs(heroPos.y) <= DETONATE_COORDINATE_Y then heroPos.y = 0 else heroPos.y = math.abs(heroPos.y) - DETONATE_COORDINATE_Y end
			
			local distance = Vector(heroPos.x - coordinate, heroPos.y, 0):Length()
			local slamshot_xy = math.max( math.min(distance*DETONATE_DISTANCE_MULT_XY, DETONATE_MAXIMAL_VELOCITY_XY), DETONATE_MINIMAL_VELOCITY_XY )
			local slamshot_z = math.max( math.min(distance*DETONATE_DISTANCE_MULT_Z, DETONATE_MAXIMAL_VELOCITY_Z), DETONATE_MINIMAL_VELOCITY_Z )
			
			if ball.vVelocity.z > 0 then
				slamshot_xy = DETONATE_AIR_XY
				slamshot_z = DETONATE_AIR_Z
			end
			
			ball:SetPhysicsVelocity(direction*slamshot_xy + Vector(ballVelocity.x, ballVelocity.y, slamshot_z) )
			Banjoball:RegisterBallHit(caster)
		end

		Banjoball:DestroyCountdownTimer(remoteMine)
		Banjoball:DestroyProjectile(remoteMine)
		ParticleManager:DestroyParticle(remoteMine.bombParticle, true)
	end)
	
	SwapAbilities( caster, "remote_mine", "remote_mine_detonate", ABILITY_SLOT_Q )
	local throw = caster:FindAbilityByName("remote_mine")
	throw:StartCooldown(REMOTE_MINE_COOLDOWN)
end