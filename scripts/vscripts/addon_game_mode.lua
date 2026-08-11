requires = {
	'config',
	'timers',
	'util',
	'physics',
	'modifiers.newsprint',
	'modifiers.modifier_unlimited_casting',
	'banjoball',
	'ai.bot_think',
	'mechanics.hero_think',
	'database.supabase_api',
	'mechanics.chat_commands',
	'mechanics.tempest_double',
	'draft',
	'initmap',
	'myphysics',
	'ability_proxy',
	'constants',
	'order_filter',
	
	'hero_selection.root',
	'hero_selection.replace_hero',
	
	'mechanics.ball',
	'mechanics.goal',
	'mechanics.kick',
	'mechanics.projectile',
	'mechanics.referee',
	'mechanics.sprint',
	'mechanics.text_particle',
	'mechanics.ability_util',
	'mechanics.truesight',

	'rofls.fake_injury',
	'rofls.high_five_custom',
	'rofls.range_custom',
	'mechanics.ball_effects',
	
	'abilities.backflip',
	'abilities.hook',
	'abilities.ogre_smash',
	'abilities.invoker_powerdash',
	'abilities.powershot',
	'abilities.pull',
	'abilities.slam',
	'abilities.skewer',
	'abilities.shadowraze',
	'abilities.become_oak',
	'abilities.shadow_step',
	'abilities.spectre_passive',
	'abilities.primal_beast_onslaught',
	'abilities.primal_beast_passive',
	'abilities.silencer_glaive_kick',
	'abilities.silencer_kick',
	'abilities.dissimilate_exit',
	
	'modifiers.goalspeed',
	'modifiers.unstuckmec',
	'modifiers.self_root',
	'modifiers.ninjainvis',
	'modifiers.manareg',
	'modifiers.metamorphosis',
	'modifiers.root_and_silence',
	'modifiers.root_full',
	'modifiers.mod_ball_slow',
	'modifiers.clockcog_slow',
	'modifiers.ball_catching_debuff',
	'modifiers.ball_catching_disable',
	'modifiers.night_speed',
	'modifiers.shukuchi',
	'modifiers.demonic_sprint',
	'modifiers.force_normal_ball_collision',
	
	'sprints.ball_lightning',
	'sprints.demonic_endurance',
	'sprints.shukuchi_sprint',
	'sprints.stealth_sprint',
	'sprints.super_sprint',

	'ui.hud',
	'ui.tips',
	'ui.toasts',
}

function Precache( context )
	print("[BANJOBALL] Performing pre-load precache")

	Timers:CreateTimer(1, function()
		PrecacheContext = context
	end)

	-- Particles can be precached individually or by folder
	-- It it likely that precaching a single particle system will precache all of its children, but this may not be guaranteed
	--PrecacheResource("particle", "particles/econ/generic/generic_aoe_explosion_sphere_1/generic_aoe_explosion_sphere_1.vpcf", context)
	PrecacheResource("particle_folder", "particles/ball", context)
	PrecacheResource("particle_folder", "particles/thunderclap", context)
	PrecacheResource("particle_folder", "particles/frowns", context)
	PrecacheResource("particle_folder", "particles/taunts", context)
	PrecacheResource("particle_folder", "particles/powershot", context)
	PrecacheResource("particle_folder", "particles/slam", context)
	PrecacheResource("particle_folder", "particles/time_walk", context)
	PrecacheResource("particle_folder", "particles/saved_txt", context)
	PrecacheResource("particle_folder", "particles/scored_txt", context)
	PrecacheResource("particle_folder", "particles/stolen", context)
	PrecacheResource("particle_folder", "particles/stolen_badguys", context)
	PrecacheResource("particle_folder", "particles/tornado", context)
	PrecacheResource("particle_folder", "particles/golden_doomling", context)
	PrecacheResource("particle_folder", "particles/enhanced_kick", context)
	PrecacheResource("particle_folder", "particles/lina_tether", context)
	PrecacheResource("particle_folder", "particles/illusory_orb", context)
	PrecacheResource("particle_folder", "particles/pudge_hook", context)
	PrecacheResource("particle_folder", "particles/curveshot", context)
	PrecacheResource("particle_folder", "particles/timers", context)
	PrecacheResource("particle_folder", "particles/timer", context)
	PrecacheResource("particle_folder", "particles/blink", context)
	PrecacheResource("particle_folder", "particles/team_auras", context)
	PrecacheResource("particle_folder", "particles/ball_lightning", context)
	PrecacheResource("particle_folder", "particles/time_lapse", context)
	PrecacheResource("particle_folder", "particles/ball/air_trail", context)
	PrecacheResource("particle_folder", "particles/ui_mouseactions", context)
	PrecacheResource("particle_folder", "particles/high_five/mug", context)
	PrecacheResource("particle_folder", "particles/high_five/agh_2021", context)
	PrecacheResource("particle_folder", "particles/high_five/fall_2021", context)
	PrecacheResource("particle_folder", "particles/high_five/crownfall", context)
	PrecacheResource("particle_folder", "particles/high_five/newbloom_dragon", context)
	PrecacheResource("particle_folder", "particles/high_five/poogie", context)
	PrecacheResource("particle_folder", "particles/high_five/dark_carnival", context)
	PrecacheResource("particle_folder", "particles/high_five/zombie", context)
	PrecacheResource("particle_folder", "particles/high_five/soap", context)
	PrecacheResource("particle_folder", "particles/high_five/mitten", context)
	PrecacheResource("particle_folder", "particles/high_five/cat_paw", context)
	PrecacheResource("particle_folder", "particles/high_five/midas", context)
	PrecacheResource("particle", "particles/abilities/general/glyph/glyph.vpcf", context)

	PrecacheResource("particle", "particles/units/heroes/hero_wisp/wisp_tether.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_pugna/pugna_life_drain.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_pugna/pugna_life_drain.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dark_seer/dark_seer_surge.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_spirit_breaker/spirit_breaker_charge.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/rune_haste_owner.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_medusa/medusa_mana_shield_impact.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_medusa/medusa_mana_shield_mod.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_medusa/medusa_mana_shield_oom.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_medusa/medusa_mana_shield_shell_add.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/courier_shield.vpcf", context)
	PrecacheResource("particle", "particles/courier_shield.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_medusa/medusa_mana_shield_oval_endcap.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_medusa/medusa_mana_shield.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_frost_nova_sphere_1.vpcf", context)
	PrecacheResource("particle", "particles/immunity_sphere_buff.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_nevermore/nevermore_shadowraze_ground_cracks.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_nevermore/nevermore_requiemofsouls_ground_cracks.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_brewmaster/brewmaster_thunder_clap.vpcf", context)
	PrecacheResource("particle", "particles/items2_fx/phase_boots.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/earthshaker/earthshaker_gravelmaw/earthshaker_fissure_gravelmaw.vpcf", context)
	PrecacheResource("particle", "particles/medusa_mana_shield_impact_highlight01.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/earthshaker/egteam_set/hero_earthshaker_egset/earthshaker_echoslam_egset.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_bounty_hunter/bounty_hunter_windwalk.vpcf", context)
	PrecacheResource("particle", "particles/ninja_invis_sprint/dark_seer_surge.vpcf", context)
	PrecacheResource("particle", "particles/pass_me.vpcf", context)
	PrecacheResource("particle", "particles/exclamation.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_meepo/meepo_earthbind.vpcf", context)
	
	-- Goal.lua
	PrecacheResource("particle", "particles/scored_txt/tusk_rubickpunch_txt.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_tusk/tusk_snowball_impact.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_tusk/tusk_ice_shards_projectip.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/tuskarr/tusk_ti5_immortal/tusk_ice_shards_projectile_stout_flek.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_keeper_of_the_light/keeper_of_the_light_chakra_magic.vpcf", context)
	PrecacheResource("particle", "particles/econ/courier/courier_trail_05/courier_trail_05.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_templar_assassin/templar_assassin_trap_explode.vpcf", context)
	PrecacheResource("particle", "particles/legion_duel_victory/legion_commander_duel_victory.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/ti4/blink_dagger_end_ti4.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/ti5/blink_dagger_end_ti5.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_magnataur/magnataur_shockwave.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_razor/razor_static_link.vpcf", context)
	PrecacheResource("particle", "particles/ranged_badguy_persistent_green.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/puck/puck_alliance_set/puck_waning_rift_aproset.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/blink_dagger_start.vpcf", context)
	PrecacheResource("particle", "particles/ghost_model.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_bloodseeker/bloodseeker_rupture.vpcf", context)
	PrecacheResource("particle", "particles/batrider_stickynapalm_stack.vpcf", context)
	--PrecacheResource("particle", "particles/units/heroes/hero_pudge/pudge_meathook_chain.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_pudge/pudge_meathook_impact.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_brewmaster/brewmaster_thunder_clap", context)

	
	-- Jump
	PrecacheResource("particle", "particles/units/heroes/hero_rubick/rubick_telekinesis.vpcf", context)

	-- Anti-Mage
	PrecacheResource("particle_folder", "particles/heroes/anti_mage/super_sprint", context)
	PrecacheResource("particle", "particles/heroes/anti_mage/mana_drain.vpcf", context)

	-- Bloodseeker
	PrecacheResource("particle", "particles/units/heroes/hero_life_stealer/life_stealer_infest_emerge_bloody.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_centaur/centaur_double_edge_bloodspray_src.vpcf", context)
	PrecacheResource("particle", "particles/ghost_model.vpcf", context)

	-- Earthshaker
	PrecacheResource("particle_folder", "particles/units/heroes/hero_earthshaker", context)
	PrecacheResource("particle_folder", "particles/abilities/heroes/earthshaker/slam", context)

	-- Juggernaut
	PrecacheResource("particle", "particles/econ/items/juggernaut/jugg_arcana/juggernaut_arcana_omni_slash_trail_dust_l.vpcf", context)

	-- Ogre
	PrecacheResource("particle", "particles/ogre_smash/ogre_magi_ogresmash_start.vpcf", context)
	
	-- Puck
	PrecacheResource("particle", "particles/units/heroes/hero_puck/puck_illusory_orb.vpcf", context)
	PrecacheResource("particle_folder", "particles/heroes/puck/illusory_orb", context)
	
	-- Clockwerk
	PrecacheResource("particle_folder", "particles/heroes/clockwerk", context)
	-- Techies
	PrecacheResource("particle_folder", "particles/heroes/techies", context)	
	-- lina
	PrecacheResource("particle_folder", "particles/heroes/lina", context)

	-- Storm
	PrecacheResource("particle_folder", "particles/curveshot", context)
	PrecacheResource("particle", "particles/econ/items/razor/razor_punctured_crest/razor_storm_lightning_strike_blade.vpcf", context)

	-- Terrorblade
	PrecacheResource("particle", "particles/aghanim_beam_burn.vpcf", context)

	PrecacheResource("particle", "particles/generic_gameplay/radiant_fountain_regen.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_brewmaster/brewmaster_fire_ambient.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_jakiro/jakiro_liquid_fire_ready.vpcf", context)
	PrecacheResource("particle", "particles/econ/courier/courier_golden_doomling/courier_golden_doomling_ambient.vpcf", context)
	PrecacheResource("particle", "particles/econ/courier/courier_snapjaw/courier_snapjaw_ambient_rocket_sparks.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_techies/techies_suicide_sparks.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/doom/doom_f2p_death_effect/doom_bringer_f2p_death_sigil_c.vpcf", context)
	PrecacheResource("particle", "particles/econ/courier/courier_murrissey_the_smeevil/courier_murrissey_the_smeevil.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/windrunner/windrunner_cape_cascade/windrunner_cape_cascade_ambient.vpcf", context)
	
	


	-- STORE HIGH FIVE
	PrecacheResource("particle", "particles/high_five/fall_2021/high_five_fall_2021_overhead.vpcf", context)
	PrecacheResource("particle", "particles/high_five/fall_2021/high_five_fall_2021_overhead_model.vpcf", context)
	PrecacheResource("particle", "particles/high_five/fall_2021/high_five_fall_2021_impact.vpcf", context)
	PrecacheResource("particle", "particles/high_five/fall_2021/high_five_fall_2021_travel.vpcf", context)
	PrecacheResource("particle", "particles/high_five/fall_2021/high_five_fall_2021_travel_model.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_overhead.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_overhead_model.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_overhead_rings.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_overhead_soap_bubbles.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_overhead_foam.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_overhead_sparkle.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_travel.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_travel_glow.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_travel_model.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_travel_model_endcap.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_travel_model_endcap_b.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_impact.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_impact_light.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_impact_flare.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_impact_burst.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_impact_burst_b.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_impact_steam.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_impact_flash.vpcf", context)
	PrecacheResource("particle", "particles/high_five/mug/high_five_mug_impact_bubble_float.vpcf", context)
	
	-- STORE BALL EFFECTS (новые эффекты временно отключены)
	PrecacheResource("particle", "particles/general_events/ball_hot/ball_hot.vpcf", context)
	PrecacheResource("particle", "particles/general_events/ball_hot/phase_boots_winterrewardline_2025_snowy_vortex.vpcf", context)
	PrecacheResource("particle", "particles/heroes/night_stalker/phantom_assassin_active_start_streak.vpcf", context)
	











	-- Models can also be precached by folder or individually
	--PrecacheModel should generally used over PrecacheResource for individual models
	--PrecacheResource("model_folder", "particles/heroes/antimage", context)
	PrecacheResource("model", "models/heroes/oracle/crystal_ball.vmdl", context)
	PrecacheResource("model", "ball.vmdl", context)
	PrecacheResource("model", "models/particle/snowball.vmdl", context)
	PrecacheResource("model", "models/heroes/lich/lich_ice_spire.vmdl", context)
	--PrecacheModel("models/heroes/viper/viper.vmdl", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_puck.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_furion.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_void_spirit.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_earthshaker.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_vengefulspirit.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_spirit_breaker.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_slardar.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_weaver.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bounty_hunter.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_brewmaster.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_leshrac.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_earth_spirit.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_creeps.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_items.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_ui.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_ambient.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_roshan_halloween.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/soundevents_custom.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/abilities.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/round_start.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/crowd.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/countdowns.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/score_sounds.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_templar_assassin.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_wisp.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_faceless_void.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_pudge.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_storm_spirit.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_warlock.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_techies.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_weaver.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_nevermore.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_magnataur.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_queenofpain.vsndevts", context)

	PrecacheItemByNameSync("item_phase_boots", context)

	-- Entire heroes (sound effects/voice/models/particles) can be precached with PrecacheUnitByNameSync
	-- Custom units from npc_units_custom.txt can also have all of their abilities and precache{} blocks precached in this way
	local herolist = LoadKeyValues("scripts/npc/herolist.txt")
	if herolist then
		local heroes = herolist.CustomHeroList or herolist
		for heroName, enabled in pairs(heroes) do
			if tostring(enabled) == "1" or enabled == 1 then
				PrecacheUnitByNameSync(heroName, context)
			end
		end
	end
	PrecacheUnitByNameSync("npc_dota_roshan", context)

	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_spectre.vsndevts", context)
	PrecacheResource("particle", "particles/units/heroes/hero_spectre/spectre_shadow_path.vpcf", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_primal_beast.vsndevts", context)
	PrecacheResource("particle", "particles/units/heroes/hero_primal_beast/primal_beast_onslaught_hit.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_primal_beast/primal_beast_onslaught_range_finder.vpcf", context)
	
	-- Ringmaster
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ringmaster.vsndevts", context)
	PrecacheResource("particle", "particles/items_fx/force_staff.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ringmaster/ringmaster_escape_act_target.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ringmaster/ringmaster_escape_act_aoe_edge.vpcf", context)
	PrecacheResource("model", "models/heroes/ringmaster/ringmaster_box.vmdl", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ringmaster/ringmaster_unicycle_max_speed_sparkles.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ringmaster/ringmaster_unicycle_end.vpcf", context)
	PrecacheResource("model", "models/heroes/ringmaster/ringmaster_prop_unicycle.vmdl", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ringmaster/ringmaster_escape_act_aoe_dust_motes.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ringmaster/ringmaster_escape_act_target_spotlight.vpcf", context)

	-- Silencer
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_silencer.vsndevts", context)
	PrecacheResource("particle", "particles/units/heroes/hero_silencer/silencer_glaives_of_wisdom.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_silencer/silencer_glaives_of_wisdom_explosion_flash.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_silencer/silencer_curse.vpcf", context)


	-- Tuskar
	PrecacheResource("particle", "particles/units/heroes/hero_razor/razor_static_link.vpcf", context)
	PrecacheResource("particle", "particles/ui_mouseactions/range_display.vpcf", context)
	PrecacheResource("particle", "particles/ui_mouseactions/custom_range_display.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/ancient_apparition/ancient_apparation_ti8/ancient_ice_vortex_ti8_color_light.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/tuskarr/tusk_ti9_immortal/tusk_ti9_golden_walruspunch_start_rocks.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/tuskarr/tusk_ti9_immortal/tusk_ti9_walruspunch_start_water.vpcf", context)


	PrecacheResource("particle", "particles/econ/items/nightstalker/nightstalker_black_nihility/nightstalker_black_nihility_void_hit_ray.vpcf", context)


	
end

-- Create the game mode when we activate
function Activate()
	GameRules.Banjoball = Banjoball()
	GameRules.Banjoball:InitBanjoball()
	InitHighFiveEvents()
	InitBallEffectsEvents()
end

for i,v in ipairs(requires) do
	require(v)
end