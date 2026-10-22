# Историческая ручная установка Pi 0.87

Это **историческая справка**, не текущий install/update-рецепт. Ниже сохранены команды прежнего baseline вместе с их исходными версиями. Они не подтверждают работоспособность нового ядра и не должны выполняться поверх принятого состава.

Текущий вход: [INSTALL_FOR_AGENTS](../../INSTALL_FOR_AGENTS.md); конфигурация: [setup](../setup.md). Полный прежний документ сохранён в Git: commit `c90b3284800e35055dc115496548c0d72fd0b726`, файл `docs/setup.md` (команда `git show c90b3284800e35055dc115496548c0d72fd0b726:docs/setup.md`).

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

Функция ниже устанавливает 12 общих пакетов в выбранный профиль. Источники и версии в этом историческом блоке соответствуют прежнему baseline, не текущему manifest; не выполнять его как установку Pi1.3.0 build.1.

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
  PI_CODING_AGENT_DIR="$profile" pi install npm:@samfp/pi-memory@1.6.0
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

Fetch `2025.4.7` требует Python `>=3.10`. Пример [`mcp.example.json`](../../config/mcp.example.json) использует Context7 по remote URL, поэтому локальный `context7-mcp` нужен только если вы осознанно замените URL на command. Установка server binary не добавляет его в config автоматически и не подтверждает API/network access.


## Что из этой истории остаётся полезным

- Пакеты ставятся штатным `pi install`, а фильтры активации проверяются после package/config writes.
- `PI_CODING_AGENT_DIR` задаётся процессу, не глобальным `setx`; cwd и личные ancestor resources не изолируются одним профилем.
- На Windows `spawn(shell:false)` может требовать реальный `.exe`, а не npm shim. Текущий staging выполняет installer.
- Remote Context7 не требует локального npm server. Секция optional tools выше относится к прежнему manifest и не является обязательным default.
- Не копируйте все настройки поверх существующего профиля: актуальный preserving merge, backups и guards описаны в текущем setup.
