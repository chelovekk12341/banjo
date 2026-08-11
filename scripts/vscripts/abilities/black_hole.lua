black_hole = class({})

function black_hole:Precache(context)
	PrecacheResource("particle", "particles/units/heroes/hero_enigma/enigma_blackhole.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/blink_dagger_start.vpcf", context)
end

function black_hole:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function black_hole:OnSpellStart()
	local caster = self:GetCaster()
	local target_point = self:GetCursorPosition()
	local duration = self:GetSpecialValueFor("channel_time")
	local radius = self:GetSpecialValueFor("radius")

	-- Create Black Hole visual effect
	self.particle = ParticleManager:CreateParticle("particles/units/heroes/hero_enigma/enigma_blackhole.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.particle, 0, target_point)

	-- Play cast sound
	caster:EmitSound("Hero_Enigma.Black_Hole")

	-- Thinker to pull units
	local tick = 0.03
	local pull_force = 60 -- force per tick (45 * 30 ticks = 1350 velocity per second)

	self.captured_units = {}

	-- Мгновенный захват целей в радиусе при старте (на случай моментальной отмены)
	local init_targets = {}
	for _, hero in ipairs(Banjoball.vHeroes) do
		if hero:IsAlive() then
			table.insert(init_targets, hero)
		end
	end
	if Ball.unit and not Ball.unit.controller then
		table.insert(init_targets, Ball.unit)
	end

	for _, unit in ipairs(init_targets) do
		if not (unit.goalie or (unit.HasModifier and unit:HasModifier("modifier_goalie"))) then
			local unit_pos = unit:GetAbsOrigin()
			local to_center = (target_point - unit_pos)
			local dist = to_center:Length()

			if dist <= radius then
				self.captured_units[unit] = true
			end
		end
	end

	-- Swap abilities to allow canceling with the same hotkey
	caster:SwapAbilities("black_hole", "black_hole_stop", false, true)

	Timers:CreateTimer(function()
		if not caster:IsChanneling() or not caster:IsAlive() then
			return nil
		end

		-- Scan all heroes and the ball
		local targets = {}
		for _, hero in ipairs(Banjoball.vHeroes) do
			if hero:IsAlive() then
				table.insert(targets, hero)
			end
		end
		if Ball.unit and not Ball.unit.controller then
			table.insert(targets, Ball.unit)
		end

		for _, unit in ipairs(targets) do
			-- Goalkeeper is immune to Black Hole
			if not (unit.goalie or (unit.HasModifier and unit:HasModifier("modifier_goalie"))) then
				local unit_pos = unit:GetAbsOrigin()
				local to_center = (target_point - unit_pos)
				local dist = to_center:Length()

				if dist <= radius then
					-- Track unit as captured in this black hole cast
					self.captured_units[unit] = true

					-- Pull unit towards center
					local dir = to_center:Normalized()

					if not unit.SetPhysicsVelocity then
						Banjoball:SetupPhysicsSettings(unit)
					end

					unit:AddPhysicsVelocity(dir * pull_force)
				end
			end
		end

		return tick
	end)
end

function black_hole:OnChannelFinish(bInterrupted)
	local caster = self:GetCaster()
	local target_point = self:GetCursorPosition()

	-- Stop cast sound
	caster:StopSound("Hero_Enigma.Black_Hole")

	-- Play end sound
	caster:EmitSound("Hero_Enigma.Black_Hole.Stop")

	-- Destroy particle
	if self.particle then
		ParticleManager:DestroyParticle(self.particle, false)
		ParticleManager:ReleaseParticleIndex(self.particle)
		self.particle = nil
	end

	-- Restore the original ability
	if caster:HasAbility("black_hole_stop") and not caster:FindAbilityByName("black_hole_stop"):IsHidden() then
		caster:SwapAbilities("black_hole_stop", "black_hole", false, true)
	end

	-- Launch all captured units outwards (acceleration trajectory)
	if self.captured_units then
		-- Больше не выбиваем мяч из рук героя при взрыве черной дыры.
		-- Мяч останется у своего владельца.

		for unit, _ in pairs(self.captured_units) do
			if unit and not unit:IsNull() and (unit.IsAlive == nil or unit:IsAlive()) then
				local unit_pos = unit:GetAbsOrigin()
				local to_unit = (unit_pos - target_point)
				local dist = to_unit:Length()
				local dir = to_unit:Normalized()

				-- Handle unit exactly at center
				if dist < 10 then
					local angle = RandomFloat(0, 2 * math.pi)
					dir = Vector(math.cos(angle), math.sin(angle), 0)
				end

				if not unit.SetPhysicsVelocity then
					Banjoball:SetupPhysicsSettings(unit)
				end

				-- Launch outward with high speed (slingshot/explosion effect)
				unit:SetPhysicsVelocity(dir * 1500)

				-- Small teleport/burst visual effect
				local launch_p = ParticleManager:CreateParticle("particles/items_fx/blink_dagger_start.vpcf", PATTACH_ABSORIGIN, unit)
				ParticleManager:ReleaseParticleIndex(launch_p)
			end
		end
		self.captured_units = {}
	end
end

--------------------------------------------------------------------------------

black_hole_stop = class({})

function black_hole_stop:OnSpellStart()
	local caster = self:GetCaster()
	caster:Interrupt()
end
