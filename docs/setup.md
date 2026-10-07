# Установка сборки

Состав задают текущие `manifests/*.lock.json`: в source сейчас Pi `1.0.4`; [build.5](releases/pi-1.0.4-build.5.md) обновляет MCP Adapter5.1.0 Both; builtin:mcp остаётся выключен. [build.4](releases/pi-1.0.4-build.4.md) обновил Session Search1.6.0 Both с profile/runtime patch и без forced reindex. [build.3](releases/pi-1.0.4-build.3.md) обновил Inspector1.3.0 и Code Serena wrapper0.9.20 (Agent1.7.0 неизменён). Предыдущий [build.2](releases/pi-1.0.4-build.2.md) обновил Subagents0.76.1, GoalX0.32.3 и Intercom0.16.1. Both candidate loading и короткий local-mock/Windows broker smoke PASS. Владелец уже обновил рабочий Pi до `1.0.4`; core SDK local-mock проверен отдельно. Прежние Both plugin checks относятся к `1.0.2`, не являются свежей проверкой `1.0.4` ([scope](releases/pi-1.0.4.md)). Скрипты предусмотрены для Windows x64 и POSIX; actual native scope — в [readiness board](plans/lab-readiness-board.md), shell/fake проверки не подтверждают live macOS/Linux. Это не bit-reproducible build: переносимых transitive lockfiles и hashes всех скачиваемых artifacts пока нет, поэтому dependency tree может измениться при повторной установке. Команды ниже не переносят пользовательские сессии, память или credentials. Для этого см. [перенос состояния](state-migration.md).

Различия платформ и POSIX-эквиваленты скриптов описаны в [platforms.md](platforms.md).

> Для обновления кандидата используйте [паспорт стенда](lab-stand.md) и [lab upgrade runbook](pi-upgrade-workflow.md), не global manual commands ниже. Read-only PLAN, private executable probes, PREPARE, install и runtime gate — разные действия. Этот документ не разрешает изменять рабочие Code/Task.
>
> Ручные примеры с Pi0.87.0 ниже сохранены как working-baseline procedure, не команда поставить новый target. Целевая политика следующего выпуска — Trace установлен/default-off в обоих профилях; [проверенный opt-in/off recipe](trace.md) использует обычный `pi -e` без изменения canonical filters.

## До установки

Требования разделены по роли:

- installer проверяет exact Node.js `25.8.1`, npm `11.11.0` и Git for Windows `2.54.0.windows.1`; поддерживаемый минимум Node — `24.0.0` из-за `pi-session-search`, но automatic install gate требует именно manifest version;
- Python `3.8+` нужен patchers и Trace renderer;
- Python package `jsonschema` нужен для обязательной schema validation в `scripts/verify.ps1`/`verify.sh`;
- `uv 0.9.27` нужен при установке Code (Serena) и для рекомендуемой установки optional Python MCP server;
- `serena-agent==1.7.0` требует Python `>=3.11,<3.15`, а `mcp-server-fetch==2025.4.7` — Python `>=3.10`; Для Serena manifest закрепляет managed Python `3.12.10`, отличный от `python` для patchers: это избегает source-build `pyyaml==6.0.2` на Python 3.14.

Проверка:

```bash
node --version
npm --version
git --version
python --version
uv --version
python -c "import jsonschema; print(jsonschema.__version__)"
```

Все Pi-пакеты исполняются с правами текущего пользователя. Перед обновлением сверяйте источники и версии с [`pi-packages.lock.json`](../manifests/pi-packages.lock.json), а не устанавливайте `latest`.

> На macOS/Linux точные Windows-версии Node/npm/Git из manifest обычно недоступны. `verify.sh` сообщает о расхождении как WARN; жёсткие требования — Node `>= 24.0.0`, Python `>= 3.8` и `jsonschema`. Флаг `--strict-runtime` включает проверку exact Windows-версий.

## Автоматизированная установка

Installer сначала работает как dry-run plan. По `-Apply` (PowerShell) или `--apply` (POSIX) он проверяет runtime prerequisites, устанавливает Pi и profile packages, ставит внешние tools выбранного профиля, создаёт отсутствующие profile configs/навык и применяет patches, но **не запускает интерактивную/model Pi-сессию и не пишет credentials**. Profile packages устанавливаются штатной командой `pi install <source>` с профильным `PI_CODING_AGENT_DIR`, а не прямым `npm install --prefix`; это сохраняет package metadata/filter semantics Pi. Git-пакет передаётся как immutable object id:

```powershell
$RepoRoot = '<REPO_ROOT>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install.ps1" -Profile Both
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install.ps1" -Profile Both -Apply
```

Installer запускает `npm`, `pi` и `uv` с allowlisted process environment, а не наследует весь текущий environment: provider/API credentials не должны попадать в package lifecycle children. Это защита от случайной утечки, не sandbox; устанавливаемые packages и их lifecycle scripts всё равно выполняются с правами пользователя.

По умолчанию существующие profile configs сохраняются без полного replace. Для `settings.json` installer после штатных `pi install` выполняет целевой merge: сохраняет неизвестные пользовательские поля и дополнительные пакеты, но приводит 15/12 пакетов сборки к exact sources, в том числе ставит `pi-goal-x` **перед** `pi-intercom`, восстанавливает отключающий filter `pi-background-tasks` и задаёт `memory.consolidationModel`. Оба verifier'а проверяют **все закреплённые источники по порядку**, а не только версии на диске. В существующий `models.json` добавляется только отсутствующий provider `polza-memory`; другие providers сохраняются. Если там уже объявлен старый **static** `polza`, полный installer отказывает **до package writes**, чтобы не столкнуть его с динамическим `pi-polza`: сначала сохраните backup и перенесите этот provider в `polza-memory` по [инструкции](polza-memory.md). `ollama-cloud.json` и существующий `skills/memory-ops/` остаются без изменений. Перед merge создаются приватные runtime backups. Установщики также сразу кладут [автономный Goal X preset](goal-autonomy.md) в `pi-goal-x-settings.json` и две инструкции в `AGENTS.md`: unlimited, implicit continuation, Oracle/Auditor high. Существующие Goal X settings и AGENTS сохраняются. Флаг `-ReplaceProfileConfigs` явно разрешает полную замену этих файлов и остальных конфигурационных компонентов шаблонами с backup.

Если пакеты уже установлены, но `settings.json` содержит старые незакреплённые строки `npm:<name>`, приведите их в соответствие **без переустановки пакетов и без изменения патчей**:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install.ps1" -Profile Both -Apply -SyncSettingsOnly
```

Эта команда проверяет payload каждого пакета и **до записи обоих профилей** наличие служебной модели `memory.consolidationModel` в соответствующем `models.json` и доступность её настроенного credential (env-переменная должна быть задана; команда из `apiKey: "!…"` не исполняется при проверке). Если route отсутствует, merge отказывается работать вместо установки недоступной модели. Команда сохраняет дополнительные настройки и `memory.factProjectAliases`, создаёт backup и правит только `settings.json`; `models.json` предварительно настройте по [Polza для памяти](polza-memory.md). Полная переустановка перед первым `pi install` проверяет уже существующий memory bundle: неизвестная правка не будет стёрта штатным lifecycle. Приватные alias для одного проекта и его worktree описаны в [memory-injection.md](fixes/memory-injection.md).

Launchers устанавливаются отдельным plan/apply:

```powershell
$RepoRoot = '<REPO_ROOT>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install-launchers.ps1" -Profile Both -Shell Both
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install-launchers.ps1" -Profile Both -Shell Both -Apply
```

После этого всё равно нужны локальные provider configs, `/login` и проверки из разделов 5 и 8. Далее приведён ручной эквивалент, полезный для аудита и точечного восстановления.

## 1. Pi Agent — исторический working baseline, не lab upgrade

Следующий block явно относится к0.87.0. Для кандидата exact version берётся из manifest и устанавливается только private lab-mode installer после gates.

```bash
npm install -g --no-audit --no-fund npm@11.11.0
npm install -g --no-audit --no-fund @earendil-works/pi-coding-agent@0.87.0
pi --version
```

Ожидается `0.87.0`.

## 2. Каталоги профилей

`PI_CODING_AGENT_DIR` задаётся только процессу. Не используйте `setx`: глобальная переменная лишит launchers возможности переключать профиль.

Создайте каталоги, но пока не подменяйте `settings.json`: сначала `pi install` должен штатно записать package entries и скачать payloads.

```bash
export REPO_ROOT="<REPO_ROOT>"
user_home="${USERPROFILE:-$HOME}"
user_home="${user_home//\\//}"
mkdir -p "$user_home/.pi/agent" "$user_home/.pi/task"
```

Команды следующих разделов выполняйте в той же Git Bash-сессии: в ней остаются `REPO_ROOT` и нормализованный `user_home`. Для аргументов native Windows programs используйте форму `C:/...`, а не MSYS `/c/...`; именно поэтому примеры строят путь из `USERPROFILE`.

Если профиль уже существует, заранее сделайте приватную резервную копию `settings.json`. `auth.json`, сессии и другие runtime-файлы не копируют в репозиторий.

## 3. Пакеты Pi

Функция ниже устанавливает 12 общих пакетов в выбранный профиль. Источники и версии совпадают с manifest.

```bash
install_common() {
  profile="$1"
  PI_CODING_AGENT_DIR="$profile" pi install npm:pi-ollama-cloud@0.12.1
  PI_CODING_AGENT_DIR="$profile" pi install npm:pi-trace-extension@0.1.16
  PI_CODING_AGENT_DIR="$profile" pi install npm:pi-context-inspector@1.3.0
  PI_CODING_AGENT_DIR="$profile" pi install npm:@juicesharp/rpiv-todo@2.12.0
  PI_CODING_AGENT_DIR="$profile" pi install https://github.com/VladimirMonin/pi-polza@cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139
  PI_CODING_AGENT_DIR="$profile" pi install npm:pi-subagents@0.76.1
  PI_CODING_AGENT_DIR="$profile" pi install npm:pi-goal-x@0.32.3
  PI_CODING_AGENT_DIR="$profile" pi install npm:pi-intercom@0.16.1
  PI_CODING_AGENT_DIR="$profile" pi install npm:pi-background-tasks@2.6.2
  PI_CODING_AGENT_DIR="$profile" pi install npm:pi-session-search@1.6.0
  PI_CODING_AGENT_DIR="$profile" pi install npm:@samfp/pi-memory@1.5.0
  PI_CODING_AGENT_DIR="$profile" pi install npm:pi-mcp-adapter@5.1.0
}

install_common "$user_home/.pi/agent"
install_common "$user_home/.pi/task"
```

Три code-only пакета:

```bash
PI_CODING_AGENT_DIR="$user_home/.pi/agent" pi install npm:@nicknisi/pi-ast-grep@0.2.1
PI_CODING_AGENT_DIR="$user_home/.pi/agent" pi install npm:@bacnh85/pi-serena@0.9.20
PI_CODING_AGENT_DIR="$user_home/.pi/agent" pi install npm:pi-cbm@1.2.1
```

Теперь приведите settings к декларативным шаблонам:

- в **совершенно новых** профилях скопируйте соответствующий `settings.template.json` поверх созданного `settings.json`;
- в существующих профилях не заменяйте файл целиком: вручную перенесите package sources, defaults, `memory` и object filter background-tasks, сохранив остальные пользовательские поля.

```bash
# Только для новых пустых профилей
cp "$REPO_ROOT/profiles/code/settings.template.json" "$user_home/.pi/agent/settings.json"
cp "$REPO_ROOT/profiles/task/settings.template.json" "$user_home/.pi/task/settings.json"
```

`pi-background-tasks` должен остаться установленным, но отключённым записью

```json
{"source":"npm:pi-background-tasks@2.6.2","extensions":[]}
```

После любого `pi install` и после посещения `pi config` заново проверьте эту запись: пустой массив означает «не загружать extension», а потерянный filter снова включает несовместимый package.

Проверьте состав отдельно:

```bash
PI_CODING_AGENT_DIR="$user_home/.pi/agent" pi list
PI_CODING_AGENT_DIR="$user_home/.pi/task" pi list
```

В Code должно быть 15 пакетов, в Task — 12; background-tasks показывается как `(filtered)`.

## 4. Внешние инструменты Code

```bash
npm install -g @ast-grep/cli@0.45.3
npm install -g codebase-memory-mcp@0.11.0
uv tool install --python 3.12.10 --prerelease=allow "serena-agent==1.7.0"
```

На Windows npm создаёт shell-shims, а `@nicknisi/pi-ast-grep` запускает процесс с `shell:false`. Поэтому положите реальный бинарник рядом с npm-shims:

```bash
npm_prefix="$(npm prefix -g | tr '\\' '/')"
cp "$npm_prefix/node_modules/@ast-grep/cli/ast-grep.exe" "$npm_prefix/ast-grep.exe"
ast-grep.exe --version
serena --version
"$npm_prefix/node_modules/codebase-memory-mcp/bin/codebase-memory-mcp.exe" --version
```

Ожидаются `0.45.3`, `1.7.0` и `0.11.0`.

### Опциональные MCP servers

Они не нужны для запуска Pi или `pi-mcp-adapter` и `install.ps1` их не устанавливает. Если нужны локальные executables из manifest, установите выбранные точные версии вручную. Для Fetch manifest закрепляет `2025.4.7`, но verifier проверяет наличие команды, не запуская server ради `--version`; установленную версию подтверждайте через `uv tool list` или metadata Python-пакета:

```bash
npm install -g @upstash/context7-mcp@3.2.2
npm install -g @brave/brave-search-mcp-server@2.0.85
uv tool install "mcp-server-fetch==2025.4.7"
```

Fetch `2025.4.7` требует Python `>=3.10`. Пример [`mcp.example.json`](../config/mcp.example.json) использует Context7 по remote URL, поэтому локальный `context7-mcp` нужен только если вы осознанно замените URL на command. Установка server binary не добавляет его в config автоматически и не подтверждает API/network access.

## 5. Конфигурация без публикации секретов

### Ollama Cloud

Скопируйте [`ollama-cloud.example.json`](../config/ollama-cloud.example.json) в `ollama-cloud.json` каждого профиля. Вход выполните внутри каждого профиля через `/login`; ключ сохранит Pi в локальном `auth.json`.

### Polza и служебная память

1. Скопируйте [`models.polza-memory.example.json`](../config/models.polza-memory.example.json) в `models.json` каждого профиля. Если файл уже есть, объедините объект `providers`, не заменяйте весь файл.
2. Перед запуском экспортируйте `POLZA_API_KEY` из локального secret store или текущей shell-сессии. Не записывайте значение в launcher или Git.
3. В `settings.json` оставьте `memory.consolidationModel` равным `polza-memory/deepseek/deepseek-v4.1-flash`.
4. Для semantic session search создайте локальный config из [`session-search.polza.example.json`](../config/session-search.polza.example.json): Code — `~/.pi/session-search/config.json`, Task после профильного patch — `<TASK_PROFILE_DIR>/session-search/config.json`. Поле `apiKey` хранит реальное значение и поэтому этот файл нельзя публиковать.

Почему одновременно нужны `pi-polza` и статический `polza-memory`, описано в [Polza memory](polza-memory.md).

### Прогрев локального embedder'а памяти

Patch `memory-windows-runtime` подключает локальную мультиязычную модель встраивания для семантического поиска по фактам памяти. Плагин загружает её лениво с жёстким таймаутом 30 с; на холодном кэше скачивание по медленному каналу может его превысить, и тогда плагин молча откатывается на FTS-only поиск. Скорость сети разная, поэтому модель нужно скачать заранее:

```bash
node scripts/warm-memory-embedder.mjs "$user_home/.pi/agent"
node scripts/warm-memory-embedder.mjs "$user_home/.pi/task"
```

Helper читает id модели из пропатченного `dist`, качает её в кэш `@xenova/transformers` активного профиля (у каждого профиля свой кэш, ~130 МБ) и использует щедрый таймаут с повторами. `scripts/install.sh --apply` вызывает его автоматически после применения patches; сбой прогрева только предупреждает и не прерывает установку. `scripts/verify.sh` показывает `PASS`/`WARN` по наличию кэша (WARN, а не FAIL — сеть не должна валить проверку).

### MCP

[`mcp.example.json`](../config/mcp.example.json) — только пример. Копируйте лишь нужные серверы в `~/.config/mcp/mcp.json` или профильный `<PI_CODING_AGENT_DIR>/mcp.json`. Не оставляйте placeholder вместо реального Brave key. MCP-команды имеют права локального пользователя; включайте approval для destructive tools.

## 6. Локальные исправления

Запускайте из корня репозитория. Сначала `--check`, затем `--apply` только для ожидаемых версий.

```bash
python patches/trace-ru-windows-profile/apply.py --agent-dir "$user_home/.pi/agent" --check
python patches/trace-ru-windows-profile/apply.py --agent-dir "$user_home/.pi/agent" --apply
python patches/trace-ru-windows-profile/apply.py --agent-dir "$user_home/.pi/task" --apply

python patches/memory-windows-runtime/apply.py --agent-dir "$user_home/.pi/agent" --check
python patches/memory-windows-runtime/apply.py --agent-dir "$user_home/.pi/agent"
python patches/memory-windows-runtime/apply.py --agent-dir "$user_home/.pi/task"

python patches/session-search-profile/apply.py --agent-dir "$user_home/.pi/task" --apply
python patches/serena-tools/apply.py --agent-dir "$user_home/.pi/agent" --apply
python patches/pi-cbm-011/apply.py --agent-dir "$user_home/.pi/agent" --apply
```

`memory-windows-runtime/apply.py` применяет patch без флага `--apply`; это особенность его CLI. Подробности и откат: [`docs/fixes/`](fixes/).

## 7. Launchers

Файлы в `launchers/` — шаблоны с tokens и не предназначены для прямого копирования. Рендерите их только через `install-launchers.ps1`; script подставляет exact profile root и npm prefix, делает backup существующих launchers и ставит executable bit POSIX-файлам при наличии `chmod`.

Default Windows target — `$HOME\bin`, Pi root — `$HOME\.pi`, npm prefix — `%APPDATA%\npm`. Для custom locations передайте их явно и в plan, и в apply:

```powershell
$RepoRoot = '<REPO_ROOT>'
$TargetDir = '<USER_BIN_DIR>'
$PiRoot = '<PI_ROOT>'
$NpmPrefix = '<NPM_GLOBAL_PREFIX>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install-launchers.ps1" `
  -Profile Both -Shell Both -TargetDir $TargetDir -PiRoot $PiRoot -NpmPrefix $NpmPrefix
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install-launchers.ps1" `
  -Profile Both -Shell Both -TargetDir $TargetDir -PiRoot $PiRoot -NpmPrefix $NpmPrefix -Apply
```

- Git Bash: `pi-code` и `pi-task`.
- CMD/PowerShell: `pi-code.cmd` и `pi-task.cmd`.
- оба launcher задают `PI_AGENT_BUILD_NPM_PREFIX` и запускают `pi` именно из этого prefix;
- `pi-code` также задаёт путь к реальному CBM executable и ограничивает фоновые индексаторы.

## 8. Проверка

Без модельного запроса:

```bash
pi-code --version
pi-task --version
pi-code --list-models
pi-task --list-models
pi-code list
pi-task list
```

В интерактивных сессиях:

- оба профиля: `/context`, `/todos`, `/trace`, `session_search`, `memory_stats`, `mcp({ search: "..." })`;
- Code: `ast_search`, `serena_status`, `/cbm status`;
- `/polza-model-info` и `/polza-balance` после `/login`;
- `/trace all` должен создать профильный dashboard с русским UI.

Runtime-тест memory выполняет реальный модельный вызов и может расходовать квоту. Pi-memory передаёт consolidation prompt дочернему Pi через command-line argument `-p`; текст может быть виден локальным process monitors, администраторам и telemetry, поэтому не используйте в smoke реальные секреты/приватный диалог:

```bash
node patches/memory-windows-runtime/tests/test-memory-runtime-scope.mjs code
node patches/memory-windows-runtime/tests/test-memory-runtime-scope.mjs task
```

Финальные repository/profile gates:

```powershell
$RepoRoot = '<REPO_ROOT>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\verify.ps1" -Profile Both
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\safety-check.ps1" -Scope Both
```

Семантика `verify.ps1`:

- `-RepositoryOnly` проверяет обязательные repository paths, JSON schemas и согласованность двух profile templates с manifests; установленный runtime/profile при этом не проверяется;
- `-ExternalOnly` после тех же repository gates запускает только probes внешних Code/MCP tools и не требует установленного Pi profile/runtime; это режим диагностики executable resolution;
- обычный запуск дополнительно проверяет exact Node/npm/Git/Pi/top-level package versions, минимум Python, состояние patches и direct-spawn внешних executables;
- обязательные Code tools отсутствуют/имеют неверную версию — failure; отсутствующие optional MCP commands — warning; найденный optional command с безопасным version probe, но неверной версией — failure;
- `-SkipExternalChecks` пропускает только probes внешних Code/MCP executables, а не runtime/packages/patches; `-SkipPatchChecks` отдельно пропускает installed patch checks;
- `failures > 0` даёт ненулевой exit; warnings сами по себе не доказывают полноту установки и не делают exit ненулевым.

Для `mcp-server-fetch` manifest не задаёт безопасный version probe: verifier проверяет только разрешение command и намеренно **не запускает** fetch server. Поэтому найденный executable ещё не подтверждает версию `2025.4.7`. Эта verification также не выполняет MCP handshake, provider login, network/API request, model call, session-search quality check или non-empty CBM query. Manual read-only smokes выше обязательны для заявлений о functional compatibility. Safety scan не заменяет ручной просмотр diff и никогда не должен печатать найденный secret целиком.

## Обновление и откат

Автоматического `scripts/update.ps1` в репозитории нет. Обновление — сопровождаемое изменение manifest/template/patch docs с отдельным review. Обновление установленного пакета перезаписывает локальные правки. Порядок всегда один: backup `settings.json` → установить явно выбранную exact version/source → проверить package filter → patch `--check` → apply при необходимости → runtime smoke.

Для полного удаления используйте `PI_CODING_AGENT_DIR=<profile> pi remove <тот же source>`, затем удаляйте только документированные cache/data каталоги компонента. Не удаляйте весь профиль, пока не выполнен [аудит и перенос состояния](state-migration.md).
