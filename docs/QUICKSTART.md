# QUICKSTART: поставить и проверить

Короткий маршрут для выбранного опубликованного релиза. Подробности и Windows/POSIX-варианты — [INSTALL_FOR_AGENTS](../INSTALL_FOR_AGENTS.md); версии — `manifests/`. Исторические материалы (`docs/releases/`, `docs/plans/`, `docs/lab-*`) — прошлые выпуски, не действующие правила.

## 5 команд (Windows)

```powershell
# 0. переменные (RepoRoot — checkout или распакованный ZIP релиза)
$RepoRoot = '<REPO_ROOT>'; $PiRoot = Join-Path $HOME '.pi'; $BinDir = Join-Path $HOME 'bin'; $NpmPrefix = (npm prefix -g).Trim()
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install.ps1" -Profile Both -PiRoot $PiRoot -Apply
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\install-launchers.ps1" -Profile Both -Shell Both -PiRoot $PiRoot -TargetDir $BinDir -NpmPrefix $NpmPrefix -Apply
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\verify.ps1" -Profile Both -PiRoot $PiRoot
```

Без `-Apply` первые два вызова показывают PLAN без записи. Перед запуском закройте все процессы `pi`. Полный Apply занимает 5–10+ минут.

## 4 проверки

1. `verify.ps1` — **0 failures** (WARN «credential NOT TESTED» до ввода ключа — норма).
2. `pi-code --version` и `pi-task --version` (лаунчеры на месте).
3. `/login` Polza → новая сессия → короткий ответ модели (§6 INSTALL).
4. `memory_stats`; для истории — `/session-sync` и `session_search(query="контрольный запрос", limit=3)`.

## При падении

- **Ошибка пакета при установке** — сообщение содержит полную команду с именем пакета и хвост вывода; доводите остаток флагами `-SkipPackageInstall` / `-SkipPatches` (INSTALL §3 «Возобновление»).
- **«Required JSON file not found» на кириллическом пути** — `chcp 65001` до запуска (кодировка консоли).
- **`serena-agent` не найден** — добавьте `%USERPROFILE%\.local\bin` в PATH.
- **WARN «credential NOT TESTED» / PENDING-CREDENTIALS** — ключ Polza ещё не введён; это ожидаемое состояние, не поломка.
- **Расхождение версий Node/Git/npm с пином** — рабочий диапазон шире пинов (INSTALL §2); на Windows обход — `-AllowVersionMismatch`.
- **Установка из ZIP** — сверите SHA256 ассета релиза с `.sha256` (INSTALL §1).

## Термины

- **installed-disabled / «выключен» / `pi list` показывает `(filtered)`** — одно состояние: пакет установлен, расширения не загружаются (пустой `extensions` в шаблоне; см. [composition](components/composition.md)).
- **WVM** (в контексте MCP) — локальный сервер Whisper Voice Machine, подключённый через `pi-mcp-adapter`.
- **`provider/model`** — единая форма идентификатора модели (например `polza/qwen3-27b`); в `settings.json` это два поля `defaultProvider` + `defaultModel`.
