function Banjoball:text_particle( keys )
	local caster = keys.caster
	if not caster then print("text_particle, caster nil") return end

	local abilName = ""
	if keys.ability then
		abilName = keys.ability:GetAbilityName()
	end

	-- remove the current text particle above the caster, if any. to avoid clutter
	if caster.textParticle then
		if type(caster.textParticle) == "table" then
			for i,v in ipairs(caster.textParticle) do
				ParticleManager:DestroyParticle(v, true)
			end
		else
			ParticleManager:DestroyParticle(caster.textParticle, true)
		end
		caster.textParticle = nil
	end

	local particle = "particles/pass_me.vpcf"

	if abilName == "item_frown" then
		local frownIndex = RandomInt(1, NUM_FROWNS)
		--local frownIndex = 3
		particle = "particles/frowns/frown" .. frownIndex .. ".vpcf"

		-- helps reduce spam
		if caster.tauntItem then
			caster.tauntItem:StartCooldown(SMILEY_COOLDOWN)
		end
		EmitSoundOnClient("Item_Click", caster:GetPlayerOwner())

	elseif abilName == "item_taunt" then
		local tauntIndex = RandomInt(1, NUM_TAUNTS)
		particle = "particles/taunts/taunt" .. tauntIndex .. ".vpcf"

		-- helps reduce spam
		if caster.frownItem then
			caster.frownItem:StartCooldown(SMILEY_COOLDOWN)
		end
		EmitSoundOnClient("Item_Click", caster:GetPlayerOwner())
	end

	if abilName == "pass_me" then
		local parts = {}
		for _,hero in pairs(Banjoball.vHeroes) do
			if hero:GetTeam() == caster:GetTeam() then
				local part = ParticleManager:CreateParticleForPlayer(particle, PATTACH_OVERHEAD_FOLLOW, caster, hero:GetPlayerOwner())
				ParticleManager:SetParticleControl(part, 1, Vector(0,255,0))
				table.insert(parts, part)
			end
		end
		caster.textParticle = parts

	elseif abilName == "item_frown" or abilName == "item_taunt" then
		local parts = {}
		for _,hero in pairs(Banjoball.vHeroes) do
			local part = ParticleManager:CreateParticleForPlayer(particle, PATTACH_OVERHEAD_FOLLOW, caster, hero:GetPlayerOwner())
			if hero:GetTeam() == caster:GetTeam() then
				ParticleManager:SetParticleControl(part, 1, Vector(0,255,0))
			else
				ParticleManager:SetParticleControl(part, 1, Vector(255,0,0))
			end
			table.insert(parts, part)
		end
		caster.textParticle = parts
	elseif keys.stolen then
		local parts = {}
		for _,hero in pairs(Banjoball.vHeroes) do
			local part = nil
			if hero:GetTeam() ~= caster:GetTeam() then
				part = ParticleManager:CreateParticleForPlayer("particles/stolen_badguys/tusk_rubickpunch_txt.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster, hero:GetPlayerOwner())
			else
				part = ParticleManager:CreateParticleForPlayer("particles/stolen/tusk_rubickpunch_txt.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster, hero:GetPlayerOwner())
			end
			ParticleManager:SetParticleControlEnt(part, 4, caster, 4, "follow_origin", caster:GetAbsOrigin(), true)
			table.insert(parts, part)
		end
		caster.textParticle = parts

	end

	if not caster.textParticle then
		if keys.exclamation then
			particle = "particles/exclamation.vpcf"
			caster.textParticle = ParticleManager:CreateParticle(particle, PATTACH_ABSORIGIN, caster)
		else
			caster.textParticle = ParticleManager:CreateParticle(particle, PATTACH_OVERHEAD_FOLLOW, caster)
		end
		if caster:GetTeam() == DOTA_TEAM_GOODGUYS then
			ParticleManager:SetParticleControl(caster.textParticle, 1, Vector(0,255,0))
		else
			ParticleManager:SetParticleControl(caster.textParticle, 1, Vector(255,0,0))
		end
		ParticleManager:SetParticleControlEnt(caster.textParticle, 3, caster, 3, "follow_origin", caster:GetAbsOrigin(), true)
	end

end
