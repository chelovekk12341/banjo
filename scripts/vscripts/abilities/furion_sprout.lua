furion_sprout = class({})

function furion_sprout:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_furion/furion_sprout.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_furion.vsndevts", context)
end

function furion_sprout:CastFilterResultLocation(vLoc)
	if not IsServer() then return end
	
	-- GetGoalPointIsWithin returns team ID if inside goal area, else 0/nil
	local goalTeam = GetGoalPointIsWithin(vLoc)
	if goalTeam and goalTeam ~= 0 then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function furion_sprout:GetCustomCastErrorLocation(vLoc)
	return "dota_hud_error_cant_cast_in_goal"
end

function furion_sprout:OnSpellStart()
	if not IsServer() then return end
	local caster = self:GetCaster()
	local target_point = self:GetCursorPosition()
	
	local duration = self:GetSpecialValueFor("duration")
	local radius = self:GetSpecialValueFor("radius")
	local num_trees = self:GetSpecialValueFor("num_trees")
	local hero_push_force = self:GetSpecialValueFor("hero_push_force")
	local ball_push_force = self:GetSpecialValueFor("ball_push_force")
	
	if duration <= 0 then duration = 2.0 end
	if radius <= 0 then radius = 150 end
	if num_trees <= 0 then num_trees = 8 end
	if hero_push_force <= 0 then hero_push_force = 300 end
	if ball_push_force <= 0 then ball_push_force = 500 end
	
	-- Play cast sound
	caster:EmitSound("Hero_Furion.Sprout")
	
	-- Sprout particle effect
	local sprout_pfx = ParticleManager:CreateParticle("particles/units/heroes/hero_furion/furion_sprout.vpcf", PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleControl(sprout_pfx, 0, target_point)
	ParticleManager:ReleaseParticleIndex(sprout_pfx)
	
	-- Prevent heroes from getting stuck inside trees:
	-- 1. If inside the ring (dist < 140), snap them to the exact center.
	-- 2. If outside the ring but close to trees (140 <= dist <= 220), push them safely outwards.
	for _, hero in ipairs(Banjoball.vHeroes) do
		if hero:IsAlive() then
			local hero_pos = hero:GetAbsOrigin()
			local dist = (hero_pos - target_point):Length2D()
			
			if dist < 140 then
				-- Snap to center so they stand freely inside the sprout ring
				FindClearSpaceForUnit(hero, target_point, true)
			elseif dist >= 140 and dist <= 220 then
				-- Push safely outside the sprout trees
				local dir = (hero_pos - target_point):Normalized()
				if dist < 1 then
					dir = caster:GetForwardVector()
				end
				local safe_pos = target_point + dir * 230
				FindClearSpaceForUnit(hero, safe_pos, true)
				
				if not hero.SetPhysicsVelocity then
					Banjoball:SetupPhysicsSettings(hero)
				end
				hero:SetPhysicsVelocity(dir * 450)
			end
		end
	end
	
	-- If the ball is OUTSIDE the trees ring but close to them, push it outwards.
	-- If the ball is INSIDE (dist < 140), it remains untouched.
	if Ball.unit then
		local ball_pos = Ball.unit:GetAbsOrigin()
		local dist = (ball_pos - target_point):Length2D()
		if dist >= 140 and dist <= 220 then
			local dir = (ball_pos - target_point):Normalized()
			if dist < 1 then
				dir = caster:GetForwardVector()
			end
			if not Ball.unit.SetPhysicsVelocity then
				Banjoball:SetupPhysicsSettings(Ball.unit)
			end
			Ball.unit:SetPhysicsVelocity(dir * 500)
		end
	end
	
	-- Provide FOW vision around the sprout for both teams, ignoring obstruction by trees
	AddFOWViewer(2, target_point, 250, duration, false) -- DOTA_TEAM_GOODGUYS
	AddFOWViewer(3, target_point, 250, duration, false) -- DOTA_TEAM_BADGUYS
	
	-- Spawn trees in a circle
	for i = 1, num_trees do
		local angle = (i - 1) * (2 * math.pi / num_trees)
		local offset = Vector(math.cos(angle), math.sin(angle), 0) * radius
		local tree_pos = target_point + offset
		CreateTempTree(tree_pos, duration)
	end
end
