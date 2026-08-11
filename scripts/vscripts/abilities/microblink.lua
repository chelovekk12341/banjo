microblink = class({})

function microblink:Precache(context)
	PrecacheResource("particle", "particles/items_fx/blink_dagger_start.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/blink_dagger_end.vpcf", context)
end

function microblink:OnSpellStart()
	local caster = self:GetCaster()
	local origin = caster:GetAbsOrigin()
	local target_point = self:GetCursorPosition()

	-- Preventing the hero from blinking while rooted.
	if caster:IsRooted() or caster:HasModifier("modifier_shadowraze_root") then 
		self:EndCooldown() 
		return 
	end


	local dir = (target_point - origin)
	local dist = dir:Length2D()
	
	if dist < 1 then
		dir = caster:GetForwardVector()
	else
		dir = dir:Normalized()
	end

	local blink_range = self:GetSpecialValueFor("blink_range")
	if blink_range <= 0 then blink_range = 350 end

	local blink_dist = math.min(dist, blink_range)
	local newPos = origin + dir * blink_dist

	-- Collision check on field
	local checkPos = newPos
	local enemyTeam = GetHeroEnemy(caster)
	if (not IsPointOnField(checkPos)) or GetGoalPointIsWithin(checkPos) == enemyTeam then
		local distTraveled = 0
		newPos = origin
		while (distTraveled < blink_dist) do
			checkPos = origin + dir * (distTraveled + 10)
			if IsPointOnField(checkPos) and not (GetGoalPointIsWithin(checkPos) == enemyTeam) then
				newPos = checkPos
				distTraveled = distTraveled + 10
			else
				break
			end
		end
	end

	-- Visual effects
	local blink_out_p = ParticleManager:CreateParticle("particles/items_fx/blink_dagger_start.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:ReleaseParticleIndex(blink_out_p)
	caster:EmitSound("DOTA_Item.BlinkDagger.Activate")

	-- Teleportation
	caster.collisionEnabled = false

	caster:SetAbsOrigin(newPos)
	caster:AddNewModifier(caster, nil, "modifier_force_normal_ball_collision", {duration = (FRAME_TIME or 0.033) * 2})

	Timers:CreateTimer(0.03, function()
		caster.collisionEnabled = true
	end)

	local blink_in_p = ParticleManager:CreateParticle("particles/items_fx/blink_dagger_end.vpcf", PATTACH_ABSORIGIN, caster)
	ParticleManager:ReleaseParticleIndex(blink_in_p)
	caster:EmitSound("DOTA_Item.BlinkDagger.Activate")


end
