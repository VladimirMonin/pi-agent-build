# Изоляция лаборатории Pi 0.99.1

Этот документ сохраняет version-specific процедуру/историю0.99.1. Общий контракт следующего стенда: [паспорт](lab-stand.md), [runbook](pi-upgrade-workflow.md), [evidence](lab-evidence.md), [current readiness](plans/lab-readiness-board.md). Ниже fixed baseline refs/counts — не вечные значения для новой машины/версии. Subsequent source-only native query fixes не означают accepted runner: current gate указан в board.

Это инструкция для **кандидата**, не команда обновить рабочий Pi. Исполняемые Code/Task, глобальный npm, настоящие ключи и `~/.pi/memory/memory.db` должны оставаться вне лаборатории. Подробные этапы и стоп-условия: [план](plans/pi-0.99.1-lab.md), текущие результаты: [доска](plans/pi-0.99.1-execution-board.md).

## Перед любой установкой

1. Сверьте `main`, `origin/main`, опубликованный tag `pi-v0.87.0-build.2` и чистоту отслеживаемых файлов. Не стирайте обнаруженные локальные изменения. Создайте **отдельный worktree/ветку** от tag вне рабочего checkout; перенесите плановый commit отдельно. Второй, отличный от worktree каталог `<LAB_ROOT>` разместите тоже вне всех Git-репозиториев. Старые smoke-каталоги не переиспользуйте и не очищайте.
2. На Windows защитите `<LAB_ROOT>` NTFS ACL (не `mkdir -m` из Git Bash): отключите наследование и оставьте FullControl только текущему пользователю. Создайте отдельные `pi-root/agent`, `pi-root/task`, `npm-prefix`, `home`, `appdata`, `localappdata`, `temp`, npm/uv/XDG-кэши, `sessions/{agent,task}`, `sessions-archive/{agent,task}`, `memory`, `test-cwd` и приватный `evidence` вне Git. Не переносите сюда рабочие `auth.json`, `models.json` с ключами, БД, сессии и логи.
3. В **синтетическом** `<LAB_ROOT>/test-cwd/.pi/settings.json` задайте только `{"pi-memory":{"localPath":"../memory"}}`. Проверьте, что путь к `memory.db` и возможным `-wal`/`-shm` остаётся внутри `<LAB_ROOT>`, включая reparse/junction links. В профилях допускается только пустой локальный `mcp.json` без `imports` и servers; OAuth через OS credential store не считается изолированным одним `MCP_OAUTH_DIR`.
4. Запустите **только чтение**: `powershell -NoProfile -File scripts/lab-preflight.ps1 -LabRoot "<LAB_ROOT>" -RepoRoot "<LAB_WORKTREE>"`. `LAB PREFLIGHT PLAN: PASS` означает проверенные входные пути/пустые конфиги, а **не** разрешение на `install.ps1 -Apply` и не доказательство изоляции исполняемого Pi. Отрицательные случаи: `powershell -NoProfile -File tests/scripts/lab-preflight-tests.ps1 -FixtureRoot "<PRIVATE_FIXTURE_PARENT>"`. Любой FAIL — стоп до исправления. Этот preflight не создаёт каталоги и не устанавливает Pi.

## Проверка уже установленного кандидата

`install.ps1 -LabRoot <LAB_ROOT>` (также `-Apply`) и `install.sh --lab-root <LAB_ROOT>` (также `--apply`) принимают существующую установку только после полного installed-state gate. Успех: `VERIFIED INSTALLED-STATE NO-OP`, без npm/package/launcher writes. Смешанная, частичная или неизвестная установка — отказ, не repair/reinstall. Проверяются канонический private launcher/Pi version, 15 Code и 12 Task identities, точные synthetic configs/skills, canonical patches (Code session-search `--runtime-only`, Task full patch), private external metadata/version и mandatory stdio probes. Автоматический **пустой** `auth.json` допустим; ключи — нет.

`verify.ps1 -LabRoot <LAB_ROOT> -Profile Both` / `verify.sh --lab-root <LAB_ROOT> --profile Both` и `lab-preflight.ps1 -RequireInstalledPi` используют этот же gate. У installed links/junctions конечная существующая цель должна оставаться внутри LAB; escaping/broken/cyclic links запрещены. Fresh preflight по-прежнему запрещает reparse points. Windows installed gate требует Python >=3.12 для junction inspection.

External probes используют только абсолютные private ast-grep/CBM/Serena binaries, без uvx/download/global fallback. Mandatory CBM и Serena: local stdio `initialize` + `tools/list`, synthetic private cwd, dashboard/HTTP выключены; **не** `tools/call`. Private cache/log state может создаваться даже при Plan/no-op. Metadata/version не доказывают full functionality; LSP/indexing, optional MCP, реальные providers, native Linux/macOS и WVM остаются NOT TESTED. Конкретный отказ процесса (включая CBM ACL identity guard на родительском каталоге) — FAIL, не skip; shared-parent ACL нельзя менять автоматически ради PASS.

## Process-local окружение установщика

Нельзя ограничиться `-PiRoot` или `PI_CODING_AGENT_DIR`: существующий установщик без лабораторного режима ставит Pi/npm/Code tools **глобально**, а stock `pi-memory` использует `~/.pi/memory/memory.db`. Лабораторный installer вызывает fail-closed preflight и явный бинарник `<LAB_ROOT>/npm-prefix/pi.cmd` (POSIX: `bin/pi`); без этих gates его `Apply` **запрещён**. Не используйте `pi update`, `setx`, пользовательский `bin`, глобальный `npm install -g`/`uv tool install` и fallback на `pi` из `PATH`.

Для каждого запуска соберите новый allowlist окружения, **не** наследуйте provider keys/`NODE_OPTIONS`/непроверенные redirect-переменные. Обязательные направления:

| Класс | Значение внутри `<LAB_ROOT>` |
|---|---|
| Home и кеши | `HOME`, `USERPROFILE`, `APPDATA`, `LOCALAPPDATA`, `TEMP`, `TMP`, XDG config/cache/data/state, npm prefix/cache/userconfig/globalconfig, uv cache/tool/bin |
| Pi Code/Task | `PI_CODING_AGENT_DIR=pi-root/{agent,task}`, `PI_AGENT_BUILD_NPM_PREFIX=npm-prefix`, `PI_CODING_AGENT_SESSION_DIR=sessions/{agent,task}`; явно передать `--session-dir` при runtime проверке |
| Plugin sources | `PI_SESSION_DIR=sessions/{agent,task}`, `PI_SESSION_ARCHIVE_DIR=sessions-archive/{agent,task}`, `PI_CBM_CACHE_DIR=cbm-cache`; `PI_INTERCOM_SCOPE_ID` отдельный для лаборатории |
| MCP | `PI_MCP_CONFIG_MODE=exclusive`, пустой профильный `mcp.json` без `imports` до осознанного теста; не запускать OAuth/stdio-серверы с унаследованными секретами |
| Дочерние процессы | Узкий `PATH` из проверенных бинарников и приватного prefix; убедиться, что потомок видит те же маршруты. |

Даже без установки `npm view`/`npm config` могут создать debug-log и cache в общих пользовательских каталогах. Не вызывайте их из обычной shell-сессии: только отдельный child с `npm_config_cache`, `npm_config_userconfig`, `npm_config_globalconfig`, `npm_config_prefix`, `HOME`/`APPDATA`/`LOCALAPPDATA` под `<LAB_ROOT>`; после него сравните внешние пути. Не очищайте общий npm cache «для восстановления».

`PI_TRACE_PARENT_DIR`, `PI_GOAL_ROOT`, `PI_GOAL_GLOBAL_SETTINGS_FILE`, `CBM_CACHE_DIR`, `PI_POLZA_ENV_FILE`, `MCP_OAUTH_DIR` и любые явные абсолютные пути в profile/project configs либо отсутствуют, либо проверены на принадлежность лаборатории. Goal-X, Polza cache, MCP trace, subagent schedules и некоторые outputs пишут в **cwd**; cwd должен быть `<LAB_ROOT>/test-cwd`, не исходный проект и не worktree. Session-search хранит index отдельно от **источников** sessions; проверяйте оба пути.

## Два разных gate

- **Предварительный (до установки):** статическая карта путей, ACL, пустые конфиги, `lab-preflight.ps1`, подставной child и потомок с синтетическими данными; краткое сравнение рабочих файлов до/после. Если параллельно работает старый Pi, его живые SQLite WAL/SHM могут меняться сами: широкая hash-разница без атрибуции не доказывает причину. Ничего не исправляйте в живой БД.
- **Runtime (после изолированной установки, но до любых ключей/моделей):** только явный кандидатный Pi 0.99.1; оба профиля; реально открытые memory DB/WAL/SHM, сессии, MCP/Trace, session-search, Goal-X/intercom, CBM, потомки и write paths. Нужна процессная атрибуция либо отдельный пользователь ОС/спокойное окно для живого WAL. Не заменяйте её одним значением env или `--no-extensions`. При неизвестном пути записи — **STOP**. Только затем допускаются согласованные functional checks.

Тесты Git Bash показывают лишь POSIX-синтаксис на Windows, не нативный Linux/macOS. Все pristine patch stores и Trace payload используют byte-exact LF — `.gitattributes` фиксирует LF и для файлов с суффиксом `.ts.orig-*`, и для HTML. Иначе свежий Windows checkout может пройти JSON/unit checks, но остановиться на реальном checksum guard. Не отключайте guard: сначала сравните рабочие байты с Git HEAD и восстановите только неизменённые pristine файлы после приватного backup. Если `python3` в Windows PATH — Store alias, задайте process-local `PI_BUILD_PYTHON` на рабочий Python для shell-verifier; CRLF его вывода требует отдельной проверки. Не маскируйте ошибки `SkipPatchChecks`/`SkipExternalChecks` ради PASS.

Сырые доказательства оставляйте только в `<LAB_ROOT>/evidence/`; публичная доска содержит безопасные идентификаторы. WVM (legacy SSE и streamable HTTP) проверяйте **последним техническим этапом** после миграции и общих gates. Даже лабораторный GO не разрешает автоматически менять рабочие профили, переносить в `main`, выпускать tag или push: нужны отдельные решения владельца и приватный откат бинарника, двух профилей и данных.
