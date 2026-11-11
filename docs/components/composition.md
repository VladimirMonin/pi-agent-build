<!-- GENERATED FILE — do not edit by hand.
Sources: manifests/runtime.lock.json, manifests/pi-packages.lock.json, profiles/*/settings.template.json.
Regenerate: node scripts/gen-composition.mjs · freshness gate: node scripts/gen-composition.mjs --check (wired into verify). -->

# Состав сборки (генерируется)

Ядро **Pi 1.5.2** само поставляет базовые инструменты и SDK-подмостки для расширений (`@earendil-works/pi-ai`, `pi-agent-core`, `pi-coding-agent`, `pi-tui`, `typebox`) — это не плагины. Всё в таблице ниже — **Pi-пакеты**: отдельные npm/git-пакеты с закреплёнными версиями. Источник истины — `manifests/pi-packages.lock.json`; эта таблица лишь читаемое представление.

Легенда: ✅ активен · ⛔ установлен, но выключен (`"extensions": []` — расширения не загружаются; включается правкой одной строки в шаблоне профиля) · — пакет не входит в профиль.

| Пакет | Версия | Источник | Code | Task | Что делает |
|---|---|---|---|---|---|
| `pi-ollama-cloud` | 0.12.1 | npm | ✅ | ✅ | Маршрут к моделям Ollama Cloud (провайдер) |
| `pi-trace-extension` | 0.1.16 | npm | ⛔ | ⛔ | Trace — трассировка сессий (политика сборки: установлен, выключен по умолчанию) |
| `pi-context-inspector` | 1.3.0 | npm | ✅ | ✅ | Диагностика контекстного окна |
| `@juicesharp/rpiv-todo` | 2.12.0 | npm | ✅ | ✅ | Список задач (todo) |
| `pi-polza` | 0.3.1 | git | ✅ | ✅ | Запасной провайдер Polza AI |
| `pi-subagents` | 0.79.1 | npm | ✅ | ✅ | Сабы — делегирование и сценарии из нескольких агентов |
| `pi-goal-x` | 0.32.3 | npm | ✅ | ✅ | Goal X — автономная работа с целями |
| `pi-intercom` | 0.17.1 | npm | ✅ | ✅ | Связь между сессиями |
| `pi-background-tasks` | 2.6.2 | npm | ⛔ | ⛔ | Фоновые shell-задачи, делегирование, Fusion через дочерние Pi |
| `pi-session-search` | 1.6.0 | npm | ✅ | ✅ | Поиск по сессиям (история работы) |
| `@samfp/pi-memory` | 1.6.1 | npm | ✅ | ✅ | Долговременная память |
| `pi-mcp-adapter` | 5.3.2 | npm | ✅ | ✅ | Мост к MCP-серверам |
| `@nicknisi/pi-ast-grep` | 0.2.1 | npm | ✅ | — | Поиск и правка кода по синтаксису (ast-grep) (внешняя зависимость: @ast-grep/cli@0.45.3) |
| `@bacnh85/pi-serena` | 0.9.20 | npm | ✅ | — | Семантика кода через LSP (Serena) (внешняя зависимость: serena-agent@1.7.0) |
| `pi-cbm` | 1.2.1 | npm | ✅ | — | Граф кода: символы, связи, трассировки (codebase memory) (внешняя зависимость: codebase-memory-mcp@0.11.0) |

Профили: **Code** = общие пакеты + code-intelligence тройка; **Task** = только общие. Полные спецификации (коммиты, теги) — в `manifests/pi-packages.lock.json`.
