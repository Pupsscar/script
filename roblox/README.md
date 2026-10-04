# Скрипты для Roblox Studio

В каждом скрипте замените **весь код** (Ctrl+A → вставить). Новые скрипты создайте с таким же именем и типом.

## Заменить

| Файл | Скрипт в Studio | Где лежит |
|---|---|---|
| `Monsters.server.lua` | **Monsters** (Script) | ServerScriptService |
| `SpawnService.server.lua` | **SpawnService** (Script) | ServerScriptService |
| `Regeneration.server.lua` | **Regeneration** (Script) | ServerScriptService |
| `CharacterVisualSyncServer.server.lua` | **CharacterVisualSyncServer** (Script) | ServerScriptService |
| `FallDamageController.module.lua` | **FallDamageController** (ModuleScript) | ReplicatedStorage → Modules |
| `MonsterData.module.lua` | **MonsterData** (ModuleScript) | ReplicatedStorage → Modules |
| `AdminPanel.client.lua` | **AdminPanel** (LocalScript) | там же, где был |
| `DeathScreen.client.lua` | **DeathScreen** (LocalScript) | там же, где был |
| `BloodFX.client.lua` | **BloodFX** (LocalScript) | там же, где был |
| `MonsterClient.client.lua` | **MonsterClient** (LocalScript) | там же, где был |
| `Chat.client.lua` | **Chat** (LocalScript) | там же, где был |
| `Animation.client.lua` | **Animation** (LocalScript) | там же, где был |
| `PlayerList.client.lua` | **PlayerList** (LocalScript) | там же, где был |

## Создать новые (если ещё не создали)

| Файл | Имя и тип | Куда положить |
|---|---|---|
| `AntiCheat.server.lua` | **AntiCheat** (Script) | ServerScriptService |
| `AntiCheatClient.client.lua` | **AntiCheatClient** (LocalScript) | StarterPlayer → StarterPlayerScripts |
| `InfectionHUD.client.lua` | **InfectionHUD** (LocalScript) | StarterPlayer → StarterPlayerScripts |
| `VoiceNoise.client.lua` | **VoiceNoise** (LocalScript) | StarterPlayer → StarterPlayerScripts |

## Текстуры (по желанию, но с ними сильно красивее)
1. В Studio: **Asset Manager → Bulk Import** (или Create → Decals) и загрузите три файла из `textures/`:
   - `flesh_meat.png`
   - `veins_overlay.png`
   - `listener_skin.png`
2. Скопируйте ID каждой картинки (ПКМ → Copy ID).
3. Вставьте ID в начало скрипта **Monsters**, в таблицу `TEXTURES` (`Meat`, `Veins`, `ListenerSkin`).

Без текстур монстры всё равно получают объёмные вены, глаза, рты и цвет мяса.

## Настройки игры
- **Game Settings → Security**:
  - **Enable Studio Access to API Services**: баны, повторы и список игроков для подсказок.
  - **Allow HTTP Requests**: бейджи и поиск ников через Roblox.
- **Голос**: в `VoiceChatService` поставьте `UseAudioApi = Enabled`, и голосовой чат должен быть включён для игры. Без этого монстры слышат всё, кроме голоса.

## Что нового
- **Заражённый**: переломы и раны заживают через 30 секунд. Оторванные конечности отрастают мясом. +2 HP каждые 10 секунд.
- **Слух у всех монстров**:
  - слышат шаги, бег, прыжки, падения;
  - слышат, как игрок ложится и ползёт;
  - слышат удары, крики от боли, чат и голос;
  - вплотную слышат сердцебиение и тяжёлое дыхание.
  - Слушатель слышит в 1,6 раза дальше остальных.
- **Слушатель (C-207)**: без глаз (зашитые впадины), огромный рот с зубами, вены по всему телу.
- **Мутант (A-013)**:
  - мясо, вены, белые глаза в чёрных впадинах, лишние глаза на теле, пасть с зубами;
  - 5 щупалец: хватают игрока с 7–24 стадов, роняют в регдолл и подтягивают к себе.
- **Чат**: открывается кликом или тапом по «/ talk», клавиша `/` тоже работает.
- **Телефон**: кнопки HIT (удар), CRAWL (ползти), LIST (игроки), ADMIN (для админов). Админка и экран смерти уменьшаются под экран.
- **Админка**:
  - в поле бана появляются подсказки ников по мере ввода: игроки на сервере, те, кто заходил раньше, забаненные и поиск Roblox;
  - в повторе есть кнопки **CHEATS: PERM BAN** (перманентно, на всех устройствах) и **LEGIT: RELEASE**. Второй снимает наказание, разбанивает, если бан поставил античит, и дальше проверяет игрока мягче.
