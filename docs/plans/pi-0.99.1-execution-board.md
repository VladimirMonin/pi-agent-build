# Pi 0.99.1 — доска выполнения лабораторной миграции

**Цель:** выполнить [лабораторный план](pi-0.99.1-lab.md) на строго `@earendil-works/pi-coding-agent@0.99.1` без изменения рабочих Code/Task. Эта доска отражает *проверенные* факты, а не обещание совместимости. Рабочая ветка — `lab/pi-0.99.1`, создана от опубликованного `pi-v0.87.0-build.2`; поверх неё перенесён только существующий commit с планом. Рабочий `main` не меняем.

**Обозначения:** `TODO` → `DOING` → `PASS` / `FAIL` / `NOT TESTED` / `BLOCKED`. `PASS` требует команду и свидетельство; отсутствие доступа/разрешения означает `NOT TESTED`, а не `PASS`. Сырые логи, пути с именами владельца и результаты модельных запросов находятся **только** в `<LAB_ROOT>/evidence/`, вне Git. В этой доске приведены только безопасные идентификаторы доказательств и команды с плейсхолдерами. Новые запросы к платным провайдерам и публикация требуют отдельных разрешений.

## Очередь и зависимости

| № | Веха | Статус | Gate / свидетельство |
|---|---|---|---|
| 0 | Baseline и матрица изменений 0.87.0 → 0.99.1 | PASS | `baseline-repo`, `baseline-tests`, `baseline-live`, `baseline-safety`, `official-release-retry`, `official-registry`, `lab-repo-verify`, `lab-safety-tree` |
| 1 | Отдельные worktree и `<LAB_ROOT>`, предварительная изоляция | PASS | ACL root: только текущий пользователь; `preinstall-global-snapshot`, `static-paths`, `static-path-closure`, `preflight-probe`, `dummy-window`, `lab-preflight-plan`, `lab-preflight-tests` (15/15), `stage1-full-unit` (23/23), `stage1-repo-verify` (0/0). Повторяемая [инструкция](../lab-isolation.md) опубликована в ветке. Это **только предварительный** gate: до подключения fail-closed preflight к установщику этапа 2 его Apply запрещён. |
| 2 | Лабораторные installer/verifier и точный lock 0.99.1 | DOING | Кандидатный lock/templates → строго 0.99.1; Windows/POSIX независимые writer lanes, затем один integration owner. До review явного Pi/npm prefix никакого Apply; runtime isolation gate **до credentials/моделей** |
| 3 | Патчи, плагины, CLI и обязательные MCP-маршруты (пока с адаптером) | TODO | [Матрица Code/Task × компонент](pi-0.99.1-compat-matrix.md) подготовлена, все runtime-ячейки пока NOT TESTED; память/ребёнок `--no-extensions`/JSON-headless/tools; не испытывать WVM на этом этапе |
| 4 | Каталог, доступность моделей, реальный payload | TODO | [Отдельная матрица](pi-0.99.1-model-matrix.md) catalog/auth/response/tool/limits создана; всё пока NOT TESTED; платные вызовы — лишь с отдельного разрешения |
| 5 | Общие tests/platform/safety gates | TODO | unit/contract, оба verifier, JSON/schema/синтаксис, Markdown links, diff, safety; Windows нативно; прочие ОС — только с нативным доказательством |
| 6 | **WVM последним техническим этапом**: legacy SSE + streamable HTTP и выбор MCP | TODO | Изолированные конфигурации, функциональный паритет адаптера/встроенного MCP; затронутые финальные smokes после изменений |
| 7 | GO/NO-GO, документация, откат, решение владельца | TODO | Review staged-файлов, остаточные риски, приватный backup/rollback; нет автоматического main/tag/push/переключения |

Зависимости строгие: 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7. Внешние read-only исследования можно делать параллельно, но gates не перепрыгивать.

**Этап 2 — multi-seam topology (до writer launch):** Windows PowerShell и POSIX shell — независимые контракты с разными install/verify/test файлами; общие runtime lock, profile templates и доска принадлежат только интеграционному владельцу. Каждый writer работает в отдельном Git worktree от кандидатного commit и передаёт проверенный diff/отчёт; если его инструкции запрещают git writes, commit на lane после review создаёт parent. Интеграция — последовательный перенос с повтором gates.

| Lane / изоляция | Исключительный владелец и решение | Gate / handoff |
|---|---|---|
| Windows / `<LAB_WIN_LANE>` вне `main` | `scripts/install.ps1`, `verify.ps1`, при необходимости `common.ps1`/`lab-preflight.ps1`, Windows-тесты; только lab-mode, глобальный default не запускать | Synthetic plan/apply с fake toolchain, оба profile preflight, exact private Pi path, без реальной установки до parent review; diff/handoff |
| POSIX / `<LAB_POSIX_LANE>` вне `main` | `scripts/install.sh`, `verify.sh`, при необходимости `common.sh`, shell-тесты; Git Bash — лишь синтаксис на Windows | Dry-run/fake lifecycle, no global fallback, исправить CRLF в Git Bash verifier, native POSIX остаётся NOT TESTED; diff/handoff |
| Интеграция / `<LAB_WORKTREE>` | Только parent: `manifests/runtime.lock.json`, Code/Task templates, docs/board; перенести отдельно проверенные lane diffs | Windows и Git Bash repository gates, diff/safety, затем явный runtime isolation gate на синтетике |

**Решение об идемпотентности:** первый lab `Apply` допускается лишь на свежих целевых каталогах; повторный `Apply` на установленном дереве обязан fail-closed, пока отдельный installed-state gate не подтвердит безопасный no-op/reapply. До такого gate **не заявлять** идемпотентность Apply и не выпускать GO. Если у worker строже запрет на Git writes, он передаёт unstaged diff, а parent делает осмысленный commit после проверки. Если WVM нельзя испытать, отметить `NOT TESTED` и ограничить релизное заявление; не заменять адаптер гипотезой о совместимости.

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
| Кандидатная ветка (этапы 1–2, без реальной установки) | `verify.ps1 -RepositoryOnly`: 0/0; `safety-check.ps1 -Scope Tree`: exit 0; lock 0.99.1 закреплён только в lab commit | `lab-repo-verify`, `lab-safety-tree`, `stage2-seed-repo-verify` |

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

## Предварительная карта изоляции (этап 1; реальный Pi ещё не запускался)

| Источник записи / причина | Лабораторный маршрут и gate |
|---|---|
| npm/Pi/внешние CLI | Отдельный `<LAB_ROOT>/npm-prefix`, npm cache/config и **явный бинарник** Pi; существующие установщики пока пишут глобально, поэтому `-Apply`/`--apply` **запрещены** до этапа 2. Глобальные `uv tool` и пользовательские launchers исключены. |
| Профили и сессии | `PI_CODING_AGENT_DIR=<LAB_ROOT>/pi-root/{agent,task}`, `PI_CODING_AGENT_SESSION_DIR=<LAB_ROOT>/sessions/{agent,task}` и, где поддерживается, `--session-dir`; [CLI 0.99.1](https://github.com/earendil-works/pi/blob/v0.99.1/packages/coding-agent/docs/cli.md#sessions) фиксирует приоритет CLI-флага. |
| SQLite memory | Даже при profile env stock default — `~/.pi/memory/memory.db`; в синтетическом `<LAB_ROOT>/test-cwd/.pi/settings.json` задан относительный `pi-memory.localPath` под `<LAB_ROOT>/memory`. Изолированный `USERPROFILE/HOME` защищает и fallback, но фактическую DB/WAL/SHM докажет только runtime gate. |
| Goal-X, intercom, subagents | Goal state/trace — project-local `.pi` в **тестовом cwd**, broker/config и артефакты — под профилем; `PI_INTERCOM_SCOPE_ID` отдельный. Абсолютные overrides (`goalsRoot`, artifact roots, broker) не использовать без явной проверки. |
| session-search, Trace, Polza, CBM | Home/default indexes и cache — под синтетическим home, Trace под профилем, Polza project cache под test-cwd; `PI_CBM_CACHE_DIR` задан под `<LAB_ROOT>`. Перед runtime сверить Task-specific patch и фактические пути. |
| MCP/внешние серверы | Адаптер может читать shared host configs и передавать env в stdio child: синтетический `HOME/USERPROFILE`, чистый test-cwd, no credentials и explicit lab config; `PI_MCP_CONFIG_MODE=exclusive` только после проверки семантики. Не запускать WVM до последнего этапа. |
| Другие кэши и дочерние процессы | Переопределить `APPDATA`, `LOCALAPPDATA`, `TEMP/TMP`, XDG, npm/uv cache/tool dirs; разрешать только узкий `PATH`, исключать внешние ключи, `NODE_OPTIONS` и неаудированные redirect-env. |

Подставной Node-child и его потомок из `<LAB_ROOT>/test-cwd` получили только очищенный process-local env; проверили `os.homedir()`, каталоги и `memory.db` внутри lab, отсутствие синтетического секрета: `preflight-probe` PASS. Отдельный `scripts/lab-preflight.ps1` проверяет пути, Git/reparse-escape, пустые конфиги MCP/npm, синтетическую БД; 15 отрицательных/положительных тестов PASS, реальный lab PLAN PASS и ничего не устанавливает. Приватные Windows ACL `<LAB_ROOT>` не наследуются и дают доступ только владельцу. **Это не runtime gate:** расширения исполняются с правами пользователя, а активные рабочие SQLite WAL/SHM меняются между снимками даже без лабораторного Pi; простая hash-разница не определяет виновный процесс. До любых credentials/реальных данных требуется отдельная проверка маршрутов *фактического* Pi и сравнение рабочих путей с учётом конкурирующих процессов.

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
| 1 | Изменился hash живых `memory.db-wal`/`-shm` между широким baseline и сравниванием после подставного child; сам `memory.db` и проверенные рабочие settings/Pi package не изменились. | Остановили продвижение к установке, затем повторили *ограниченное окно* вокруг child+descendant и отдельно вокруг preflight PLAN: global diff пуст, включая WAL/SHM (`dummy-window`, `preflight-plan-window`). Конкурирующие Pi/Node sessions остаются; реальному Pi нужен собственный runtime gate, широкую WAL-разницу нельзя атрибутировать лаборатории. |
| 1 | Независимый review preflight указал недостающие пути, флаг с ложной претензией на установленный Pi и возможную утечку путей в ошибке. | Дополнены все плановые пути профиля/сессий/npm/uv, неподтверждённый installed-флаг удалён, диагностические ошибки обезличены; добавлены отрицательные тесты Git-escape, пустых npm configs и fake launcher (`lab-preflight-tests`: 15/15). Реальная установка по-прежнему запрещена до интеграции gate. |
| 1 | Первый полный Windows unit run в новом worktree показал 21/23: Git `text=auto` развернул byte-exact TS store в CRLF, а длинный путь сломал строковую проверку synthetic Git error из-за переносов. | `.gitattributes` закрепил LF для pristine TS store; тест принимает whitespace между `pinned` и `commit`. Повтор: `stage1-full-unit` 23/23, не менять живые package files. |
| 2 | Parent прочитал опубликованные metadata `npm view ...@0.99.1` без отдельного npm cache; команда создала debug-log в общем пользовательском npm cache (`stage2-parent-npm-probe`). Это **не установка** и не изменение рабочих Code/Task/БД, но нарушает строгую формулировку «вообще никаких глобальных файлов» для этого диагностического шага. | Ничего в общем cache не удалять. Все следующие npm-запросы направлять process-local в `<LAB_ROOT>` с приватными config/cache; перед реальным Apply повторить ограниченный baseline/diff, не включать эту запись в окно доказательства runtime gate. Рабочие npm package/prefix после этого probe отдельной проверкой ещё не подтверждены. |
| 5 | `verify.sh --repository-only` в Git Bash на Windows не прошёл: Windows `python.exe` выдаёт CRLF в перечне patch имён; `python3` в PATH является неработающим Store alias. | Отложено до POSIX-проверок этапа 5; `PI_BUILD_PYTHON` выбирает рабочий Python, CRLF-normalization/регрессию исправить адресно. Это не результат нативного Linux/macOS. |
