--////////////////////////////////////--
--           Debug Config             --
--////////////////////////////////////--

-- When true: spawns 9 hero units at game start to visualize all 10 spawn positions.
-- Their coordinates (X, Y, Z) and hero names are printed to console.
-- Set to false for normal gameplay.
DEBUG_SPAWN_BOTS = false

-- Heroes to use for debug bots (one per slot, 9 total)
-- Dynamically loaded from herolist.txt to ensure only active heroes are spawned
DEBUG_BOT_HEROES = {}
if LoadKeyValues then
	local herolist = LoadKeyValues("scripts/npc/herolist.txt")
	if herolist then
		local heroes = herolist.CustomHeroList or herolist
		for heroName, enabled in pairs(heroes) do
			if tostring(enabled) == "1" or enabled == 1 then
				table.insert(DEBUG_BOT_HEROES, heroName)
			end
		end
	end
end

-- Fallback heroes if herolist.txt load fails
if #DEBUG_BOT_HEROES == 0 then
	DEBUG_BOT_HEROES = {
		"npc_dota_hero_antimage",
		"npc_dota_hero_bloodseeker",
		"npc_dota_hero_earthshaker",
		"npc_dota_hero_invoker",
		"npc_dota_hero_lina",
		"npc_dota_hero_juggernaut",
		"npc_dota_hero_pudge",
		"npc_dota_hero_nevermore",
		"npc_dota_hero_void_spirit",
	}
end

