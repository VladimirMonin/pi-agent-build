# Code intelligence (только профиль Code)

## `@nicknisi/pi-ast-grep` 0.2.1

### Назначение

Структурный AST search и preview-first rewrite через внешний `ast-grep` CLI. Это syntax-aware, но не type-aware инструмент.

### Установка

```bash
npm install -g @ast-grep/cli@0.45.3
PI_CODING_AGENT_DIR="<CODE_PROFILE_DIR>" \
  pi install npm:@nicknisi/pi-ast-grep@0.2.1
```

На Windows нужен [real executable fix](../fixes/ast-grep-windows.md).

### Конфигурация и данные

Package собственного config/data не создаёт; применяются ignore/config rules ast-grep проекта. CLI должен разрешаться как `ast-grep.exe`/`ast-grep` при `spawn(shell:false)`.

### Команды, tools и skills

- `ast_search(pattern, lang?, path?, timeout?)`;
- `ast_rewrite(pattern, replacement, path, lang?, dryRun=true, timeout?)`;
- slash commands/skills нет.

### Риски

`ast_rewrite` с `dryRun:false` меняет все matches одного файла без undo; timeout/cancel не гарантирует rollback. AST не понимает types/import resolution. Результаты ограничены по строкам/байтам — сужайте pattern/path, не повторяйте уже применённый rewrite для восстановления output.

### Проверка

`ast-grep.exe --version`, затем безопасный `ast_search` и `ast_rewrite` без `dryRun:false`. После apply проверяйте Git diff и project tests.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<CODE_PROFILE_DIR>" \
  pi remove npm:@nicknisi/pi-ast-grep
npm uninstall -g @ast-grep/cli
```

Удалите staged `ast-grep.exe` только если его не использует другой software.

## `@bacnh85/pi-serena` 0.9.20 + `serena-agent` 1.7.0

### Назначение

Pi wrapper регистрирует semantic symbol/refactoring tools, а persistent TypeScript worker вызывает Python Serena bridge и LSP/JetBrains backend.

### Установка

```bash
uv tool install --prerelease=allow "serena-agent==1.7.0"
PI_CODING_AGENT_DIR="<CODE_PROFILE_DIR>" \
  pi install npm:@bacnh85/pi-serena@0.9.20
python patches/serena-tools/apply.py --agent-dir "<CODE_PROFILE_DIR>" --apply
```

### Конфигурация и данные

Project Serena config/cache — `.serena/`; в 1.7.0 актуален `language_servers:`. `SERENA_LANGUAGE_BACKEND=LSP|JetBrains` выбирается до запуска worker. `SERENA_EAGER_STARTUP=1`, dashboard variables и `.env.local/.env` меняют lifecycle; перезапуск `/serena-restart` обязателен.

### Команды, tools и skills

Команды `/serena-dashboard [project]`, `/serena-restart`. После patch доступно 18 `serena_*` tools: status/list, symbols overview/find/references/declaration, symbol/content edits, rename/safe-delete, pattern search, diagnostics, restarts, config и onboarding. `serena_find_implementations` и `serena_check_onboarding_performed` скрыты; guidance не рекомендует отсутствующий implementation tool. Skills package не поставляет.

### Риски

Wrapper и Serena меняют API независимо. Semantic edits пишут файлы; сначала references/diagnostics, затем diff/tests. System prompt surcharge присутствует при active tools. Pyright не поддерживает `textDocument/implementation`; не выдавайте отсутствие результата за отсутствие implementation. `find_symbol("*")` — неверный name path, а не «все symbols».

### Проверка

`serena --version`, patch `--check`, `serena_status`, `serena_get_symbols_overview` на source file и `serena_find_symbol` с реальным name path. Проверяйте `.serena/memories/` вместо удалённого checker tool.

### Удаление/откат

```bash
python patches/serena-tools/apply.py --agent-dir "<CODE_PROFILE_DIR>" --restore
PI_CODING_AGENT_DIR="<CODE_PROFILE_DIR>" \
  pi remove npm:@bacnh85/pi-serena
uv tool uninstall serena-agent
```

Project `.serena/` удаляйте отдельно. Полный fix: [Serena](../fixes/serena.md).

## `pi-cbm` 1.2.1 + `codebase-memory-mcp` 0.11.0

### Назначение

Регистрирует локальный code graph как native Pi tools, auto-indexes current git root и даёт architecture/search/symbol/read/trace/impact queries.

### Установка

```bash
npm install -g codebase-memory-mcp@0.11.0
PI_CODING_AGENT_DIR="<CODE_PROFILE_DIR>" pi install npm:pi-cbm@1.2.1
python patches/pi-cbm-011/apply.py --agent-dir "<CODE_PROFILE_DIR>" --apply
```

Launcher задаёт `CODEBASE_MEMORY_MCP_BIN` на реальный `.exe`, `PI_CBM_MAX_CONCURRENT_INDEXES=1` и refresh interval.

### Конфигурация и данные

Индексы — `~/.cache/codebase-memory-mcp/<project>.db` (SQLite WAL). Project inferred по cwd. Non-git indexing выключен, включается явно `/cbm enable-non-git`. Env: `PI_CBM_MAX_CONCURRENT_INDEXES`, `PI_CBM_AUTO_REFRESH_INTERVAL_MS`, optional `PI_CBM_CACHE_DIR`.

### Команды, tools и skills

`/cbm menu|status|enable-non-git|disable-non-git`; 13 tools: `get_graph_schema`, `get_architecture`, `search_graph`, `resolve_symbol`, `read_symbol(s)`, `search_code`, `get_code_snippet(s)`, `search_and_read_symbols`, `trace_path`, `query_graph`, `detect_changes`. Skills нет.

### Риски

Index содержит source-derived graph. Binary около сотен MB и каждый CLI call имеет startup overhead. 13 schemas заметно увеличивают context, поэтому пакет только в Code. Несовместимость 0.11 schema без patch даёт опасные silent empty results. Автоиндексация нагружает disk/CPU; root/home/system paths guard не заменяет проверку cwd.

### Проверка

`codebase-memory-mcp.exe --version`, patch `--check`, `/cbm status`, затем `search_graph` по существующему symbol и `read_symbol`; тест должен подтверждать ненулевой результат, не только valid JSON. `detect_changes` проверяйте на известном Git diff.

### Удаление/откат

```bash
python patches/pi-cbm-011/apply.py --agent-dir "<CODE_PROFILE_DIR>" --restore
PI_CODING_AGENT_DIR="<CODE_PROFILE_DIR>" pi remove npm:pi-cbm
npm uninstall -g codebase-memory-mcp
```

Index DB удаляется отдельно после backup/остановки процессов. Полный fix: [CBM](../fixes/cbm.md).
