function Banjoball:truesight( keys )
	local caster = keys.caster
	for _,hero in ipairs(Banjoball.vHeroes) do
		if hero ~= caster then
			hero:MakeVisibleToTeam(1, 9999)
		end
	end
end
