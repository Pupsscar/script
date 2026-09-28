# Скрипты для Roblox Studio

В каждом скрипте замените **весь код** (Ctrl+A → вставить). Новые скрипты создайте с таким же именем и типом.

## Заменить

| Файл | Скрипт в Studio | Где лежит |
|---|---|---|
| `Monsters.server.lua` | **Monsters** (Script) | ServerScriptService |
| `SpawnService.server.lua` | **SpawnService** (Script) | ServerScriptService |
| `FallDamageController.module.lua` | **FallDamageController** (ModuleScript) | ReplicatedStorage → Modules |
| `MonsterData.module.lua` | **MonsterData** (ModuleScript) | ReplicatedStorage → Modules |
| `AdminPanel.client.lua` | **AdminPanel** (LocalScript) | там же, где был |
| `DeathScreen.client.lua` | **DeathScreen** (LocalScript) | там же, где был |
| `BloodFX.client.lua` | **BloodFX** (LocalScript) | там же, где был |

## Создать новые

| Файл | Имя и тип | Куда положить |
|---|---|---|
| `AntiCheat.server.lua` | **AntiCheat** (Script) | ServerScriptService |
| `AntiCheatClient.client.lua` | **AntiCheatClient** (LocalScript) | StarterPlayer → StarterPlayerScripts |
| `InfectionHUD.client.lua` | **InfectionHUD** (LocalScript) | StarterPlayer → StarterPlayerScripts |

## Настройки игры (Game Settings → Security)
- **Enable Studio Access to API Services**: нужно для хранения банов и повторов (DataStore).
- **Allow HTTP Requests**: нужно для проверки бейджей. Без этого проверка бейджей просто пропускается.

## Что есть
- **Сломанная нога**: первую секунду после перелома без коллизии, потом коллизия включается.
- **Кровь**: убраны облака дыма при брызгах, остались только капли.
- **A-013 «The Flesh»**: съедает убитого, игрок встаёт заражённым. Кнопки меню смерти не работают. Съеденные и отрубленные части становятся плотью. Задача: убить выживших. Монстры заражённых не трогают, по F заражённый бьёт выживших.
- **C-207 «The Listener»**: слепой, охотится на звук (бег, прыжки, удары, падения). Если идти медленно или присесть, он вас не найдёт. Если замереть, теряет вас.
- **Античит**: скорость, телепорт, полёт, noclip, desync, fling, удаление Humanoid, спам ремоутов, хуки функций, ESP-подсветки, следы инжектора в логе, подмена света, гравитации, скорости и прыжка.
  - При подозрении пишется повтор (30 с до и 8 с после).
  - При уверенности: паралич, лоботомия, смерть, бан. Если игрок вышел или сбросился, бан сразу.
- **Проверка аккаунтов**: младше 3 дней, меньше 5 друзей или меньше 20 бейджей → кик «Suspicious account».
- **Админка (F2)**:
  - вкладка **BANS**: список банов (кто, за что, кем, до когда), разбан, бан на свой срок, переключатель «на всех устройствах», кик;
  - вкладка **ANTICHEAT**: инциденты и просмотр повтора всей сцены.
- Настройки античита в начале `AntiCheat.server.lua` (таблица `CONFIG`).
