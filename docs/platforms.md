# Платформы: Windows x64 и POSIX (macOS/Linux)

Сборка описывает один и тот же состав Pi Agent для двух семейств платформ. Различаются только способ запуска скриптов, пути npm-префикса и несколько Windows-специфичных исправлений.

## Матрица поддержки

| Область | Windows x64 | macOS / Linux (POSIX) |
|---|---|---|
| Скрипты | `scripts/*.ps1` (Windows PowerShell 5.1+) | `scripts/*.sh` (bash 3.2+, `python3`) |
| Лаунчеры | `launchers/pi-code.cmd`, `pi-task.cmd` | `launchers/pi-code`, `pi-task` |
| npm global prefix | `%APPDATA%\npm` | `$(npm prefix -g)` (обычно `/usr/local` или `/opt/homebrew`) |
| CLI внутри prefix | `<prefix>\pi.cmd` | `<prefix>/bin/pi` |
| ast-grep | нужен staging реального `.exe` рядом с shim | не нужен: npm shim прямо исполняем |
| memory spawn fix | обязателен (`pi.cmd` + `spawn(shell:false)` → ENOENT) | ветка `win32` не срабатывает, работает `pi` из PATH |
| Trace patch | русификация + Windows UTF-8 | русификация; Windows-ветки не активны |
| CBM executable | `<prefix>\node_modules\codebase-memory-mcp\bin\codebase-memory-mcp.exe` | `<prefix>/bin/codebase-memory-mcp` (node-скрипт) |
| Serena | `uv tool install serena-agent==1.7.0` | то же |
| Node/npm/Git pinned versions | exact из manifest | manifest закрепляет Windows-версии; на POSIX проверяются как WARN |

## Что переносится без изменений

- `manifests/*.lock.json` — единый источник версий;
- `profiles/*/settings.template.json` — одинаковые для обеих платформ;
- `config/*.example.json` — одинаковые;
- `patches/*/apply.py` — Python, платформо-нейтральны (Windows-ветки внутри JS-патчей не активны на POSIX);
- `skills/` — навыки Pi не зависят от платформы.

## Что отличается

### Скрипты

POSIX-набор повторяет PowerShell-набор по контракту:

| PowerShell | POSIX | Назначение |
|---|---|---|
| `common.ps1` | `common.sh` | общие helpers (JSON, profiles, backups, версии) |
| `install.ps1` | `install.sh` | plan/apply установки |
| `apply-patches.ps1` | `apply-patches.sh` | оркестрация patchers |
| `install-launchers.ps1` | `install-launchers.sh` | рендер и установка лаунчеров |
| `verify.ps1` | `verify.sh` | проверка репозитория и профилей |
| `safety-check.ps1` | `safety-check.sh` | публичный safety scan |

Оба набора читают одни manifests и вызывают одни patchers, поэтому состояние установки совместимо между платформами.

### Runtime-версии

`manifests/runtime.lock.json` закрепляет Windows-версии Node `25.8.1`, npm `11.11.0` и Git `2.54.0.windows.1`. На macOS/Linux эти точные версии обычно недоступны, поэтому `verify.sh` сообщает о расхождении как **WARN**, а не FAIL. Жёсткие требования остаются:

- Node `>= 24.0.0` (требование `pi-session-search 1.4.3`);
- Python `>= 3.8` для patchers и Trace renderer;
- Python-пакет `jsonschema` для schema validation в `verify.sh`.

Флаг `--strict-runtime` превращает расхождение runtime-версий в FAIL для тех, кто воспроизводит именно Windows-пин.

### npm prefix

Windows-лаунчеры вызывают `<prefix>\pi.cmd`. POSIX-лаунчеры определяют layout автоматически: сначала пробуют `<prefix>/bin/pi`, затем `<prefix>/pi`. Это покрывает и Homebrew (`/opt/homebrew/bin/pi`), и пользовательские префиксы.

## POSIX-установка

Полная процедура — в [setup.md](setup.md#posix-macoslinux). Кратко:

```bash
# prerequisites
node --version    # >= 24
npm --version
git --version
python3 --version # >= 3.8
uv --version
python3 -c "import jsonschema; print(jsonschema.__version__)"

# plan, затем apply
scripts/install.sh --profile Both
scripts/install.sh --profile Both --apply
scripts/install-launchers.sh --profile Both
scripts/install-launchers.sh --profile Both --apply

# проверка
scripts/verify.sh --profile Both
scripts/safety-check.sh --scope Both
bash tests/scripts/goal-order-posix.sh  # синтетическая проверка порядка goal-x/intercom
```

Проверка синтаксиса Bash и синтетический тест verifier'а возможны и в Git Bash на Windows, но **не заменяют запуск установки и Pi на macOS**. Перед объявлением macOS-совместимости повторите plan/apply/verify и headless-создание тестовой цели на реальном Mac.

## Известные ограничения POSIX

- `patches/ast-grep-windows/` — Windows-only staging реального `.exe`; на POSIX не применяется и не нужен.
- `memory-windows-runtime` на POSIX применяется ради **profile-aware settings** и ordered turns; Windows-ветка spawn не активна, но patch остаётся обязательным для независимых memory settings Task.
- Точные Windows-версии Node/npm/Git не воспроизводятся; воспроизводится состав Pi-пакетов и состояние patches.
- `CODEBASE_MEMORY_MCP_BIN` на POSIX указывает на node-скрипт (`<prefix>/bin/codebase-memory-mcp`), а не на `.exe`.
