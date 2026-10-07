# История сессий и долговременная память

## `pi-session-search` 1.6.0

### Назначение

Индексирует active/archive Pi sessions. FTS5 keyword search работает без provider; optional embeddings добавляют hybrid cosine + BM25/RRF.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:pi-session-search@1.6.0
```

Требуется Node `24+`. Indexing работает на Worker Thread. Примените [profile/runtime patch](../fixes/session-search.md): Code с `--runtime-only`, Task без этого флага.

### Конфигурация и данные

Code: `~/.pi/session-search/config.json` и `index/`; Task после patch: `<TASK_PROFILE>/session-search/`. Источники — profile `sessions/` и `sessions-archive/`. Project `pi-session-search.localPath` может перенести config/index, но не session source.

Polza config: `qwen/qwen3-embedding-8b`, 1024 dimensions, `sendDimensions: true`; см. [Polza memory](../polza-memory.md). Config содержит literal API key.

### Команды, tools и skills

- tools: `session_search`, `session_list`, `session_read`;
- commands: `/session-embeddings-setup`, `/session-sync`, `/session-reindex`;
- skill: `session-history`.

### Риски

Index и embeddings содержат производные от приватной session history. External embedder получает session text. Auto-sync может стартовать в child/noninteractive processes; используйте `sync.disableForChild: true`. Смена model/dimensions требует полного reindex.

### Проверка

`/session-sync`, затем `session_list` и точный keyword query. Для ранее настроенных embeddings достаточно короткой semantic query: обновление1.6 не требует forced `/session-reindex`. В Task убедитесь, что Code sessions/index не подмешаны; `session_read` должен читать Windows paths и отклонять чужие roots.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:pi-session-search
```

Patch сначала можно `--restore`. Удалите config/index отдельно; исходные Pi sessions не трогайте. Полный fix: [session-search](../fixes/session-search.md).

## `@samfp/pi-memory` 1.6.0

### Назначение

Хранит learned preferences, project patterns и corrections в SQLite, injects memory в новые sessions и консолидирует завершившийся диалог отдельным LLM run.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:@samfp/pi-memory@1.6.0
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>"
```

Scope `@samfp/` обязателен; unscoped `pi-memory` — другой package.

### Конфигурация и данные

По умолчанию БД `~/.pi/memory/memory.db` общая для обоих профилей. Project `pi-memory.localPath` изолирует БД. Stock package жёстко читает user-global settings из `~/.pi/agent/settings.json`; применяемый в сборке patch переключает этот путь на `<PI_CODING_AGENT_DIR>/settings.json`, поэтому Task получает собственный global config. Служебная модель — `polza-memory/deepseek/deepseek-v4.1-flash`.

Automatic vector recall использует upstream provider/hybrid/RRF с Polza `qwen/qwen3-embedding-8b`,1024d в `memory.embedding`. DeepSeek-консолидация и Session Search — независимые механизмы. Patch сохраняет upstream ephemeral context-hook, фильтрует project scope и помещает только целые записи.

Patch также читает id сессии через `sessionManager.getSessionId()`: stock-выражение `ctx.sessionId ?? ctx.session?.id` всегда даёт `undefined` (в `ExtensionContext` нет таких полей), из-за чего консолидированные lessons помечались `session:unknown`.

Xenova/warm-up удалены. До переключения сохранена consistent SQLite backup вне Git. Старые384d не сравниваются с новыми1024d; upstream backfill обновляет missing/wrong-dimension vectors при новом session start. Сразу после установки полный reindex личной БД не заявляется; старые процессы нужно полностью перезапустить.

### Команды, tools и skills

- tools: `memory_search`, `memory_remember`, `memory_forget`, `memory_lessons`, `memory_stats`;
- command `/memory-consolidate`;
- отдельных skills нет.

### Риски

Memory DB содержит персональные preferences/identity и project facts. Default injection capped 8 KiB, но может раскрыть данные в новом model request. Consolidation отправляет conversation внешней модели; кроме того, pi-memory передаёт consolidation prompt дочернему Pi как command-line аргумент `-p`, видимый локальным process monitors/администраторам/telemetry. Неверный model id/credential может привести к тихому пропуску. Embedding выбранным облачным provider отправляет туда тексты фактов и запросов. Без embedding config работает keyword fallback. Ephemeral hook не записывает memory block в историю или consolidation transcript.

### Проверка

Patch `--check` должен вернуть0 и `runtime-safe`. Build.6: Native SDK Both на synthetic SQLite/local mock проверил Windows Node child, ordered consolidation, profile/session ID, scope/aliases и ephemeral injection. Installed real Polza canary: русский paraphrase без keyword match автоматически recalled,2 successful embedding requests. Личные факты не fixtures; real DeepSeek consolidation не повторялась. Подробности: [memory fix](../fixes/memory.md).

### Удаление/откат

```bash
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>" --restore
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:@samfp/pi-memory
```

БД не удаляется автоматически. Удаляйте её только при остановленных профилях и после приватной backup.
