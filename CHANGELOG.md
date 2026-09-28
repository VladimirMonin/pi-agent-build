# Журнал изменений

Все значимые изменения сборки документируются здесь. Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/); до первого release tag изменения остаются в `Unreleased`.

## [Unreleased]

### Добавлено

- Русская инструкция чистой установки Windows x64, двух профилей, exact-version packages, внешних CLI, patches и verification.
- Документация границ Code/Task, профильных и общих данных, безопасной миграции state.
- Компонентная документация всех 14 Pi-пакетов в семи тематических группах: назначение, установка, конфигурация/данные, commands/tools/skills, риски, проверка и удаление.
- Отдельные документы по `pi-polza` v0.2.0 и служебному static provider `polza-memory`.
- Конфигурация Polza embeddings `qwen/qwen3-embedding-8b` (1024 dimensions) для hybrid session search.
- Конфигурация `deepseek/deepseek-v4.1-flash` для pi-memory через core `models.json`, поскольку consolidation child запускается с `--no-extensions`.
- Runbooks шести локальных исправлений: Trace, memory, session-search, Serena, CBM и Windows spawn для ast-grep.
- `THIRD_PARTY.md` с прямыми компонентами, версиями, лицензиями, источниками и оговорками внешних сервисов.
- `THIRD_PARTY_NOTICES.md` и patch-local notices/licenses с точным file-level происхождением, опубликованными npm `gitHead` и SHA-256 vendored/modified upstream source.
- Ручная установка optional MCP servers `@upstash/context7-mcp@3.2.2`, `@brave/brave-search-mcp-server@2.0.85` и `mcp-server-fetch==2025.4.7`.

### Изменено

- Граница repeatability описана как exact top-level/version-pinned, без обещания bit-reproducibility до появления transitive locks и artifact hashes.
- Existing profile configs сохраняются по умолчанию; полная замена документирована только как явный `-ReplaceProfileConfigs` с backup и без автоматического merge.
- Profile packages устанавливаются через штатный `pi install` в sanitized child environment; Git source закреплён immutable object id и отдельно проверяется по tag object/peeled checkout.
- Memory patch учитывает `PI_CODING_AGENT_DIR` при чтении user-global settings, поэтому Task больше не зависит от Code `settings.json`; общая memory DB остаётся общей.
- Уточнены prerequisites/runtime roles, semantics `verify.ps1`, отсутствие `update.ps1` и pending status корневого `AGENTS.md`.

### Безопасность

- Во всех примерах используются placeholders и profile-relative/user-relative пути; credentials, живые sessions, traces и memory DB не добавлены.
- Документировано, что session-search config хранит Polza key как literal, Trace/indexes содержат sensitive derived data, а runtime state переносится только зашифрованным каналом вне Git.
- Документировано, что pi-memory передаёт consolidation prompt дочернему Pi через process command line, видимую локальным monitors/администраторам/telemetry.

### Известные ограничения

- `pi-background-tasks 2.6.2` остаётся installed-disabled из-за несовместимости с system-role conversation blocks Pi 0.87.0.
- Локальные package patches нужно повторно проверять и применять после reinstall/update.
- Закреплённые top-level versions не фиксируют transitive dependency tree; release bundle требует отдельного lock/hash/SBOM шага.
