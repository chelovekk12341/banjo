-- This function is called whenever "SUPER SPRINT" ability is used.
function Banjoball:super_sprint( keys )
	local caster = keys.caster

	if caster:HasModifier("modifier_shadowraze_root") then
		caster:GiveMana(10)
		caster:CastAbilityNoTarget(caster:FindAbilityByName("super_sprint_break"), 0)
		return
	end
	
	SwapAbilities( caster, "super_sprint_break", "super_sprint", ABILITY_SLOT_E )
	
	caster.surgeParticle = ParticleManager:CreateParticle("particles/heroes/anti_mage/super_sprint/super_sprint.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControl(caster.surgeParticle, 1, caster.colArr[COLOR_INDEX_BASE])
	ParticleManager:SetParticleControl(caster.surgeParticle, 2, caster.colArr[COLOR_INDEX_LIGHT])
	ParticleManager:SetParticleControl(caster.surgeParticle, 3, caster.colArr[COLOR_INDEX_DARK])
	ParticleManager:SetParticleControl(caster.surgeParticle, 5, caster.colArr[COLOR_INDEX_DARKEST])

	caster:AddNewModifier(caster,nil,"modifier_self_root", {duration = 99999})
	caster:AddPhysicsVelocity(caster:GetForwardVector():Normalized() * SUPER_SPRINT_BASE_VELOCITY)

	local iterator = 0
	Timers:CreateTimer(function()
		if not caster.surgeOn then return
		elseif caster:HasModifier("modifier_shadowraze_root") then
			caster:CastAbilityNoTarget(caster:FindAbilityByName("super_sprint_break"), 0)
			return
		end

		local mult = math.min(iterator * SUPER_SPRINT_GAIN + SUPER_SPRINT_MIN_SPEED, 1)
		local speed = SUPER_SPRINT_ACCELERATION*mult

		caster:AddPhysicsVelocity(caster:GetForwardVector():Normalized() * speed)

		if #GetUnitsInTrueRadius(caster:GetAbsOrigin(), SUPER_SPRINT_NOHERO_RADIUS) > 1 then
			Banjoball:SlamNearby(caster, caster:GetAbsOrigin(), SUPER_SPRINT_NOHERO_RADIUS, SUPER_SPRINT_KNOCKBACK_XY, 0, SUPER_SPRINT_NOHERO_RADIUS, function(caster, entity, direction, slam_xy, slam_z)
				if entity ~= caster and entity ~= Ball.unit then return (direction*slam_xy + Vector(0, 0, slam_z)) end
				
				return Vector(0, 0, 0)
			end)
		end
		
		iterator = iterator + SUPER_SPRINT_TICK
			--print( string.format( "Velocity = %d", caster.vVelocity:Length()*30 ), string.format( "increase = %.2f", mult ), "at", iterator )

		return SUPER_SPRINT_TICK
	end)

	caster:EmitSound("Hero_Weaver.Shukuchi")

	-- this is for animation purposes. We also needed to add "OverrideAnimation" "ACT_DOTA_RUN" in the super_sprint ability for this to work.
	-- because the rooted sets movespeed to 0, which causes ACT_DOTA_RUN to never be called.
	caster:AddNewModifier(caster, nil, "modifier_rune_haste", {})

	-- root hero so the haste movespeed doesn't influence him
	if not caster:HasModifier("modifier_haste_anim") then
		GlobalDummy.dummy_passive:ApplyDataDrivenModifier(GlobalDummy, caster, "modifier_haste_anim", {})
	end
end

function Banjoball:super_sprint_break( keys )
	local caster = keys.caster
	caster.surgeOn = false
	
	SwapAbilities( caster, "super_sprint", "super_sprint_break", ABILITY_SLOT_E )

	if caster:HasModifier("modifier_rune_haste") then
		caster:RemoveModifierByName("modifier_rune_haste")
	end
	
	if caster:HasModifier("modifier_haste_anim") then
		caster:RemoveModifierByName("modifier_haste_anim")
	end

	if caster:HasModifier("modifier_self_root") then
		caster:RemoveModifierByName("modifier_self_root")
	end
end

function Banjoball:ManaSteal( ... )
	args = {...}
	local targ = args[2]
	local hero = args[1]
	local thrucol = args[3]
	if not thrucol then
		thrucol = 0
	end
	local ball = Ball.unit
	if targ:GetTeam() ~= hero:GetTeam() and (ball.trailColor == targ.ballCol or thrucol == 1) then
		manadrainamount = targ:GetMana() * MANA_STEAL_AMOUNT
		targ:SetMana(targ:GetMana() - manadrainamount)
		hero:SetMana(hero:GetMana() + manadrainamount)
		local curveshotManaParticle = ParticleManager:CreateParticle( "particles/heroes/anti_mage/mana_drain.vpcf", PATTACH_ABSORIGIN_FOLLOW, ball.particleDummy )
		ParticleManager:SetParticleControl( curveshotManaParticle, 0, targ:GetAbsOrigin())
		ParticleManager:SetParticleControlEnt( curveshotManaParticle, 1, targ, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", targ:GetAbsOrigin(), true )
		targ:EmitSound("Hero_Warlock.ShadowWordCastGood")
	end
end