activeProjectiles = {}

function Banjoball:CreateProjectile(projIndex, caster, radius, initVel, friction, startPos, nocfriction)
	local projectile = CreateUnitByName("dummy", caster:GetAbsOrigin(), false, nil, nil, DOTA_TEAM_FIRST)
	projectile:SetAbsOrigin(startPos or caster:GetAbsOrigin())
	-- It puts the projectile back to the field.
	local projectilePos = projectile:GetAbsOrigin()
	if not IsPointOnField(projectilePos) then
		projectile:SetAbsOrigin(ClosestPointOnField(projectilePos))
	end
	
	projectile.caster = caster
	projectile.__isProjectile = true
	projectile.__isProjectileActive = true
	projectile.__projectileCollisionRadius = radius
	projectile.__projectileType = projIndex
	
	projectile.onProjectileCollision = function( collided ) 
		return false
	end
	
	projectile.onProjectileGoalCollision = function( goal )
		return Banjoball:GetProjectileTeam(projectile) ~= goal.team
	end
	
	-- Set up Physics
	Banjoball:SetupPhysicsSettings( projectile )
	projectile.colliderID = DoUniqueString("a")
	Banjoball.colliderFilter[projectile.colliderID] = projectile
	projectile:SetPhysicsVelocity(initVel)
	if friction then
		projectile:SetPhysicsFriction(friction)
		-- Ensure frictionless projectiles don't change friction
	end
	if nocfriction == true then
		projectile.dontChangeFriction = true
	end
	projectile.lastBounceTime = 0
	projectile.lastPos = Vector(0,0,GroundZ)
	projectile:OnPhysicsFrame(function(unit)
		Banjoball:OnMyPhysicsFrame(projectile)
	end)
	
	table.insert(activeProjectiles, projectile)
	
	return projectile
end

function Banjoball:DestroyProjectile( projectile )
	projectile.__isProjectileActive = false
	projectile:StopPhysicsSimulation()
	projectile: SetOriginalModel("models/development/invisiblebox.vmdl") -- In case a model change occurred 
	projectile:SetAbsOrigin(Vector(10000,10000,1000)) -- Just in case the kill causes issues (hint, it does)
	projectile:ForceKill(true)
	Banjoball.colliderFilter[projectile.colliderID] = nil
	projectile.__isProjectile = false
	for i=1, #activeProjectiles do
		if activeProjectiles[i] == projectile then
			table.remove(activeProjectiles, i)
			return nil
		end
	end
end

function Banjoball:IterateProjectiles( fun )
	for i=1, #activeProjectiles do
		if not activeProjectiles[i].noIter then 
			fun(activeProjectiles[i])
		end
	end
end

--[[
	PROJECTILES:
	PROJECTILE_INDEX_SWAP =  1
	PROJECTILE_INDEX_HOOK =  2
]]--

--[[
	Random accessor functions:
]]--

function Banjoball:IsProjectile( unit )
	return unit.__isProjectile
end

function Banjoball:IsProjectileActive( projectile )
	return projectile.__isProjectileActive
end


function Banjoball:ActivateProjectile( projectile )
	projectile.__isProjectileActive = true
end

function Banjoball:DisableProjectile( projectile )
	projectile.__isProjectileActive = false
end

function Banjoball:GetProjectileTeam( projectile )
	local caster = projectile.caster
	return caster:GetTeam()
end
