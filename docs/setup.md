# Установка и настройка: справочник

**Основной короткий маршрут — [INSTALL_FOR_AGENTS.md](../INSTALL_FOR_AGENTS.md).** Здесь только подробности prerequisites, сохранения конфигурации и диагностики. Версии задают [runtime lock](../manifests/runtime.lock.json), [packages lock](../manifests/pi-packages.lock.json) и [external tools](../manifests/external-tools.lock.json).

Установка выбранной опубликованной ревизии, ремонт конкретного дефекта и разработка нового состава — разные задачи. Последняя использует [upgrade workflow](pi-upgrade-workflow.md); обычная установка не наследует весь lab/release процесс. [Pi 1.4.0 build.4](releases/pi-1.4.0-build.4.md) добавляет strict Session Search model mapping, отдельный semantic-only/cosine и preserving setup при прежних pins. Исторические [build.3](releases/pi-1.4.0-build.3.md), [build.2](releases/pi-1.4.0-build.2.md), [build.1](releases/pi-1.4.0-build.1.md) и [Pi 1.3.0](releases/pi-1.3.0-build.1.md) сохраняют собственные проверки и ограничения. [Ручной Pi 0.87 baseline](history/pi-0.87-install.md) отделён в историю.

## Prerequisites по платформам

| Область | Windows x64 | POSIX (macOS/Linux) |
|---|---|---|
| Shell | PowerShell 5.1+; Git Bash нужен для shell-варианта launchers | Bash 3.2+ |
| Node | Exact `runtime.node` из manifest; минимум выбранных пакетов — Node 24 | Node ≥ 24; отклонение от Windows pin — WARN verifier-а |
| npm/Git | Pinned npm, exact Git for Windows из manifests | Работоспособные npm/Git; installer при необходимости ставит pinned npm |
| Patch/schema Python | Реальный `python` ≥ 3.8 и `jsonschema` в нём | `python3`/`python` ≥ 3.8 и `jsonschema`; допустим `PI_BUILD_PYTHON` |
| Code tools | `uv` из manifest, затем installer ставит ast-grep, CBM и Serena | Тот же состав с платформенными executable paths |

В исходных manifests Node `25.8.1`, npm `11.11.0`, Git `2.54.0.windows.1`, uv `0.9.27`. Проверяйте values **выбранного commit**, не старый install log. Serena `1.7.0` использует отдельный managed Python `3.12.10` (её контракт `>=3.11,<3.15`); это не требование сменить interpreter patchers. Optional Fetch требует Python ≥ 3.10, но не нужен для удалённого Context7.

```sh
node --version
npm --version
git --version
python --version
python -c "import jsonschema"
uv --version
```

На POSIX при необходимости используйте `python3`. На Windows Store alias не считается Python. `--strict-runtime` в POSIX verifier делает несовпадение Windows pins ошибкой. Package/core/patch guards не отключаются ни на одной ОС. [Платформенные детали](platforms.md).

## Что делает installer

PLAN не устанавливает пакеты. Apply ставит pinned Pi в текущий npm global prefix, profile packages через штатный `pi install`, внешние Code tools и patches; создаёт отсутствующие configs/навык. Provider credentials не должны наследоваться package lifecycle children. Эти процессы всё равно имеют права пользователя: sanitized environment не sandbox. Installer не вводит credentials и не выполняет модельную приёмку.

Default `PiRoot` — `~/.pi`: Code=`agent`, Task=`task`. Launchers рендерятся **отдельным** installer-ом; шаблоны из `launchers/` нельзя копировать буквально. Windows default bin — `~/bin`, POSIX — `~/.local/bin`. Передайте фактические `PiRoot`, bin и npm prefix одинаково в plan/apply/verify; [готовые команды](../INSTALL_FOR_AGENTS.md#3-установить-два-профиля-и-launchers).

`-LabRoot`/`--lab-root` предназначен для разработки/приёмки нового состава на synthetic state, не является обязательным способом поставить принятую сборку. Не создавайте новые VM/runner/orchestrator ради установки.

## Сохранение существующих настроек

По умолчанию нет полного replace:

- `settings.json`: сохраняются неизвестные пользовательские поля, дополнительные пакеты и `memory.factProjectAliases`; build-owned sources/order/filters приводятся к manifests, служебная consolidation model — к template. `pi-goal-x` остаётся перед `pi-intercom`; Trace и background-tasks не активируются из-за потери фильтра.
- `models.json`: добавляется только отсутствующий `polza-memory`; другие providers сохраняются. Старый **static `polza`** конфликтует с dynamic provider: installer отказывает до package writes. Сначала backup и адресное переименование по [справке](polza-memory.md#миграция-со-старого-static-provider-polza), не удаление всего файла.
- Существующие Ollama config, memory-ops, Goal X settings и AGENTS не заменяются автоматически.
- MCP: стандартный Context7 дополняет effective adapter configuration, не отменяя shared servers/imports/settings, реальные credentials, собственный URL или явное отключение. Adapter-specific owner — `mcp-adapter.json`; [приоритеты и проверка](components/mcp.md).

`-ReplaceProfileConfigs` / `--replace-profile-configs` — **явная полная замена** конфигурационных компонентов с backup. Это не синоним reinstall и не рекомендуемый default. Прежде сохраните личные решения; не используйте replace/skip flags для обхода unknown state.

### Только синхронизировать settings

Если exact package payloads уже установлены, а sources/filters в settings устарели:

```powershell
$RepoRoot = '<REPO_ROOT>'
$PiRoot = '<PI_ROOT>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install.ps1" -Profile Both -PiRoot $PiRoot -Apply -SyncSettingsOnly
```

```bash
REPO_ROOT="<REPO_ROOT>"
PI_ROOT="<PI_ROOT>"
bash "$REPO_ROOT/scripts/install.sh" --profile Both --pi-root "$PI_ROOT" --apply --sync-settings-only
```

Этот режим не переустанавливает packages и не применяет patches. Он проверяет installed payloads и доступность настроенного consolidation route до записи обоих profiles, создаёт backup, затем меняет только settings. Secret helper из `apiKey` при static preflight не исполняется: его фактическая работоспособность — отдельная проверка. Режим не заменяет обновление пакетов, MCP default installation или functional acceptance.

## Четыре независимых model/data маршрута

1. **Основной `polza`:** штатный `/login` и динамический каталог. `.env` не обязательное условие сохранённых credentials. При пустом каталоге отличайте missing/rejected credential, сеть и неизвестную модель; не считайте служебный fallback готовностью main.
2. **Консолидация Memory:** статический `polza-memory` в каждом `models.json`, потому что child использует `--no-extensions`. Нужен отдельный разрешаемый credential: пример с `POLZA_API_KEY` либо уже проверенный приватный helper. Это не обход auth основного provider.
3. **Memory embeddings:** отдельный `memory.embedding`. Модель `qwen/qwen3-embedding-8b`, 1024d в существующем Polza-сценарии не делает все 1024d vectors совместимыми: identity модели тоже важна. Без конфигурации возможен keyword fallback; он не доказывает semantic retrieval.
4. **Session-search:** собственный config и index; default `semantic-only` требует embedder и точный `modelPrefixes` с двумя string-prefixes. FTS5 без embeddings выбирается явным `fusion: "rrf"`. Code default config — `~/.pi/session-search/config.json`, Task после patch — `<TASK_PROFILE_DIR>/session-search/config.json`. Без `project` поиск межпроектный **внутри выбранного индекса**, с `project` — суженный; другой профиль или `localPath` может выбирать иной индекс. Успешные list/read и непустой индекс не гарантируют, что широкий semantic query вернёт нужную сессию: [границы и известное ограничение](fixes/session-search.md#scope-и-качество-выдачи). Private apiKey в config не публикуется.

При обновлении Search с build.3 дополните только mapping/выбранный режим в существующем config, сохраняя ключ/модель/размерность/roots/прочие поля. Patcher не мигрирует config автоматически; отсутствующий или неполный mapping надо настроить через JSON/`/session-embeddings-setup`. [Точный preserving recipe](fixes/session-search.md#мастер-настройки-и-обновление-прежнего-конфига).

[Подробная настройка](polza-memory.md). DB памяти по умолчанию общая, настройки Code/Task профильные. Установка пакета не разрешает массовую миграцию БД, `/session-reindex` или платную переиндексацию личной истории. Адресные synthetic checks используют свои данные. Естественные startup/shutdown embedding/consolidation side effects учитывайте **до запуска** Pi; уже применимое разрешение на обычный lifecycle не нужно получать повторно.

## Проверка без подмены результата

Основные команды verifier — в [коротком входе](../INSTALL_FOR_AGENTS.md#6-короткая-приёмка-и-восстановление). Значения scopes:

- `-RepositoryOnly` / `--repository-only`: paths, JSON schemas, templates/manifests; не установленный runtime.
- `-ExternalOnly` / `--external-only`: repository gates и probes внешних tools; не model/auth/MCP handshake.
- Обычный verifier: runtime/package pins, package sources/order/filters, patches и direct-spawn executable resolution. Failure даёт nonzero; WARN не означает функциональную готовность.
- Optional command absence — не общий FAIL. Удалённый Context7 не требует локального binary. Найденные CLI не подтверждают сеть, auth, handshake или результат tools/call.
- `-SkipExternalChecks`/`--skip-external-checks` и отдельный skip patch checks уменьшают scope; такой результат нельзя выдавать за полную установку.

Для main: новая сессия, expected provider/model из настроек и явных launch arguments → actual SDK/RPC state → структурированный результат запроса. Старый выбор из resumed session не годится. `/polza-model-info` и список моделей полезны, но успешный ответ `polza-memory` не подтверждает main. Ошибка, timeout, обрыв или mismatch — не PASS.

Явный one-request check из проверяемого cwd: `node "<REPO_ROOT>/scripts/check-main-model.mjs" --sdk-root "<INSTALLED_CORE_PACKAGE>" --profile-dir "<PROFILE_DIR>"`. Для альтернативы доступны `--provider <name> --model <id> --timeout-ms 60000`; SDK root не npm prefix. Helper действительно делает запрос, использует новую in-memory сессию и exact registry membership; это не offline installer gate. Результат — JSON `expected/actual/answer/status`, при отказе `reason` и **native exit 2**. Команды для обоих профилей — в [короткой приёмке](../INSTALL_FOR_AGENTS.md#6-короткая-приёмка-и-восстановление).

Для Context7: effective config + обнаружение schemas + `resolve-library-id` → нужная версия → `query-docs` через adapter. URL/GET/server listing не заменяет functional call; внешняя auth/network/rate-limit ошибка фиксируется отдельно. Для локального текста нужен только смысл/links/Markdown, не сетевой ритуал.

Для Memory: scope чтения/записи и новая automatic consolidation проверяются различимыми synthetic фактами; `memory_remember` не доказывает новую запись от консолидации. [Memory contract](fixes/memory.md). Для нового ремонта повторяйте affected seam, не всю историческую model/ОС матрицу. Полный suite — на согласованной release boundary или при общем impact. Визуальный TUI нужен только при затронутом интерактивном поведении.

## Backups, отказ и восстановление

- Installer configs: `<PROFILE_DIR>/.pi-agent-build-backups/install/<stamp>/`.
- Patchers: `<PROFILE_DIR>/.pi-agent-build-backups/<patch>/` либо их явный state-dir.
- Launchers: `<BIN_DIR>/.pi-agent-build-backups/launchers/<stamp>/`.
- Windows staged global tools: `<PI_ROOT>/.pi-agent-build-backups/global-tools/<stamp>/`.

Эти backups не заменяют private snapshot runtime/данных. После unknown patch не запускайте reinstall поверх него: сохраните bytes и причину отказа, сопоставьте с поддержанными переходами. Прежняя поддержанная версия, текущий canonical no-op и неизвестная локальная правка — разные состояния. Наличие marker не подтверждает весь bundle. [Patches](../instructions/PATCH.maintenance.instructions.md).

После частичного сбоя операция не объявляется атомарной; сохраняется достигнутый checkpoint, продолжается только незавершённый остаток. Git revert не откатывает executable, settings, БД или credentials. Остановите writers перед restore, проверьте совместимость данных и точный backup. [Перенос и откат](state-migration.md#откат).

У uninstall используйте тот же package source; не удаляйте профиль, auth, память и sessions автоматически. Уборка owned временных артефактов — после освобождения их потребителей; recovery snapshot и нужные evidence сохраняются вне публичного Git. [Диагностика/хранение](../instructions/SEC.public_repository.instructions.md#диагностика-и-хранение).
