# Компоненты сборки

Manifest содержит 15 Pi-пакетов. Документы сгруппированы по назначению; в каждом разделе указаны версия, установка, конфигурация/данные, интерфейсы, риски, проверка и удаление.

| Группа | Пакеты |
|---|---|
| [Провайдеры](providers.md) | `pi-ollama-cloud`, `pi-polza` |
| [Наблюдаемость](observability.md) | `pi-trace-extension`, `pi-context-inspector` |
| [План задач](workflow.md) | `@juicesharp/rpiv-todo`, `pi-goal-x` |
| [Координация](coordination.md) | `pi-subagents`, `pi-intercom`, `pi-background-tasks` |
| [История и память](history-memory.md) | `pi-session-search`, `@samfp/pi-memory` |
| [MCP](mcp.md) | `pi-mcp-adapter` |
| [Code intelligence](code-intelligence.md) | `@nicknisi/pi-ast-grep`, `@bacnh85/pi-serena`, `pi-cbm` |

Версии берутся только из [`manifests/pi-packages.lock.json`](../../manifests/pi-packages.lock.json); читаемая таблица состава с признаком вкл/выкл — [`composition.md`](composition.md) (генерируется `scripts/gen-composition.mjs`, сверяется в verify). `pi-background-tasks` и `pi-trace-extension` поставляются installed-disabled (пустой `extensions` в шаблонах; Trace — политика default-off). Code содержит все 15 пакетов; Task — 12 без трёх code-intelligence packages.
