# Профили Code и Task

Сборка использует штатную переменную Pi `PI_CODING_AGENT_DIR`. Профили — отдельные каталоги конфигурации и runtime-состояния, а не режимы одного `settings.json`.

## Состав

| Область | Code (`~/.pi/agent`) | Task (`~/.pi/task`) |
|---|---|---|
| Общие 12 Pi-пакетов | да | да |
| `@nicknisi/pi-ast-grep` | да | нет |
| `@bacnh85/pi-serena` | да | нет |
| `pi-cbm` | да | нет |
| Провайдер по умолчанию | `polza` | `ollama-cloud` |
| Модель по умолчанию | `z-ai/glm-5.3-flash` | `deepseek-v4.1-flash` |
| CBM env | launcher задаёт | нет |
| Назначение | кодовая навигация и impact analysis | задачи без дорогого code-intelligence surface |

Оба профиля содержат `pi-background-tasks@2.6.2`, но extension filter должен быть пустым, то есть пакет установлен и отключён.

## Что изолирует `PI_CODING_AGENT_DIR`

Внутри выбранного каталога Pi хранит `settings.json`, `auth.json`, `models.json`, npm/git packages, sessions и часть package-specific state. Rendered launchers задают переменную только дочернему процессу и одновременно фиксируют `PI_AGENT_BUILD_NPM_PREFIX`, из которого запускается Pi:

```bash
pi-code [аргументы Pi]
pi-task [аргументы Pi]
```

Глобальный `setx PI_CODING_AGENT_DIR ...` запрещён: он незаметно закрепляет один профиль для всех запусков.

## Что остаётся общим

Профили не являются sandbox:

- `~/.agents/skills/`, пользовательский `AGENTS.md`, общие MCP-файлы и project-local `.pi/*` видны обоим профилям;
- `@samfp/pi-memory` по умолчанию использует общую БД `~/.pi/memory/memory.db`;
- stock pi-memory `1.6.0` читает user-global memory config только из `~/.pi/agent/settings.json`; patch `memory-windows-runtime` заменяет это на `<PI_CODING_AGENT_DIR>/settings.json`, поэтому Code и Task получают независимые global memory settings, но по-прежнему делят БД по умолчанию;
- исходный `pi-session-search 1.4.3` жёстко ориентирован на Code; Task требует [profile patch](fixes/session-search.md);
- внешние binaries (`serena`, `ast-grep.exe`, `codebase-memory-mcp.exe`) устанавливаются на уровне пользователя;
- текущий проект, его инструкции и файлы не изолируются выбором профиля.

Если нужен чистый baseline, используйте `--no-skills --no-context-files`, но это не отключает установленные extensions. Для полного отключения discovery есть `--no-extensions`; явно переданный `-e` всё ещё может загрузить нужный extension.

## Конфигурация профилей

Шаблоны:

- [`profiles/code/settings.template.json`](../profiles/code/settings.template.json);
- [`profiles/task/settings.template.json`](../profiles/task/settings.template.json).

Не заменяйте ими живой файл без просмотра diff. После `pi config` и каждого `pi install` проверьте объектную запись background-tasks: пустой `extensions` означает «не загружать extension», тогда как удалённый filter снова включает пакет.

`models.json` нужен в обоих профилях для служебного `polza-memory`: дочерняя консолидация запускается с `--no-extensions`, поэтому динамический `pi-polza` в ней недоступен. Profile-aware memory settings требуют применённого [memory patch](fixes/memory.md) в каждом профиле; без него Task снова читает Code `settings.json`.

## Картинки

В обоих шаблонах явно включены `images.blockImages: false` и `images.autoResize: true`: изображения разрешены для модели и уменьшаются до 2000×2000. Для terminal preview заданы `terminal.showImages: true`, `terminal.imageWidthCells: 60`, `terminal.images: "auto"`.

Preview требует поддержки inline-image протокола терминалом и не управляет передачей изображения модели. Модель должна поддерживать vision. После ручного изменения живого settings выполните `/reload`; уже запущенные сабы надёжнее перезапустить. Project-local settings могут переопределять эти поля.

## Данные по компонентам

| Данные | Code | Task |
|---|---|---|
| Pi sessions | `~/.pi/agent/sessions/` | `~/.pi/task/sessions/` |
| Trace после patch | `~/.pi/agent/traces/` | `~/.pi/task/traces/` |
| session-search config/index | `~/.pi/session-search/` | `~/.pi/task/session-search/` после patch |
| intercom runtime/config | `~/.pi/agent/intercom/` | `~/.pi/task/intercom/` |
| memory DB по умолчанию | `~/.pi/memory/memory.db` | та же БД |
| packages | `<profile>/npm/`, `<profile>/git/` | `<profile>/npm/`, `<profile>/git/` |

Project-local storage у session-search и memory имеет более высокий приоритет и может изменить таблицу.

## Проверка идентичности профиля

```bash
pi-code list
pi-task list
```

Внутри сессии `/context` показывает активные tools. В Task не должно быть `ast_search`, `serena_*` и CBM tools. В Code должны присутствовать `ast_search`, `serena_status`, `get_architecture`/`search_graph`. `(filtered)` в `pi list` само по себе недостаточно: дополнительно убедитесь, что `/bg-tasks` не зарегистрирована.

## Удаление профиля

1. Закройте все процессы этого профиля.
2. Экспортируйте нужные state-файлы по [state-migration.md](state-migration.md).
3. Удалите launcher или перестаньте его использовать.
4. Удаляйте каталог профиля только после проверки архива.

Удаление `~/.pi/task` не удаляет общую `~/.pi/memory/memory.db`, глобальные skills, MCP config или внешние binaries. После profile-aware memory patch Task не зависит от Code `settings.json`, однако удаление любого профиля не удаляет общую БД и не очищает записи, созданные этим профилем.
