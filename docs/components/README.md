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

Версии берутся только из [`manifests/pi-packages.lock.json`](../../manifests/pi-packages.lock.json). `pi-background-tasks` входит в состав как installed-disabled. Code содержит все 15 пакетов; Task — 12 без трёх code-intelligence packages.
