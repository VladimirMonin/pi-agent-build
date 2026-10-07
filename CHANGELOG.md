# Журнал изменений

Все значимые изменения сборки документируются здесь. Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/); до первого release tag изменения остаются в `Unreleased`.

## [Unreleased]

### Добавлено

- Русская инструкция чистой установки Windows x64, двух профилей, exact-version packages, внешних CLI, patches и verification.
- Документация границ Code/Task, профильных и общих данных, безопасной миграции state.
- Компонентная документация всех 15 Pi-пакетов в семи тематических группах: назначение, установка, конфигурация/данные, commands/tools/skills, риски, проверка и удаление.
- Отдельные документы по `pi-polza` v0.2.0 и служебному static provider `polza-memory`.
- Конфигурация Polza embeddings `qwen/qwen3-embedding-8b` (1024 dimensions) для hybrid session search.
- Конфигурация `deepseek/deepseek-v4.1-flash` для pi-memory через core `models.json`, поскольку consolidation child запускается с `--no-extensions`.
- Runbooks шести локальных исправлений: Trace, memory, session-search, Serena, CBM и Windows spawn для ast-grep.
- `THIRD_PARTY.md` с прямыми компонентами, версиями, лицензиями, источниками и оговорками внешних сервисов.
- `THIRD_PARTY_NOTICES.md` и patch-local notices/licenses с точным file-level происхождением, опубликованными npm `gitHead` и SHA-256 vendored/modified upstream source.
- Ручная установка optional MCP servers `@upstash/context7-mcp@3.2.2`, `@brave/brave-search-mcp-server@2.0.85` и `mcp-server-fetch==2025.4.7`.
- Русскоязычный локальный embedder памяти: patch `memory-windows-runtime` заменяет англоязычную `Xenova/all-MiniLM-L6-v2` на мультиязычную `Xenova/paraphrase-multilingual-MiniLM-L12-v2` (384d, offline, без ключа) и добавляет структурный тест `test-memory-embedder.mjs`.
- Прогрев кэша embedder'а памяти: `scripts/warm-memory-embedder.mjs` скачивает модель заранее (таймаут 10 мин, 3 повтора); installer вызывает его автоматически, verifier сообщает WARN при отсутствии кэша. Учитывает разную скорость сети и 30-секундный таймаут ленивой загрузки плагина.
- Пакет `pi-goal-x@0.31.9` (MIT) в оба профиля: команды `/goal`, `/sisyphus` и автономное продолжение работы с персистентным состоянием в `<cwd>/.pi/goals/`. Собран против Pi 0.87.0, но peer range `>=0.83.0 <0.88.0` требует повторной проверки после апгрейда Pi. В манифесте и шаблонах размещён перед `pi-intercom`: обратный порядок в headless-режиме ломает `turn_end` boundary ([заметка](docs/notes/goal-x-intercom-order.md)).
- Исправление session id в консолидации памяти: patch `memory-windows-runtime` читает id через `sessionManager.getSessionId()`, так как `ExtensionContext` не содержит полей `sessionId`/`session` и stock-выражение всегда давало `session:unknown`. Добавлен структурный тест `test-memory-sessionid.mjs`.
- Раздел `docs/notes/` с заметками о поведении upstream-компонентов: `session:unknown` в консолидации памяти, квадратичный рост файлов трассировки `pi-trace-extension` (до 144 МБ на длинной сессии) и порядок загрузки `pi-goal-x` относительно `pi-intercom` (полная матрица проверок в [`docs/notes/goal-x-intercom-order.md`](docs/notes/goal-x-intercom-order.md)).

### Изменено

- Граница repeatability описана как exact top-level/version-pinned, без обещания bit-reproducibility до появления transitive locks и artifact hashes.
- Existing profile configs сохраняются по умолчанию; полная замена документирована только как явный `-ReplaceProfileConfigs` с backup и без автоматического merge.
- Profile packages устанавливаются через штатный `pi install` в sanitized child environment; Git source закреплён immutable object id и отдельно проверяется по tag object/peeled checkout.
- Memory patch учитывает `PI_CODING_AGENT_DIR` при чтении user-global settings, поэтому Task больше не зависит от Code `settings.json`; общая memory DB остаётся общей.
- Memory patch также меняет локальную модель встраивания фактов на мультиязычную (384d, mean pooling, порог `0.25` не меняется, reindex не требуется).

### Исправлено

- Навык `memory-ops` в сборке: добавлен раздел «Типовые ложные выводы». Реальный замер обязан передавать профильный `memory`-конфиг (`factProjectAliases`, `lessonInjection`) в сборщик — без него проектные факты молча отфильтровываются и регрессионный чекер даёт ложное «missing»; `--estimate` считает потенциальную стоимость, а не нижнюю границу блока; отсутствие маркера `truncated` означает целые **выбранные** строки, а не отсутствие потерь. Там же уточнено, что version-guarded патч привязан к 1.5.0, снимается `pi update`/пересборкой и требует повторного применения (версия навыка `1.0.1-public`).
- Уточнены prerequisites/runtime roles, semantics `verify.ps1`, отсутствие `update.ps1` и pending status корневого `AGENTS.md`.

### Безопасность

- Во всех примерах используются placeholders и profile-relative/user-relative пути; credentials, живые sessions, traces и memory DB не добавлены.
- Документировано, что session-search config хранит Polza key как literal, Trace/indexes содержат sensitive derived data, а runtime state переносится только зашифрованным каналом вне Git.
- Документировано, что pi-memory передаёт consolidation prompt дочернему Pi через process command line, видимую локальным monitors/администраторам/telemetry.

### Известные ограничения

- `pi-background-tasks 2.6.2` остаётся installed-disabled из-за несовместимости с system-role conversation blocks Pi 0.87.0.
- Локальные package patches нужно повторно проверять и применять после reinstall/update.
- Закреплённые top-level versions не фиксируют transitive dependency tree; release bundle требует отдельного lock/hash/SBOM шага.

## [pi-v1.0.4-build.2]

### Изменено

- Только три пакета: Subagents **0.76.1**, Goal X **0.32.3**, Intercom **0.16.1**; Pi остаётся **1.0.4**. Goal X preset, картинки, Trace/MCP filters и остальные версии сохранены.
- Both candidate loading — 13/10 extensions, 0 errors/warnings/fetch; synthetic completion wake, два процесса Intercom через настоящий Windows broker и старый synthetic Goal с `nextAction` → complete — PASS. Windows script regressions 24/24; repository verifier 0/0. [Проверки и короткая установка](docs/releases/pi-1.0.4-build.2.md).

## [pi-v1.0.4-build.1]

### Изменено

- Только Pi core: exact pin **1.0.2 → 1.0.4**, без обновления плагинов, внешних инструментов и Node/npm.
- В Code/Task явно разрешены картинки для модели (`blockImages: false`), auto-resize и terminal preview (`showImages: true`, ширина 60, протокол auto).
- Core SDK local-mock на actual Pi/AI 1.0.4, repository verifier и safety scan — PASS. Полная plugin/live-provider приёмка и визуальная проверка terminal preview не выполнялись. [Scope, обновление и ограничения](docs/releases/pi-1.0.4.md).

## [pi-v1.0.2-build.3]

### Изменено

- Source-only интеграция опубликованного `pi-polza` **0.2.1**: exact commit/tag metadata обновлены вместе в manifest, Code/Task templates, synthetic installer fixtures и текущей документации. Core остаётся **1.0.2**; Goal X, фильтры Trace/MCP и skill bytes не изменены.
- Plugin исправляет однократный нативный RUB-учёт после успешного ответа Pi1.0.2 и сохраняет последний баланс с `stale` при ошибке refresh. Принятый upstream handoff: 203/203 offline checks, включая 47 native на actual installed Pi1.0.2 + synthetic SSE; audit/pack PASS. Live acceptance новой сессии сообщена владельцем, не полный background-live.
- Выпуск включает ранее добавленный `memory-ops` **1.0.1-public** без новых изменений навыка. История выше сохранена; прежний публичный build.2 не заменяется. [Release notes и ограничения](docs/releases/pi-1.0.2-build.3.md); публикация нового tag/release выполняется отдельно.
