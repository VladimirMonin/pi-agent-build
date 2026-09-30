# Изоляция лаборатории Pi 0.99.1

Это инструкция для **кандидата**, не команда обновить рабочий Pi. Исполняемые Code/Task, глобальный npm, настоящие ключи и `~/.pi/memory/memory.db` должны оставаться вне лаборатории. Подробные этапы и стоп-условия: [план](plans/pi-0.99.1-lab.md), текущие результаты: [доска](plans/pi-0.99.1-execution-board.md).

## Перед любой установкой

1. Сверьте `main`, `origin/main`, опубликованный tag `pi-v0.87.0-build.2` и чистоту отслеживаемых файлов. Не стирайте обнаруженные локальные изменения. Создайте **отдельный worktree/ветку** от tag вне рабочего checkout; перенесите плановый commit отдельно. Второй, отличный от worktree каталог `<LAB_ROOT>` разместите тоже вне всех Git-репозиториев. Старые smoke-каталоги не переиспользуйте и не очищайте.
2. На Windows защитите `<LAB_ROOT>` NTFS ACL (не `mkdir -m` из Git Bash): отключите наследование и оставьте FullControl только текущему пользователю. Создайте отдельные `pi-root/agent`, `pi-root/task`, `npm-prefix`, `home`, `appdata`, `localappdata`, `temp`, npm/uv/XDG-кэши, `sessions/{agent,task}`, `sessions-archive/{agent,task}`, `memory`, `test-cwd` и приватный `evidence` вне Git. Не переносите сюда рабочие `auth.json`, `models.json` с ключами, БД, сессии и логи.
3. В **синтетическом** `<LAB_ROOT>/test-cwd/.pi/settings.json` задайте только `{"pi-memory":{"localPath":"../memory"}}`. Проверьте, что путь к `memory.db` и возможным `-wal`/`-shm` остаётся внутри `<LAB_ROOT>`, включая reparse/junction links. В профилях допускается только пустой локальный `mcp.json` без `imports` и servers; OAuth через OS credential store не считается изолированным одним `MCP_OAUTH_DIR`.
4. Запустите **только чтение**: `powershell -NoProfile -File scripts/lab-preflight.ps1 -LabRoot "<LAB_ROOT>" -RepoRoot "<LAB_WORKTREE>"`. `LAB PREFLIGHT PLAN: PASS` означает проверенные входные пути/пустые конфиги, а **не** разрешение на `install.ps1 -Apply` и не доказательство изоляции исполняемого Pi. Отрицательные случаи: `powershell -NoProfile -File tests/scripts/lab-preflight-tests.ps1`. Любой FAIL — стоп до исправления. Этот preflight не создаёт каталоги и не устанавливает Pi.

## Process-local окружение для будущего установщика

Нельзя ограничиться `-PiRoot` или `PI_CODING_AGENT_DIR`: существующий установщик без лабораторного режима ставит Pi/npm/Code tools **глобально**, а stock `pi-memory` использует `~/.pi/memory/memory.db`. Пока installer не вызывает fail-closed preflight и явный бинарник `<LAB_ROOT>/npm-prefix/pi.cmd` (POSIX: `bin/pi`), его `Apply` **запрещён**. Не используйте `pi update`, `setx`, пользовательский `bin`, глобальный `npm install -g`/`uv tool install` и fallback на `pi` из `PATH`.

Для каждого запуска соберите новый allowlist окружения, **не** наследуйте provider keys/`NODE_OPTIONS`/непроверенные redirect-переменные. Обязательные направления:

| Класс | Значение внутри `<LAB_ROOT>` |
|---|---|
| Home и кеши | `HOME`, `USERPROFILE`, `APPDATA`, `LOCALAPPDATA`, `TEMP`, `TMP`, XDG config/cache/data/state, npm prefix/cache/userconfig/globalconfig, uv cache/tool/bin |
| Pi Code/Task | `PI_CODING_AGENT_DIR=pi-root/{agent,task}`, `PI_AGENT_BUILD_NPM_PREFIX=npm-prefix`, `PI_CODING_AGENT_SESSION_DIR=sessions/{agent,task}`; явно передать `--session-dir` при runtime проверке |
| Plugin sources | `PI_SESSION_DIR=sessions/{agent,task}`, `PI_SESSION_ARCHIVE_DIR=sessions-archive/{agent,task}`, `PI_CBM_CACHE_DIR=cbm-cache`; `PI_INTERCOM_SCOPE_ID` отдельный для лаборатории |
| MCP | `PI_MCP_CONFIG_MODE=exclusive`, пустой профильный `mcp.json` без `imports` до осознанного теста; не запускать OAuth/stdio-серверы с унаследованными секретами |
| Дочерние процессы | Узкий `PATH` из проверенных бинарников и приватного prefix; убедиться, что потомок видит те же маршруты. |

`PI_TRACE_PARENT_DIR`, `PI_GOAL_ROOT`, `PI_GOAL_GLOBAL_SETTINGS_FILE`, `CBM_CACHE_DIR`, `PI_POLZA_ENV_FILE`, `MCP_OAUTH_DIR` и любые явные абсолютные пути в profile/project configs либо отсутствуют, либо проверены на принадлежность лаборатории. Goal-X, Polza cache, MCP trace, subagent schedules и некоторые outputs пишут в **cwd**; cwd должен быть `<LAB_ROOT>/test-cwd`, не исходный проект и не worktree. Session-search хранит index отдельно от **источников** sessions; проверяйте оба пути.

## Два разных gate

- **Предварительный (до установки):** статическая карта путей, ACL, пустые конфиги, `lab-preflight.ps1`, подставной child и потомок с синтетическими данными; краткое сравнение рабочих файлов до/после. Если параллельно работает старый Pi, его живые SQLite WAL/SHM могут меняться сами: широкая hash-разница без атрибуции не доказывает причину. Ничего не исправляйте в живой БД.
- **Runtime (после изолированной установки, но до любых ключей/моделей):** только явный кандидатный Pi 0.99.1; оба профиля; реально открытые memory DB/WAL/SHM, сессии, MCP/Trace, session-search, Goal-X/intercom, CBM, потомки и write paths. Нужна процессная атрибуция либо отдельный пользователь ОС/спокойное окно для живого WAL. Не заменяйте её одним значением env или `--no-extensions`. При неизвестном пути записи — **STOP**. Только затем допускаются согласованные functional checks.

Тесты Git Bash показывают лишь POSIX-синтаксис на Windows, не нативный Linux/macOS. Патч `pi-session-search` использует byte-exact LF store — `.gitattributes` фиксирует LF для его TypeScript-источников. Если `python3` в Windows PATH — Store alias, задайте process-local `PI_BUILD_PYTHON` на рабочий Python для shell-verifier; CRLF его вывода требует отдельной проверки. Не маскируйте ошибки `SkipPatchChecks`/`SkipExternalChecks` ради PASS.

Сырые доказательства оставляйте только в `<LAB_ROOT>/evidence/`; публичная доска содержит безопасные идентификаторы. WVM (legacy SSE и streamable HTTP) проверяйте **последним техническим этапом** после миграции и общих gates. Даже лабораторный GO не разрешает автоматически менять рабочие профили, переносить в `main`, выпускать tag или push: нужны отдельные решения владельца и приватный откат бинарника, двух профилей и данных.
