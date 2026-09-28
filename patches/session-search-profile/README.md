# pi-session-search 1.4.3: изоляция именованного профиля

Поддерживаемая версия: `pi-session-search@1.4.3`.

Stock-пакет жёстко использует стандартные пути `~/.pi/agent/sessions` и `~/.pi/session-search`. Из-за этого именованный Task-профиль через `PI_CODING_AGENT_DIR` читает и индексирует историю Code-профиля.

Patch изменяет `src/config.ts`, `src/parser.ts` и собранный `dist/index.js`:

```text
<PI_CODING_AGENT_DIR>/sessions
<PI_CODING_AGENT_DIR>/sessions-archive
<PI_CODING_AGENT_DIR>/session-search/config.json
<PI_CODING_AGENT_DIR>/session-search/index/
```

Явные `PI_SESSION_DIR` и `PI_SESSION_ARCHIVE_DIR` сохраняют приоритет.

## Использование

Основной стандартный профиль patch не требует. Для Task:

```powershell
python .\patches\session-search-profile\apply.py `
  --agent-dir "$HOME\.pi\task" --check
python .\patches\session-search-profile\apply.py `
  --agent-dir "$HOME\.pi\task" --apply
```

Откат:

```powershell
python .\patches\session-search-profile\apply.py `
  --agent-dir "$HOME\.pi\task" --restore
```

После применения размести конфигурацию embeddings именно в:

```text
~/.pi/task/session-search/config.json
```

и выполни `/session-reindex` внутри `pi-task`.

Patcher жёстко проверяет версию и частичное состояние; неизвестная или смешанная структура завершается ошибкой.
