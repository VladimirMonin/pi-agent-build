# Pi 0.99.1 — доска выполнения лабораторной миграции

**Цель:** выполнить [лабораторный план](pi-0.99.1-lab.md) на строго `@earendil-works/pi-coding-agent@0.99.1` без изменения рабочих Code/Task. Эта доска отражает *проверенные* факты, а не обещание совместимости. Рабочая ветка — `lab/pi-0.99.1`, создана от опубликованного `pi-v0.87.0-build.2`; поверх неё перенесён только существующий commit с планом. Рабочий `main` не меняем.

**Обозначения:** `TODO` → `DOING` → `PASS` / `FAIL` / `NOT TESTED` / `BLOCKED`. `PASS` требует команду и свидетельство; отсутствие доступа/разрешения означает `NOT TESTED`, а не `PASS`. Сырые логи, пути с именами владельца и результаты модельных запросов находятся **только** в `<LAB_ROOT>/evidence/`, вне Git. В этой доске приведены только безопасные идентификаторы доказательств и команды с плейсхолдерами. Новые запросы к платным провайдерам и публикация требуют отдельных разрешений.

## Очередь и зависимости

| № | Веха | Статус | Gate / свидетельство |
|---|---|---|---|
| 0 | Baseline и матрица изменений 0.87.0 → 0.99.1 | PASS | `baseline-repo`, `baseline-tests`, `baseline-live`, `baseline-safety`, `official-release-retry`, `official-registry`, `lab-repo-verify`, `lab-safety-tree` |
| 1 | Отдельные worktree и `<LAB_ROOT>`, предварительная изоляция | TODO | Статическая карта всех write paths + безопасный дочерний dry-run, **до установки** |
| 2 | Лабораторные installer/verifier и точный lock 0.99.1 | TODO | Plan/apply/verify Code+Task через явный бинарник из отдельного npm prefix; runtime isolation gate на синтетических данных **до credentials/моделей** |
| 3 | Патчи, плагины, CLI и обязательные MCP-маршруты (пока с адаптером) | TODO | Матрица Code/Task × компонент; память/ребёнок `--no-extensions`/JSON-headless/tools; не испытывать WVM на этом этапе |
| 4 | Каталог, доступность моделей, реальный payload | TODO | Отдельная матрица catalog/auth/response/tool/limits; платные вызовы — лишь с отдельного разрешения |
| 5 | Общие tests/platform/safety gates | TODO | unit/contract, оба verifier, JSON/schema/синтаксис, Markdown links, diff, safety; Windows нативно; прочие ОС — только с нативным доказательством |
| 6 | **WVM последним техническим этапом**: legacy SSE + streamable HTTP и выбор MCP | TODO | Изолированные конфигурации, функциональный паритет адаптера/встроенного MCP; затронутые финальные smokes после изменений |
| 7 | GO/NO-GO, документация, откат, решение владельца | TODO | Review staged-файлов, остаточные риски, приватный backup/rollback; нет автоматического main/tag/push/переключения |

Зависимости строгие: 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7. Внешние read-only исследования можно делать параллельно, но gates не перепрыгивать. Если WVM нельзя испытать, отметить `NOT TESTED` и ограничить релизное заявление; не заменять адаптер гипотезой о совместимости.

## Baseline (этап 0)

| Проверка | Результат | Свидетельство |
|---|---|---|
| `main` ↔ `origin/main` | Совпадают, commit `030adfa`; удалённый `refs/heads/main` также совпал | `baseline-git` |
| Опубликованный `pi-v0.87.0-build.2` | Аннотированный tag на `1564e39`; единственное отличие `main` — commit с README и исходным лабораторным планом | `baseline-git` |
| Исходный checkout | Отсутствуют модификации отслеживаемых файлов; `.pi/` содержит локальные служебные файлы подтверждённой цели, **не** копировать их в лабораторную ветку/публичный Git | `baseline-git` |
| Runtime | Node 25.8.1, npm 11.11.0, Git 2.54.0.windows.1, Python 3.14.2; глобальный пакет Pi 0.87.0 | `baseline-runtime` |
| `verify.ps1 -RepositoryOnly` | `failures=0 warnings=0` | `baseline-repo` |
| `verify.ps1 -Profile Both` (рабочий baseline, без изменений) | `failures=0 warnings=0`; приватный отчёт не включать в Git | `baseline-live` |
| `tests/scripts/run-tests.ps1` | `passed=23 failed=0` | `baseline-tests` |
| `safety-check.ps1 -Scope Tracked` | exit 0 | `baseline-safety` |
| Реестр npm | `@earendil-works/pi-coding-agent@0.99.1` опубликован (`npm view ... version`) | `official-registry` |
| Кандидатная ветка (только документы пока) | `verify.ps1 -RepositoryOnly`: 0/0; `safety-check.ps1 -Scope Tree`: exit 0 | `lab-repo-verify`, `lab-safety-tree` |

Приватный индекс идентификаторов: `<LAB_ROOT>/evidence/index.md`; публичная Markdown-доска никогда не содержит реальные пути к рабочим профилям или логи.

**Матрица 0.87.0 → 0.99.1:** факты о релизах сверены по закреплённым upstream-источникам; **ни одна новая runtime-возможность пока не испытана**.

| Новое / официальный источник | Выгода | Риск | Проверка кандидата | Runtime |
|---|---|---|---|---|
| [v0.87.1](https://github.com/earendil-works/pi/releases/tag/v0.87.1): Opus 5.5, GPT-6 Sol/Luna; [v0.99.0](https://github.com/earendil-works/pi/releases/tag/v0.99.0): Sonnet 5.5; [v0.99.1](https://github.com/earendil-works/pi/releases/tag/v0.99.1): `gpt-6.1-sol` (OpenAI/Azure Responses/Codex) | Новый каталог | Наличие модели в каталоге не доказывает поддержку через Polza или доступ по подписке; точные IDs предыдущих моделей ещё сверить по каталогу | Каталог, provider/auth, real response, reasoning и tool call только с разрешения | NOT TESTED |
| [CLI 0.99.1: models/thinking](https://github.com/earendil-works/pi/blob/v0.99.1/packages/coding-agent/docs/cli.md#models): `provider/id:<thinking>` и `--thinking`; `--tools`, `defaultTools: ["+codemode"]` | Управление маршрутом и режимом | Разные пределы reasoning и опасность ложного fallback | Code/Task CLI, payload, limits | NOT TESTED |
| [v0.99.0](https://github.com/earendil-works/pi/releases/tag/v0.99.0) + [CLI extensions](https://github.com/earendil-works/pi/blob/v0.99.1/packages/coding-agent/docs/cli.md#extensions): `--no-extensions` выключает также builtins; выборочное `-e builtin:mcp` возможно | Явные границы расширений | Memory child может лишиться провайдера/инструмента | Безопасный ребёнок со статическим `polza-memory`, JSON/headless events | NOT TESTED |
| [SDK 0.99.1](https://github.com/earendil-works/pi/blob/v0.99.1/packages/coding-agent/docs/sdk.md#codemode-mcp), [v0.99.0](https://github.com/earendil-works/pi/releases/tag/v0.99.0): фабрики builtins в SDK явные, `session.bindExtensions()` для MCP; RPC disposition | Новые SDK/RPC сценарии | Расхождение CLI/SDK и границ событий | Точечные SDK/RPC и tool/hook contract tests | NOT TESTED |
| [MCP 0.99.1](https://github.com/earendil-works/pi/blob/v0.99.1/packages/coding-agent/docs/mcp.md#other-mcp-extensions): extension с `/mcp` заменяет built-in session MCP; [transport](https://github.com/earendil-works/pi/blob/v0.99.1/packages/coding-agent/docs/mcp.md#configure-servers) stdio/streamable HTTP, **не** legacy SSE; [exposure](https://github.com/earendil-works/pi/blob/v0.99.1/packages/coding-agent/docs/mcp.md#exposure) включая codemode | Потенциально меньше зависимостей и виртуальная маршрутизация | Потеря SSE, конкурирующие `/mcp`, непроверенный паритет WVM | Сохранить адаптер при общем gate; WVM/смена реализации **последним** | NOT TESTED |
| Локальные 15/12 pinned sources, patchers и npm-tree | Новое ядро без изменения состава | Peer/API incompatibility, неизвестный memory bundle, транзитивные уязвимости | Version/hash guard, матрица Code/Task, `npm audit` только в изолированном дереве | NOT TESTED |

**Известные npm-уязвимости:** в исходном публичном плане отдельные CVE/пакеты не перечислены. До изолированного `npm audit` состояние дерева — `NOT TESTED`, не «0 уязвимостей». Обновление Pi само по себе не является исправлением; находки и решения внести в release risks.

## Safety и решение о выпуске

- Ни `pi update`, ни глобальные `npm install -g`/`uv tool install`, ни `setx`, ни изменение живой SQLite DB/`source=user`, ни запуск из рабочего проекта с его local settings.
- Изоляцию памяти нельзя считать доказанной одним `PI_CODING_AGENT_DIR`: обязательны статическая проверка фактического пути DB и runtime проверка открытых DB/WAL/SHM + write diff глобальных путей.
- Сохранять `pi-mcp-adapter` в первом кандидате; возможная замена — только после WVM и паритета всех необходимых функций, без двух конкурирующих `/mcp`.
- `GO`: оба профиля и обязательные gates доказаны, публичный diff безопасен, рабочая установка неизменна, заявления ограничены измеренным. `NO-GO`: регрессия памяти/Polza/обязательного MCP/сабагентов или недоказанная изоляция. Отсутствие разрешения на модельный вызов — `NOT TESTED`, не ложный `PASS`.
- Даже `GO` даёт лишь готовность кандидата: перенос в `main`, тег, push и переключение рабочих профилей — отдельные решения владельца. Откат возвращает бинарник, оба профиля **и данные**.

## Блокеры и журнал решений

| Когда / веха | Событие | Действие / решение |
|---|---|---|
| 0 | Первый исследователь релизов не смог запуститься: недоступные child tools `web_search`, `fetch_content`, `get_search_content`, `source_check`. | Tracked tree не изменился; повтор через сабагента с доступным `curl` сверил официальный источник (`official-release-retry`). Сбой инструментария не считать проверкой runtime. |
| 0 | Git Bash `mkdir -m 700` на Windows создал пустой `<LAB_ROOT>`, но не смог применить POSIX-права. | Наследование NTFS ACL отключено; текущему пользователю оставлен единственный FullControl, после чего в отдельном root созданы только evidence и тестовый cwd. Никаких данных не потеряно. |
