LinkLuaModifier("modifier_skewer_stun_lua", "abilities/skewer", LUA_MODIFIER_MOTION_NONE)

skewer = class({})

function skewer:GetCastRange(vLocation, hTarget)
	return 1200
end

function skewer:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	local casterPos = caster:GetAbsOrigin()
	local times = math.floor(math.max(math.min((casterPos-point):Length(), SKEWER_DISTANCE), SKEWER_MINIMAL_DIST) / SKEWER_DIST_PER_TICK)
	
	-- Preventing the hero from dashing while rooted or if not on the ground.
	if caster:HasModifier("modifier_shadowraze_root") or caster:GetAbsOrigin().z > GROUND_Z then
		self:EndCooldown()
		self:StartCooldown(0.1)
		return
	end

	if (point - caster:GetAbsOrigin()):Length() > 10 then caster:SetForwardVector((point-caster:GetAbsOrigin()):Normalized()) end
	
	caster:AddNewModifier(caster, self, "modifier_skewer_stun_lua", {})
	caster.remainingTimer = Timers:CreateTimer(function()
		if times <= 0 or caster:HasModifier("modifier_shadowraze_root") then
			caster:RemoveModifierByName("modifier_skewer_stun_lua")
			return
		end
		
		local dir = caster:GetForwardVector():Normalized()
		local casterPos = caster:GetAbsOrigin()
		local perp = Vector(-dir.y, dir.x, 0):Normalized()
		local corners = {}
		
		corners[0] = casterPos - (perp * 0)
		corners[1] = casterPos + (perp * 0)
		corners[2] = casterPos + (perp * 0)
		corners[3] = casterPos - (perp * 0)
		
		-- Validating a teleportation position and computing a new one if it's outside the field.
		local newPos = casterPos + dir * SKEWER_DIST_PER_TICK
		local checkPos = newPos
		if (not IsPointOnField(checkPos)) then
			-- Resetting the teleportation position and starting a cycle. The cycle validates every position in the 10-unit range until it finds a wall or the goal line.
			newPos = caster:GetAbsOrigin()
			while (true) do
				checkPos = newPos + 10*dir
				if (not IsPointOnField(checkPos)) then break end
				newPos = checkPos
			end
		end
		caster:SetAbsOrigin(newPos)
		
		if #GetUnitsInTrueRadius(caster:GetAbsOrigin(), SKEWER_AOE) > 1 then
			Banjoball:SlamNearby(caster, caster:GetAbsOrigin(), SKEWER_AOE, SKEWER_FORCE, 0, SKEWER_AOE, function(caster, entity, direction, slam_xy, slam_z)
				if entity ~= caster and entity ~= Ball.unit then return (direction*slam_xy + Vector(0, 0, slam_z)) end
				
				return Vector(0, 0, 0)
			end)
		end

		times = times - 1
		return .03
	end)

	caster:EmitSound("Hero_Magnataur.Skewer.Cast")
end

modifier_skewer_stun_lua = class({})

function modifier_skewer_stun_lua:IsHidden() return true end

function modifier_skewer_stun_lua:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
	}
end

function modifier_skewer_stun_lua:GetOverrideAnimation()
	return ACT_DOTA_CAST_ABILITY_3
end