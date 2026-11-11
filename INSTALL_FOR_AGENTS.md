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

**Вход из ZIP релиза** (без `.git`): распакуйте ассет `pi-<версия>-build.<N>-source.zip` и сверьте его SHA256 с приложенным `.sha256` — при отсутствии `.git` это единственный способ проверить источник. Установка из распакованного каталога работает теми же командами (`<REPO_ROOT>` — распакованный каталог). Проверки коммитов/тегов в этом маршруте недоступны — доверяйте только сверенному архиву.

| Сценарий | Действие |
|---|---|
| Новая установка | Проверить prerequisites → PLAN → Apply → локальные credentials → короткая приёмка |
| Обновление принятой сборки | Остановить использующие runtime процессы, сохранить приватный recovery snapshot, проверить известное исходное состояние патчей; затем тот же preserving installer выбранной ревизии |
| Явная переустановка | Указать причину и выбранную ревизию; сохранить данные и ручные изменения. Reinstall не означает очистку профиля или разрешение перезаписать unknown patch |

Обычная установка не требует новой лаборатории, всей матрицы выпуска или повторной квалификации уже принятой версии. Замена глобального Pi затрагивает все процессы этого prefix: сначала освободите runtime. Рабочие auth/БД/сессии не являются fixtures. [Сохранение состояния](docs/state-migration.md).

## 2. Prerequisites

**Рабочий диапазон для установки** — реальные технические границы Pi и пакетов, а не точные пины:

| Инструмент | Рабочий диапазон | Основание |
|---|---|---|
| Node | **≥ 22.19** | engines ядра Pi 1.5.2 и `pi-session-search` 1.6.0 (`node >=22.19.0`); проверено на Node 24+, lab-pin `25.8.1` |
| npm | из комплекта Node | отдельного пина не требует |
| Python | реальный (не Store alias) **≥ 3.8**, с `jsonschema` в **этом же** интерпретаторе | trace renderer и patch scripts (external tools lock) |
| uv | **без жёсткого пина**, проверено на `0.9.27` | честная нижняя граница неизвестна; нужен для Serena (Code) |
| Git | **2.x** | проверено на `2.54.0.windows.1` |

**Lab-пины воспроизводимости** — Node `25.8.1`, npm `11.11.0`, Git `2.54.0.windows.1`, uv `0.9.27` из manifests — нужны для **приёмки самой сборки и её верификатора**. Расхождение с пином **не означает** нерабочую установку. Гейт сборки при этом строгий: Windows-вариант скриптов (`install.ps1`/`verify.ps1`) сверяет exact и останавливается на расхождении Node/Git/npm; POSIX-вариант (`install.sh`/`verify.sh`) сообщает drift как WARN (флаг `--strict-runtime` есть у `verify.sh` и делает его ошибкой; `install.sh` только предупреждает и Git не проверяет). Оба installer'а при расхождении npm **глобально** переустанавливают pinned npm — это изменяет ваш npm. Пины самого Pi, пакетов профилей и patches обязательны на любой ОС. Проверяйте manifests **выбранной ревизии**, не старый install log.

- **Windows x64:** PowerShell 5.1+, Git for Windows, реальный `python` с `jsonschema` (см. таблицу выше).
- **macOS/Linux:** Bash 3.2+; Helper выбирает работоспособный `python3`/`python` либо `PI_BUILD_PYTHON`.
- **Code:** нужен `uv` (проверено на `0.9.27`); installer ставит Serena с отдельным managed Python `3.12.10`. Это не версия Python для patchers. Task не требует code-intelligence CLI.
- Доступ к npm/GitHub для установки; затем к выбранному провайдеру и удалённому MCP. Права записи в выбранный пользовательский npm prefix и каталоги профилей. Не запускайте всё от администратора. Системную execution policy менять не нужно: `-ExecutionPolicy Bypass` в командах действует только на дочерний процесс.

```sh
node --version
npm --version
git --version
python --version
python -c "import jsonschema"
uv --version
```

На POSIX подставьте выбранный `python3`, если команды `python` нет. Недостающие prerequisites устанавливаются отдельно по правилам машины, не обходом verifier.

**Получение lab-пинов (точные источники):**

| Инструмент | Команда/источник |
|---|---|
| Node `25.8.1` (portable) | <https://nodejs.org/dist/v25.8.1/node-v25.8.1-win-x64.zip> |
| Git `2.54.0.windows.1` (portable) | ассет **`PortableGit-2.54.0-64-bit.7z.exe`** в <https://github.com/git-for-windows/releases/tag/v2.54.0.windows.1> (имя ассета не содержит `.windows.1`) |
| uv `0.9.27` | `powershell -c "irm https://astral.sh/uv/install.ps1 | iex"` (<https://docs.astral.sh/uv/>) |
| `jsonschema` для Python | `python -m pip install jsonschema` (в тот же интерпретатор) |

**Портативный Node без прав администратора:** `npm prefix -g` указывает внутрь каталога Node; `NPM_CONFIG_PREFIX` установщиком отбрасывается (sanitized environment) — задайте prefix через `.npmrc` внутри каталога Node. uv-шимы ставятся в `%USERPROFILE%\.local\bin` — добавьте каталог в PATH, иначе `serena-agent` не найдётся. Порядок PATH важен: если `Program Files\nodejs` идёт раньше портативного Node, `npm --version` показывает старую версию и следующая сверка падает — проверяйте `where.exe node` и `where.exe npm`.

**Кодировка консоли:** при не-ASCII пути профиля включите UTF-8 до запуска — `chcp 65001` (cmd) или `[Console]::OutputEncoding = [Text.UTF8]::UTF8` (PowerShell) — иначе возможны ложный «Required JSON file not found» и кракозябры в логах. `.ps1` с кириллицей сохраняйте **с BOM**: PS 5.1 читает без BOM как CP866 и ломает парсинг.

## 3. Установить два профиля и launchers

Installer по умолчанию показывает PLAN; только Apply выполняет package/config writes. Он использует штатный `pi install` для exact sources, не запускает модельную сессию и не вводит ключи. **Оба** этапа должны закончиться успешно. Перед запуском убедитесь, что **ни один процесс `pi` не запущен** (ни Code, ни Task): параллельный запуск даёт npm EPERM и частично распакованные пакеты, которые verify не заметит. Ожидаемая длительность полного Apply — **5–10+ минут**; не запускайте цепочку из команды с таймаутом ~120 с (типичные агентские инструменты) — так установка умирает на середине с частичным состоянием.

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

`Bypass` действует только на этот дочерний процесс. Если шаг завершился неуспешно, не продолжайте цепочку. При необходимости добавьте `$BinDir` в пользовательский PATH или вызывайте launchers полным путём. `-Shell Both` на Windows требует установленного **Git Bash** (`bash.exe` в PATH): без него POSIX-вариант лаунчеров не работает.

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

Launchers задают `PI_CODING_AGENT_DIR` процессу и выбирают Pi из указанного npm prefix. Лаунчеры **вшивают** этот prefix: после переезда Node/npm-prefix перегенерируйте их тем же `install-launchers` с новыми `-NpmPrefix`/`-TargetDir` (дефолт `-NpmPrefix` берёт текущий `npm prefix -g`). Обычный `pi` без лаунчера открывает профиль по умолчанию, не Code/Task. Не используйте глобальный `setx PI_CODING_AGENT_DIR`. Trace установлен, **выключен по умолчанию**; [разовый opt-in](docs/trace.md) не нужен для обычной приёмки.

### Возобновление после сбоя и сетевые шаги

Сбой не атомарен: продолжайте только незавершённый остаток, не начиная сначала. Флаги обоих установщиков — `-SkipPackageInstall`/`--skip-package-install`, `-SkipPatches`/`--skip-patches`, `-SyncSettingsOnly`/`--sync-settings-only`:

| Флаг | Пропускает | Когда |
|---|---|---|
| `-SkipPackageInstall` | Pi, пакеты и внешние Code tools | ядро/пакеты уже установлены (verify это показывает) |
| `-SkipPatches` | все локальные патчи | патчи применены или применяются отдельно (`apply-patches`) |
| `-SyncSettingsOnly` | всё, кроме settings | нужны только settings из шаблонов (с backup и проверкой memory-маршрута) |

Порядок доведения: verify показал недостающее → повторный Apply с нужным флагом → verify снова. Ошибка установки пакета печатает полную команду с именем пакета и последние строки вывода дочернего процесса. Вывод патчера `ALREADY PATCHED` (или `patched` для выключенного Trace) означает уже применённое состояние — это норма, не ошибка. При расхождении точных пинов на Windows обход — флаг `-AllowVersionMismatch` у `install.ps1`/`verify.ps1` (mismatch становится WARN; на POSIX дрейф и так WARN, `verify.sh --strict-runtime` делает его ошибкой).

**Сетевые шаги (зависят от канала):** postinstall `pi-cbm` качает ~40 МБ бинарник с GitHub с таймаутом 120 с; на медленном канале npm откатывает пакет. Ручной fallback: `pi install` пакета с `--ignore-scripts`, бинарник из релиза пакета и сверка его SHA-256. Пакетные патчи применяются сразу после `pi install` и не ждут внешние tools.

### Сквозной чек-лист «поставь и проверь»

1. `install.ps1 -Profile Both` (PLAN);
2. тот же вызов с `-Apply`;
3. `install-launchers.ps1 ...` (PLAN);
4. тот же вызов с `-Apply`;
5. `verify.ps1 -Profile Both`.

Затем §6: model check, memory check, Context7. Шаги 3–4 легко забыть: без них `pi-code`/`pi-task` не существуют, а verify остаётся зелёным.

## 4. Настроить независимые маршруты Polza и памяти

В новом Code и отдельно Task выполните `/login` → **Polza AI** → **Sign in with an API key**. Ключ вводит пользователь в штатный интерфейс Pi. Для **основного** `polza` дополнительный `.env` не является требованием: проверьте каталог, выберите доступную модель через `/model`, откройте `/polza-model-info`. `/polza-refresh` обновляет каталог, но не превращает пустой cold start в успешную приёмку.

| Маршрут | Где настраивается | Что доказывать отдельно |
|---|---|---|
| Основной агент `polza/<model-id>` | Нативный login + модель профиля/явные параметры запуска | Каталог и ожидаемые **provider/model**, не случайный fallback |
| Консолидация `polza-memory/deepseek/deepseek-v4.1-flash` | `<PROFILE_DIR>/models.json` + `memory.consolidationModel` | Служебный child без extensions; отдельный доступный credential |
| Embeddings Memory | `memory.embedding` в приватных settings | Модель и размерность векторов; это не модель консолидации |
| Поиск истории | Собственный session-search config/index | Default `semantic-only` требует embedder + точный `modelPrefixes`; FTS без embeddings — только явный `rrf`. Внешний endpoint получает текст |

Installer добавляет отсутствующий статический `polza-memory`, но **не обеспечивает ему секрет**. Повторный Apply **сохраняет** существующий `models.json`/`polza-memory` (`preserved`) и не применяет к нему изменения манифеста — правьте вручную. Login для `polza` сам по себе не настраивает этот route. Пример служебного provider использует `POLZA_API_KEY`; допустим существующий проверенный secret helper. Memory embeddings и session-search настраиваются отдельно по [справке](docs/polza-memory.md). Не меняйте модель/размерность и не запускайте массовые backfill/reindex ради проверки установки. Общая Memory DB по умолчанию не означает общие настройки профилей.

**Переход с build.3:** patcher обновляет package, а installer сохраняет существующий session-search config. Перед приёмкой дополните его обязательным `embedder.modelPrefixes[точный model]` с обеими string-prefixes и выберите `fusion: "semantic-only"`, если нужен только cosine. Не заменяйте свой файл публичным примером и не меняйте ключ/модель/размерность/roots попутно. Для прежнего Qwen documentPrefix остаётся `""`, forced reindex не нужен. Code/Task имеют отдельные config/index; отсутствующий конфиг надо настроить, а не считать готовым по наличию пакета. [Точный preserving recipe и настройки](docs/fixes/session-search.md#мастер-настройки-и-обновление-прежнего-конфига).

## 5. Context7 по умолчанию

Стандартный default для Code/Task — удалённый `https://mcp.context7.com/mcp`, **Streamable HTTP**, `lifecycle: "lazy"`, через единственного владельца `pi-mcp-adapter@5.3.2`. Adapter-specific файл — `<PROFILE_DIR>/mcp-adapter.json`, не Pi-native `mcp.json`. В безключевом default поля `headers` **нет**. Локальный `npx`/`context7-mcp` и exclusive mode не нужны. Безключевой доступ ограничен сервисом.

При обновлении сохраняются shared servers/imports/settings, пользовательский URL/auth и явное отключение Context7; они не отменяются default-ом. Проверяйте **effective config** адаптера, а не только новый файл. Подробнее: [MCP и необязательный HTTP auth](docs/components/mcp.md).

Когда нужна актуальная внешняя документация: обнаружьте `resolve-library-id`, выберите библиотеку и нужную версию, затем `query-docs` для конкретного вопроса; имена и аргументы берите из tool schema. Результат примените к проверяемому решению. При отказе используйте официальный первичный источник с указанием версии и способа получения. Для локальной опечатки сеть не нужна.

## 6. Короткая приёмка и восстановление

**Слои приёмки:** `install-integrity` (failures в verify: версии, manifests, пакеты, патчи) → `config-readiness` (WARN/exit-3: credential и прочая «ещё не настроенная» готовность) → `live` (пункты 2–5 ниже: сеть и платные вызовы). **Ожидаемое состояние до ввода Polza-ключа:** memory-credential проверки дают WARN «credential NOT TESTED» (exit 3) — это норма свежей установки (PENDING-CREDENTIALS), не дефект; дефект — нарушенный контракт конфига/версий.

1. Verifier обоих профилей: версии, filters, patches, доступные CLI. Это **не** модельный запрос или live MCP proof.
2. `pi-code --version` и `pi-task --version`, затем `list` и `--list-models` у каждого launcher. Сверьте профиль, ядро и основной `polza` отдельно от `polza-memory`. Учтите: `--list-models` тянет каталог Polza **по сети** и может уйти в таймаут (офлайн-альтернативы нет), а непустой список **не доказывает** валидный ключ — каталог доступен и без него.
3. Для функциональной приёмки создайте **новую** сессию. Сопоставьте ожидаемые provider/model с фактическим SDK/RPC state и структурированным результатом короткого разрешённого запроса. Не спрашивайте модель о её имени. Mismatch, timeout, ошибка/обрыв — не PASS. Явная пользовательская альтернатива меняет ожидание.
4. Context7 — живой вызов MCP (сеть). Конфигурационная часть (офлайн: файл adapter, discovery-настройки) — в [mcp](docs/components/mcp.md); «config PASS» **не равен** «сеть доступна»: discovery → `resolve-library-id` → `query-docs` через MCP сборки. URL, произвольный GET или список серверов не доказывают вызов. Сетевой отказ/rate limit фиксируйте отдельно от конфигурации; не удаляйте default из-за внешнего отказа.
5. Память: `memory_stats` и адресный synthetic сценарий для затронутой операции. Работа консолидации не доказывает основной `polza`; факт от `memory_remember` не доказывает автоматическую консолидацию. Не повторяйте всю release-матрицу при обычной установке.

Model/embedding/consolidation вызовы могут быть платными и передавать данные. Делайте только короткую проверку в разрешённом scope. CLI listing тоже может обращаться за каталогом.

Для пункта 3 есть настоящий one-request helper. Запускайте **из проверяемого проекта**: cwd участвует в effective settings. `SDK_ROOT` — каталог самого установленного `@earendil-works/pi-coding-agent`, не npm prefix. Helper создаёт новую in-memory сессию; это **не offline check** и не автоматический этап installer:

```sh
node scripts/check-main-model.mjs --sdk-root "<SDK_ROOT>" --profile-dir "<PI_ROOT>/agent"
node scripts/check-main-model.mjs --sdk-root "<SDK_ROOT>" --profile-dir "<PI_ROOT>/task"
# Явно выбранная доступная основная модель:
node scripts/check-main-model.mjs --sdk-root "<SDK_ROOT>" --profile-dir "<PROFILE_DIR>" --provider polza --model "<MODEL_ID>" --timeout-ms 60000
```

Если cwd вне checkout, используйте абсолютный путь к `scripts/check-main-model.mjs`. Default timeout — 60000 ms. JSON содержит `expected`, `actual`, `answer` (включая текст ответа), `status`, при отказе `reason` и `detail`; любой отказ даёт **exit 2**, успех — 0 (молчаливый пропуск невозможен — self-run guard нормализует пути). Сверка канарейки терпима к регистру, лишним пробелам и хвостовым знакам препинания, но лишние слова по-прежнему не принимаются. Точное присутствие модели в registry обязательно: custom-model fallback Pi не засчитывается. Служебный `polza-memory` не подтверждает main.

Конфигурационные backups находятся в `<PROFILE_DIR>/.pi-agent-build-backups/install/<stamp>/`, patch backups — в профильном `.pi-agent-build-backups/<patch>/`, launcher backups — в `<BIN_DIR>/.pi-agent-build-backups/launchers/<stamp>/`. Это **не полный backup runtime и данных**. При unknown patch остановитесь и сохраните его; не удаляйте marker/backup и не обходите guard. При частичном отказе продолжайте только установленный незавершённый остаток после диагностики; операция не объявляется атомарной. [Restore и данные](docs/state-migration.md#откат), [правила patches](instructions/PATCH.maintenance.instructions.md).

Итог установщика: SHA сборки и pin Polza; ОС и фактические версии; paths Code/Task/launchers; что сохранено; результаты verifier, модели, памяти и Context7 **с областью static/runtime/live**; конкретный NOT RUN/внешний блокер и нужен ли полный перезапуск. Не записывайте ключи, prompts, ответы или содержимое памяти в отчёт.
