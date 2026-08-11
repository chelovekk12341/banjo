# TODO (Список задач)

## Исправления:
- [x] Хост не может управлять созданными ботами

## Безопасность БД (Supabase Protection):
- [x] Настроить политики RLS (Row Level Security) в панели управления Supabase для таблиц `matches`, `match_players` и `players`:
  - Разрешить публичный `SELECT` без ограничений.
  - Ограничить `INSERT`, `UPDATE` и `DELETE` проверкой наличия секретного заголовка (например, `current_setting('request.headers', true)::json->>'x-custom-auth' = 'ваш_секретный_ключ'`).
- [x] Добавить отправку секретного HTTP-заголовка `x-custom-auth` во все запросы на запись/изменение в Lua-скриптах кастомки:
  - `goal.lua` (отправка результатов матчей)
  - `supabase_api.lua` (создание матчей и миграция)
  - `high_five_custom.lua`, `range_custom.lua`, `ball_effects.lua` (сохранение инвентаря/косметики игроков)

## Отслеживание дисконнектов (Disconnect & AFK logic):
- [x] Записывать статус отключения игрока в БД (кастомка):
  - В `Banjoball:OnDisconnect` ловить отключение и через 2 секунды делать принудительный вызов `Banjoball:SendLiveMatchUpdate()`.
  - В `SendLiveMatchUpdate` и `UpdateMatchRecord` проверять `PlayerResource:GetConnectionState(pID)` и записывать `disconnected = true` для игроков со статусами `DISCONNECTED` (3) / `ABANDONED` (4).
- [x] Автоматическое закрытие брошенных матчей в БД (кастомка):
  - В `Banjoball:OnDisconnect` добавить проверку: если не осталось ни одного подключенного реального игрока, запустить таймер на 60 секунд.
  - Если по истечении 60 секунд никто не переподключился — кастомка отправляет PATCH-запрос в Supabase, изменяя статус матча на `"abandoned"` (или `"finished"`), чтобы матч корректно закрылся в базе данных и убрался из LIVE на сайте.

## Веб-виджет (widget_show_matches):
- [x] В Matches (список матчей) добавить столбцы с никами капитанов (Radiant и Dire).
