-- Custom Hero Chat Wheel VScripts logic

if _G.CustomChatWheelRegistered then return end
_G.CustomChatWheelRegistered = true

-- База данных фраз чат-колеса
CHAT_WHEEL_PHRASES = {
	-- Дефолтные фразы (Soundboard) для всех героев
	["default"] = {
		{ id = 1, text = "Waow!", sound = "dota_soundboard.wow" },
		{ id = 2, text = "Ай-ай-ай!", sound = "dota_soundboard.ay_ay_ay" },
		{ id = 3, text = "Crybaby", sound = "dota_soundboard.crybaby" },
		{ id = 4, text = "Brutal. Savage. Rekt.", sound = "dota_soundboard.brutal" },
		{ id = 5, text = "Applause", sound = "dota_soundboard.applause" },
		{ id = 6, text = "Patience from Zhou", sound = "dota_soundboard.patience" },
		{ id = 7, text = "Crash", sound = "dota_soundboard.crash" },
		{ id = 8, text = "See ya!", sound = "dota_soundboard.see_ya" }
	},
	-- Геройские фразы (пример для Pudge)
	["npc_dota_hero_pudge"] = {
		{ id = 1, text = "Fresh meat!", sound = "pudge_pud_attack_08" },
		{ id = 2, text = "Oops...", sound = "pudge_pud_deny_08" },
		{ id = 3, text = "Chop chop!", sound = "pudge_pud_ability_hook_06" },
		{ id = 4, text = "Ha ha ha!", sound = "pudge_pud_laugh_02" },
		{ id = 5, text = "Brutal. Savage. Rekt.", sound = "dota_soundboard.brutal" },
		{ id = 6, text = "Ай-ай-ай!", sound = "dota_soundboard.ay_ay_ay" },
		{ id = 7, text = "Crybaby", sound = "dota_soundboard.crybaby" },
		{ id = 8, text = "Waow!", sound = "dota_soundboard.wow" }
	},
	-- Геройские фразы (пример для Hoodwink)
	["npc_dota_hero_hoodwink"] = {
		{ id = 1, text = "Proper skulduggery!", sound = "hoodwink_hoodwink_spawn_08" },
		{ id = 2, text = "Too easy!", sound = "hoodwink_hoodwink_lasthit_05" },
		{ id = 3, text = "Aha-ha-ha!", sound = "hoodwink_hoodwink_laugh_02" },
		{ id = 4, text = "Scurry away!", sound = "hoodwink_hoodwink_ability_scurry_01" },
		{ id = 5, text = "Waow!", sound = "dota_soundboard.wow" },
		{ id = 6, text = "Ай-ай-ай!", sound = "dota_soundboard.ay_ay_ay" },
		{ id = 7, text = "Crybaby", sound = "dota_soundboard.crybaby" },
		{ id = 8, text = "Brutal. Savage. Rekt.", sound = "dota_soundboard.brutal" }
	},
	-- Геройские фразы (для Void Spirit)
	["npc_dota_hero_void_spirit"] = {
		{ id = 1, text = "#banjoball_chatwheel_void_spirit_1", sound = "void_spirit_voidspir_spawn_01" },
		{ id = 2, text = "#banjoball_chatwheel_void_spirit_2", sound = "void_spirit_voidspir_spawn_05" },
		{ id = 3, text = "#banjoball_chatwheel_void_spirit_3", sound = "void_spirit_voidspir_deny_06" },
		{ id = 4, text = "#banjoball_chatwheel_void_spirit_4", sound = "void_spirit_voidspir_kill_11" },
		{ id = 5, text = "#banjoball_chatwheel_void_spirit_5", sound = "void_spirit_voidspir_laugh_02" },
		{ id = 6, text = "#banjoball_chatwheel_void_spirit_6", sound = "void_spirit_voidspir_level_07" },
		{ id = 7, text = "#banjoball_chatwheel_void_spirit_7", sound = "void_spirit_voidspir_ability_step_05" },
		{ id = 8, text = "#banjoball_chatwheel_void_spirit_8", sound = "void_spirit_voidspir_thanks_02" }
	}
}

function InitCustomChatWheel()
	CustomGameEventManager:RegisterListener("custom_chatwheel_fire", function(_, data)
		local playerID = tonumber(data.PlayerID or data.playerid or data.playerID)
		if not playerID then return end

		local hero = PlayerResource:GetSelectedHeroEntity(playerID)
		if not hero or not hero:IsAlive() then return end

		local phraseID = tonumber(data.phraseID)
		if not phraseID or phraseID < 1 or phraseID > 8 then return end

		local heroName = hero:GetUnitName()
		local phrases = CHAT_WHEEL_PHRASES[heroName] or CHAT_WHEEL_PHRASES["default"]
		local phrase = phrases[phraseID]
		if not phrase then return end

		-- 1. Воспроизводим звук
		EmitSoundOn(phrase.sound, hero)

		-- 2. Выводим сообщение в чат для всех игроков
		local playerName = PlayerResource:GetPlayerName(playerID)
		if playerName == "" then playerName = "Player " .. playerID end
		
		local heroNameLocalized = heroName
		if heroName == "npc_dota_hero_pudge" then heroNameLocalized = "Pudge"
		elseif heroName == "npc_dota_hero_hoodwink" then heroNameLocalized = "Hoodwink"
		elseif heroName == "npc_dota_hero_silencer" then heroNameLocalized = "Silencer"
		else
			heroNameLocalized = string.gsub(heroName, "npc_dota_hero_", "")
			heroNameLocalized = string.upper(string.sub(heroNameLocalized, 1, 1)) .. string.sub(heroNameLocalized, 2)
		end

		-- Выводим сообщение в чат
		Say(hero, phrase.text, false)

		-- 3. Отправляем событие на клиенты для показа текста над героем
		CustomGameEventManager:Send_ServerToAllClients("custom_chatwheel_bubble", {
			playerID = playerID,
			heroIndex = hero:GetEntityIndex(),
			text = phrase.text
		})
	end)
	
	print("[ChatWheel] Custom Chat Wheel events initialized successfully.")
end

-- Автоинициализация
InitCustomChatWheel()
