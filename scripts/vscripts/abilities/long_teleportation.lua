long_teleportation = class({})

function long_teleportation:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_furion/furion_teleport.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/blink_dagger_start.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/blink_dagger_end.vpcf", context)
end

function long_teleportation:OnSpellStart()
	local caster = self:GetCaster()
	local target_point = self:GetCursorPosition()
	self.target_point = target_point

	-- Preventing the hero from teleporting while rooted.
	if caster:IsRooted() or caster:HasModifier("modifier_shadowraze_root") then 
		self:EndCooldown() 
		caster:Interrupt()
		return 
	end

	-- Play cast start sound
	caster:EmitSound("Hero_Furion.Teleport_Cast")

	-- Create teleport particles
	self.teleport_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_furion/furion_teleport.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.teleport_particle, 0, caster:GetAbsOrigin())

	self.target_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_furion/furion_teleport.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.target_particle, 0, target_point)
end

function long_teleportation:OnChannelFinish(bInterrupted)
	local caster = self:GetCaster()

	-- Clean up visual effects
	if self.teleport_particle then
		ParticleManager:DestroyParticle(self.teleport_particle, true)
		ParticleManager:ReleaseParticleIndex(self.teleport_particle)
		self.teleport_particle = nil
	end
	if self.target_particle then
		ParticleManager:DestroyParticle(self.target_particle, true)
		ParticleManager:ReleaseParticleIndex(self.target_particle)
		self.target_particle = nil
	end

	if bInterrupted then
		caster:StopSound("Hero_Furion.Teleport_Cast")
		return
	end

	-- Stop cast sound
	caster:StopSound("Hero_Furion.Teleport_Cast")

	local origin = caster:GetAbsOrigin()
	local target_point = self.target_point or self:GetCursorPosition()

	-- If caster has the ball, drop it at the starting location and make it bounce up
	if Ball.unit and Ball.unit.controller == caster then
		Ball.unit.controller = nil
		caster:AddNewModifier(caster, nil, "modifier_ball_catching_debuff", {duration = 1.0})
		Ball.unit:SetPhysicsVelocity(Vector(0, 0, 450))
	end

	-- Check if target position is on field and not in enemy goals
	local checkPos = target_point
	local enemyTeam = GetHeroEnemy(caster)
	if (not IsPointOnField(checkPos)) or GetGoalPointIsWithin(checkPos) == enemyTeam then
		local dist = (target_point - origin):Length2D()
		local dir = (target_point - origin):Normalized()
		if dist < 1 then dir = caster:GetForwardVector() end
		
		local distTraveled = 0
		checkPos = origin
		while (distTraveled < dist) do
			local testPos = origin + dir * (distTraveled + 10)
			if IsPointOnField(testPos) and not (GetGoalPointIsWithin(testPos) == enemyTeam) then
				checkPos = testPos
				distTraveled = distTraveled + 10
			else
				break
			end
		end
	end
	local newPos = checkPos

	-- Teleportation visual start
	local blink_out_p = ParticleManager:CreateParticle("particles/items_fx/blink_dagger_start.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:ReleaseParticleIndex(blink_out_p)

	-- Teleport unit
	caster.collisionEnabled = false

	caster:SetAbsOrigin(newPos)
	caster:AddNewModifier(caster, nil, "modifier_force_normal_ball_collision", {duration = (FRAME_TIME or 0.033) * 2})

	Timers:CreateTimer(0.03, function()
		caster.collisionEnabled = true
	end)

	-- Teleportation visual end
	local blink_in_p = ParticleManager:CreateParticle("particles/items_fx/blink_dagger_end.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:ReleaseParticleIndex(blink_in_p)
	caster:EmitSound("Hero_Furion.Teleport_End")

	-- Calculate dynamic duration based on distance to the center (0,0)
	-- Closer to center = shorter duration
	local stun_duration_min = self:GetSpecialValueFor("stun_duration_min")
	local stun_duration_max = self:GetSpecialValueFor("stun_duration_max")
	local max_distance_reference = self:GetSpecialValueFor("max_distance_reference")

	if stun_duration_min <= 0 then stun_duration_min = 1.0 end
	if stun_duration_max <= 0 then stun_duration_max = 3.0 end
	if max_distance_reference <= 0 then max_distance_reference = 2500 end

	local dist_to_center = newPos:Length2D()
	local k = math.min(dist_to_center / max_distance_reference, 1.0)
	local dynamic_duration = stun_duration_min + k * (stun_duration_max - stun_duration_min)

	-- Apply stun
	caster:AddNewModifier(caster, self, "modifier_stunned", {duration = dynamic_duration})

	-- If teleporting onto/near the ball, kick it away from the center with half-kick force (800)
	local ball_kicked = false
	if Ball.unit then
		local to_ball = (Ball.unit:GetAbsOrigin() - newPos)
		local dist = to_ball:Length2D()
		if dist <= 120 then
			Ball.unit.controller = nil
			caster:AddNewModifier(caster, nil, "modifier_ball_catching_debuff", {duration = 0.5})
			local kick_dir = to_ball:Normalized()
			if dist < 1 then
				kick_dir = caster:GetForwardVector()
			end
			Ball.unit:SetPhysicsVelocity(kick_dir * 800)
			Banjoball:RegisterBallHit(caster)
			Ball.unit:EmitSound("Kick" .. RandomInt(1, 3))
			ball_kicked = true
		end
	end

	-- Push other heroes and the ball (if not already kicked) outwards weakly to prevent getting stuck inside trees
	local push_targets = {}
	for _, hero in ipairs(Banjoball.vHeroes) do
		if hero ~= caster and hero:IsAlive() then
			local dist = (hero:GetAbsOrigin() - newPos):Length2D()
			if dist <= 180 then
				table.insert(push_targets, hero)
			end
		end
	end
	if Ball.unit and not ball_kicked then
		local dist = (Ball.unit:GetAbsOrigin() - newPos):Length2D()
		if dist <= 180 then
			table.insert(push_targets, Ball.unit)
		end
	end

	for _, unit in ipairs(push_targets) do
		local unit_pos = unit:GetAbsOrigin()
		local to_unit = (unit_pos - newPos)
		local dist = to_unit:Length2D()
		local dir = to_unit:Normalized()
		if dist < 1 then
			local angle = RandomFloat(0, 2 * math.pi)
			dir = Vector(math.cos(angle), math.sin(angle), 0)
		end

		if not unit.SetPhysicsVelocity then
			Banjoball:SetupPhysicsSettings(unit)
		end

		unit:SetPhysicsVelocity(dir * 450)
	end

	-- Spawn trees around the hero
	local num_trees = 8
	local radius = 150
	for i = 1, num_trees do
		local angle = (i - 1) * (2 * math.pi / num_trees)
		local offset = Vector(math.cos(angle), math.sin(angle), 0) * radius
		local tree_pos = newPos + offset
		CreateTempTree(tree_pos, dynamic_duration)
	end
end
