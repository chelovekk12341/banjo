function Banjoball:surge( keys )
	local caster = keys.caster
	local ball = Ball.unit

	caster.surgeOn = true
	
	if caster.isSprinter then self:super_sprint(keys)
	elseif caster.isWeaver then
		if (caster:GetMana() < WEAVER_MIN_MANA) then caster.surgeOn = false return end
		self:shukuchi_sprint(keys)
	elseif caster.isDemon then
		if (caster ~= ball.controller) or (caster:GetMana() < DEMON_MIN_MANA) then caster.surgeOn = false return end
		self:demonic_endurance(keys)
	elseif caster.isCurveshot then self:ball_lightning(keys)
	else
		SwapAbilities( caster, "surge_break", "surge", ABILITY_SLOT_E )

		if caster:GetClassname() == "npc_dota_hero_slark" then 
			if caster.pritaica then
				caster:CastAbilityNoTarget(caster:FindAbilityByName("ninja_invis_sprint_break"), 0) 
			end
		end
		
		caster.surgeParticle = ParticleManager:CreateParticle("particles/items2_fx/phase_boots.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
		caster:EmitSound("DOTA_Item.PhaseBoots.Activate")
	end
end

function Banjoball:surge_break( keys )
	local caster = keys.caster
	caster.surgeOn = false
	local ball = Ball.unit

	if caster.isSprinter then
		self:super_sprint_break( keys )
	elseif caster.isWeaver then
		self:shukuchi_sprint_break( keys )
	elseif caster.isDemon then
		self:demonic_endurance_break( keys )
	elseif caster.isCurveshot then
		self:ball_lightning_break(keys)
	else
		SwapAbilities( caster, "surge", "surge_break", ABILITY_SLOT_E )
	end

	if caster.surgeParticle then
		ParticleManager:DestroyParticle(caster.surgeParticle, false)
		caster.surgeParticle = nil
	end

	caster.sprintFinihsedAt = GameRules:GetGameTime()
	caster.SprintLast = caster.SprintMult
end