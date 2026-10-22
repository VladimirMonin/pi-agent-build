# Установка опубликованной сборки: короткий вход

Этот маршрут устанавливает **выбранную опубликованную ревизию**, а не `latest` и не локальный незавершённый ремонт. Версии берутся из [runtime lock](manifests/runtime.lock.json) и [packages lock](manifests/pi-packages.lock.json); область приёмки — из release notes этой ревизии. [Настройка и специальные случаи](docs/setup.md). Для исправления дефекта и разработки выпуска есть [отдельный маршрут](docs/pi-upgrade-workflow.md).

## 1. Проверить источник и выбрать сценарий

Сначала используйте существующий checkout. Для него выполните из корня:

```sh
git remote -v
git status --short
git fetch origin
git log -1 --format='%H %s' HEAD
git log -1 --format='%H %s' origin/main
```

Remote должен указывать на `https://github.com/VladimirMonin/pi-agent-build` (допустим `.git`). Зафиксируйте **устанавливаемый SHA**, сравните его с выбранным опубликованным выпуском и manifests. Fetch не обновляет файлы checkout. При расхождении не устанавливайте устаревшую копию и не стирайте чужую работу через reset/clean. Если checkout ещё нет:

```sh
git clone https://github.com/VladimirMonin/pi-agent-build.git "<REPO_ROOT>"
```

Если выбран опубликованный commit на `main`, чистый checkout обновляется через `git pull --ff-only`, затем SHA проверяется повторно. Для выбранного release tag используйте отдельный каталог: `git clone --branch "<PUBLISHED_TAG>" https://github.com/VladimirMonin/pi-agent-build.git "<REPO_ROOT>"`. Не переключайте dirty/shared checkout ради установки; сначала сохраните свою работу или выберите новый путь.

| Сценарий | Действие |
|---|---|
| Новая установка | Проверить prerequisites → PLAN → Apply → локальные credentials → короткая приёмка |
| Обновление принятой сборки | Остановить использующие runtime процессы, сохранить приватный recovery snapshot, проверить известное исходное состояние патчей; затем тот же preserving installer выбранной ревизии |
| Явная переустановка | Указать причину и выбранную ревизию; сохранить данные и ручные изменения. Reinstall не означает очистку профиля или разрешение перезаписать unknown patch |

Обычная установка не требует новой лаборатории, всей матрицы выпуска или повторной квалификации уже принятой версии. Замена глобального Pi затрагивает все процессы этого prefix: сначала освободите runtime. Рабочие auth/БД/сессии не являются fixtures. [Сохранение состояния](docs/state-migration.md).

## 2. Prerequisites

- **Windows x64:** PowerShell 5.1+, Git for Windows, Node и npm по manifests. В исходном runtime lock закреплены Node `25.8.1`, npm `11.11.0`, Git `2.54.0.windows.1`; перед установкой сверяйте выбранную ревизию. Windows installer проверяет exact Node/Git, при необходимости устанавливает pinned npm. Нужен реальный `python` ≥ 3.8, не Store alias, с `jsonschema` в **этом же** интерпретаторе.
- **macOS/Linux:** Bash 3.2+, Git, Node ≥ 24, npm, Python ≥ 3.8 с `jsonschema`. Helper выбирает работоспособный `python3`/`python` либо `PI_BUILD_PYTHON`. Windows runtime pins на POSIX verifier обычно сообщает как WARN (`--strict-runtime` делает их ошибкой); pinned Pi/пакеты/patches остаются обязательными.
- **Code:** нужен `uv` из external-tools manifest (исходный pin `0.9.27`); installer ставит Serena с отдельным managed Python `3.12.10`. Это не версия Python для patchers. Task не требует code-intelligence CLI.
- Доступ к npm/GitHub для установки; затем к выбранному провайдеру и удалённому MCP. Права записи в выбранный пользовательский npm prefix и каталоги профилей. Не запускайте всё от администратора и не меняйте системную execution policy ради установки.

```sh
node --version
npm --version
git --version
python --version
python -c "import jsonschema"
uv --version
```

На POSIX подставьте выбранный `python3`, если команды `python` нет. Недостающие prerequisites устанавливаются отдельно по правилам машины, не обходом verifier.

## 3. Установить два профиля и launchers

Installer по умолчанию показывает PLAN; только Apply выполняет package/config writes. Он использует штатный `pi install` для exact sources, не запускает модельную сессию и не вводит ключи. **Оба** этапа должны закончиться успешно.

### Windows — PowerShell

```powershell
$RepoRoot = '<REPO_ROOT>'
$PiRoot = Join-Path $HOME '.pi'
$BinDir = Join-Path $HOME 'bin'
$NpmPrefix = (npm prefix -g).Trim()
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install.ps1" -Profile Both -PiRoot $PiRoot
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install.ps1" -Profile Both -PiRoot $PiRoot -Apply
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install-launchers.ps1" -Profile Both -Shell Both -PiRoot $PiRoot -TargetDir $BinDir -NpmPrefix $NpmPrefix
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install-launchers.ps1" -Profile Both -Shell Both -PiRoot $PiRoot -TargetDir $BinDir -NpmPrefix $NpmPrefix -Apply
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\verify.ps1" -Profile Both -PiRoot $PiRoot
```

`Bypass` действует только на этот дочерний процесс. Если шаг завершился неуспешно, не продолжайте цепочку. При необходимости добавьте `$BinDir` в пользовательский PATH или вызывайте launchers полным путём.

### macOS/Linux — Bash

```bash
REPO_ROOT="<REPO_ROOT>"
PI_ROOT="$HOME/.pi"
BIN_DIR="$HOME/.local/bin"
NPM_PREFIX="$(npm prefix -g)"
bash "$REPO_ROOT/scripts/install.sh" --profile Both --pi-root "$PI_ROOT"
bash "$REPO_ROOT/scripts/install.sh" --profile Both --pi-root "$PI_ROOT" --apply
bash "$REPO_ROOT/scripts/install-launchers.sh" --profile Both --pi-root "$PI_ROOT" --target-dir "$BIN_DIR" --npm-prefix "$NPM_PREFIX"
bash "$REPO_ROOT/scripts/install-launchers.sh" --profile Both --pi-root "$PI_ROOT" --target-dir "$BIN_DIR" --npm-prefix "$NPM_PREFIX" --apply
bash "$REPO_ROOT/scripts/verify.sh" --profile Both --pi-root "$PI_ROOT"
```

Добавьте `BIN_DIR` в PATH текущей shell либо используйте полный путь. Своё расположение передавайте **одинаково** installer, launcher installer и verifier; дополнительных симлинков для теста не нужно.

| Профиль | Default directory | Запуск |
|---|---|---|
| Code | `~/.pi/agent` | `pi-code` (Windows: `pi-code.cmd`) |
| Task | `~/.pi/task` | `pi-task` (Windows: `pi-task.cmd`) |

Launchers задают `PI_CODING_AGENT_DIR` процессу и выбирают Pi из указанного npm prefix. Не используйте глобальный `setx PI_CODING_AGENT_DIR`. Обычный `pi` остаётся стандартным профилем. Trace установлен, **выключен по умолчанию**; [разовый opt-in](docs/trace.md) не нужен для обычной приёмки.

## 4. Настроить независимые маршруты Polza и памяти

В новом Code и отдельно Task выполните `/login` → **Polza AI** → **Sign in with an API key**. Ключ вводит пользователь в штатный интерфейс Pi. Для **основного** `polza` дополнительный `.env` не является требованием: проверьте каталог, выберите доступную модель через `/model`, откройте `/polza-model-info`. `/polza-refresh` обновляет каталог, но не превращает пустой cold start в успешную приёмку.

| Маршрут | Где настраивается | Что доказывать отдельно |
|---|---|---|
| Основной агент `polza/<model-id>` | Нативный login + модель профиля/явные параметры запуска | Каталог и ожидаемые **provider/model**, не случайный fallback |
| Консолидация `polza-memory/deepseek/deepseek-v4.1-flash` | `<PROFILE_DIR>/models.json` + `memory.consolidationModel` | Служебный child без extensions; отдельный доступный credential |
| Embeddings Memory | `memory.embedding` в приватных settings | Модель и размерность векторов; это не модель консолидации |
| Поиск истории | Собственный session-search config/index | FTS работает без embeddings; semantic mode отдельно передаёт текст внешнему endpoint |

Installer добавляет отсутствующий статический `polza-memory`, но **не обеспечивает ему секрет**. Login для `polza` сам по себе не настраивает этот route. Пример служебного provider использует `POLZA_API_KEY`; допустим существующий проверенный secret helper. Memory embeddings и session-search настраиваются отдельно по [справке](docs/polza-memory.md). Не меняйте модель/размерность и не запускайте массовые backfill/reindex ради проверки установки. Общая Memory DB по умолчанию не означает общие настройки профилей.

## 5. Context7 по умолчанию

Стандартный default для Code/Task — удалённый `https://mcp.context7.com/mcp`, **Streamable HTTP**, `lifecycle: "lazy"`, через единственного владельца `pi-mcp-adapter@5.3.2`. Adapter-specific файл — `<PROFILE_DIR>/mcp-adapter.json`, не Pi-native `mcp.json`. В безключевом default поля `headers` **нет**. Локальный `npx`/`context7-mcp` и exclusive mode не нужны. Безключевой доступ ограничен сервисом.

При обновлении сохраняются shared servers/imports/settings, пользовательский URL/auth и явное отключение Context7; они не отменяются default-ом. Проверяйте **effective config** адаптера, а не только новый файл. Подробнее: [MCP и необязательный HTTP auth](docs/components/mcp.md).

Когда нужна актуальная внешняя документация: обнаружьте `resolve-library-id`, выберите библиотеку и нужную версию, затем `query-docs` для конкретного вопроса; имена и аргументы берите из tool schema. Результат примените к проверяемому решению. При отказе используйте официальный первичный источник с указанием версии и способа получения. Для локальной опечатки сеть не нужна.

## 6. Короткая приёмка и восстановление

1. Verifier обоих профилей: версии, filters, patches, доступные CLI. Это **не** модельный запрос или live MCP proof.
2. `pi-code --version` и `pi-task --version`, затем `list` и `--list-models` у каждого launcher. Сверьте профиль, ядро и основной `polza` отдельно от `polza-memory`.
3. Для функциональной приёмки создайте **новую** сессию. Сопоставьте ожидаемые provider/model с фактическим SDK/RPC state и структурированным результатом короткого разрешённого запроса. Не спрашивайте модель о её имени. Mismatch, timeout, ошибка/обрыв — не PASS. Явная пользовательская альтернатива меняет ожидание.
4. Context7: discovery → `resolve-library-id` → `query-docs` через MCP сборки. URL, произвольный GET или список серверов не доказывают вызов. Сеть/auth/rate limit фиксируйте отдельно; не удаляйте default из-за внешнего отказа.
5. Память: `memory_stats` и адресный synthetic сценарий для затронутой операции. Работа консолидации не доказывает основной `polza`; факт от `memory_remember` не доказывает автоматическую консолидацию. Не повторяйте всю release-матрицу при обычной установке.

Model/embedding/consolidation вызовы могут быть платными и передавать данные. Делайте только короткую проверку в разрешённом scope. CLI listing тоже может обращаться за каталогом.

Для пункта 3 есть настоящий one-request helper. Запускайте **из проверяемого проекта**: cwd участвует в effective settings. `SDK_ROOT` — каталог самого установленного `@earendil-works/pi-coding-agent`, не npm prefix. Helper создаёт новую in-memory сессию; это **не offline check** и не автоматический этап installer:

```sh
node scripts/check-main-model.mjs --sdk-root "<SDK_ROOT>" --profile-dir "<PI_ROOT>/agent"
node scripts/check-main-model.mjs --sdk-root "<SDK_ROOT>" --profile-dir "<PI_ROOT>/task"
# Явно выбранная доступная основная модель:
node scripts/check-main-model.mjs --sdk-root "<SDK_ROOT>" --profile-dir "<PROFILE_DIR>" --provider polza --model "<MODEL_ID>" --timeout-ms 60000
```

Если cwd вне checkout, используйте абсолютный путь к `scripts/check-main-model.mjs`. Default timeout — 60000 ms. JSON содержит `expected`, `actual`, `answer`, `status`, при отказе `reason`; любой отказ даёт **exit 2**, успех — 0. Точное присутствие модели в registry обязательно: custom-model fallback Pi не засчитывается. Служебный `polza-memory` не подтверждает main.

Конфигурационные backups находятся в `<PROFILE_DIR>/.pi-agent-build-backups/install/<stamp>/`, patch backups — в профильном `.pi-agent-build-backups/<patch>/`, launcher backups — в `<BIN_DIR>/.pi-agent-build-backups/launchers/<stamp>/`. Это **не полный backup runtime и данных**. При unknown patch остановитесь и сохраните его; не удаляйте marker/backup и не обходите guard. При частичном отказе продолжайте только установленный незавершённый остаток после диагностики; операция не объявляется атомарной. [Restore и данные](docs/state-migration.md#откат), [правила patches](instructions/PATCH.maintenance.instructions.md).

Итог установщика: SHA сборки и pin Polza; ОС и фактические версии; paths Code/Task/launchers; что сохранено; результаты verifier, модели, памяти и Context7 **с областью static/runtime/live**; конкретный NOT RUN/внешний блокер и нужен ли полный перезапуск. Не записывайте ключи, prompts, ответы или содержимое памяти в отчёт.
