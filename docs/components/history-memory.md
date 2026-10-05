# История сессий и долговременная память

## `pi-session-search` 1.4.3

### Назначение

Индексирует active/archive Pi sessions. FTS5 keyword search работает без provider; optional embeddings добавляют hybrid cosine + BM25/RRF.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:pi-session-search@1.4.3
```

Требуется Node `24+`. Для Task примените [profile patch](../fixes/session-search.md).

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

`/session-sync`, затем `session_list` и точный keyword query. После embeddings — `/session-reindex` и semantic query. В Task убедитесь, что Code sessions/index не подмешаны.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:pi-session-search
```

Patch сначала можно `--restore`. Удалите config/index отдельно; исходные Pi sessions не трогайте. Полный fix: [session-search](../fixes/session-search.md).

## `@samfp/pi-memory` 1.5.0

### Назначение

Хранит learned preferences, project patterns и corrections в SQLite, injects memory в новые sessions и консолидирует завершившийся диалог отдельным LLM run.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:@samfp/pi-memory@1.5.0
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>"
```

Scope `@samfp/` обязателен; unscoped `pi-memory` — другой package.

### Конфигурация и данные

По умолчанию БД `~/.pi/memory/memory.db` общая для обоих профилей. Project `pi-memory.localPath` изолирует БД. Stock package жёстко читает user-global settings из `~/.pi/agent/settings.json`; применяемый в сборке patch переключает этот путь на `<PI_CODING_AGENT_DIR>/settings.json`, поэтому Task получает собственный global config. Служебная модель — `polza-memory/deepseek/deepseek-v4.1-flash`.

Семантический поиск по фактам работает на **локальном** embedder'е `Xenova/paraphrase-multilingual-MiniLM-L12-v2` (384d, offline, без ключа), который ставит patch вместо англоязычного stock `all-MiniLM-L6-v2`. Это отдельный механизм от Polza-консолидации и от embedder'а `pi-session-search`.

Patch также читает id сессии через `sessionManager.getSessionId()`: stock-выражение `ctx.sessionId ?? ctx.session?.id` всегда даёт `undefined` (в `ExtensionContext` нет таких полей), из-за чего консолидированные lessons помечались `session:unknown`.

Плагин грузит модель лениво с таймаутом 30 с; на холодном кэше медленное скачивание может его превысить и поиск молча уйдёт в FTS-only. Прогрейте кэш заранее (у каждого профиля свой, ~130 МБ): `node scripts/warm-memory-embedder.mjs "<PROFILE_DIR>"`.

### Команды, tools и skills

- tools: `memory_search`, `memory_remember`, `memory_forget`, `memory_lessons`, `memory_stats`;
- command `/memory-consolidate`;
- отдельных skills нет.

### Риски

Memory DB содержит персональные preferences/identity и project facts. Default injection capped 8 KiB, но может раскрыть данные в новом model request. Consolidation отправляет conversation внешней модели; кроме того, pi-memory передаёт consolidation prompt дочернему Pi как command-line аргумент `-p`, видимый локальным process monitors/администраторам/telemetry. Неверный model id/credential может привести к тихому пропуску. `perTurnInjection` ухудшает prefix-cache stability и по умолчанию не нужен. Embedder памяти локальный и офлайн — факты не покидают машину на этом шаге, но модель (~130 МБ) скачивается с HuggingFace при первом использовании. Если кэш не прогрет, первый семантический поиск молча откатывается на FTS-only.

### Проверка

Patch `--check` должен печатать `RUNTIME-SAFE`. Выполните `memory_stats`, сохраните тестовый факт через `memory_remember`, найдите его и удалите. На Pi1.0.2 Code/Task реально проверены synthetic remember/search в **FTS fallback** и local-mock lifecycle без внешнего model call; cold HF download был заблокирован. Это не semantic embedding и не consolidation acceptance. Реальный consolidation/model call требует отдельного разрешения. Структурные тесты `test-memory-pushturn.mjs`, `test-memory-embedder.mjs` и `test-memory-sessionid.mjs` бесплатны. Подробности: [memory fix](../fixes/memory.md).

### Удаление/откат

```bash
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>" --restore
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:@samfp/pi-memory
```

БД не удаляется автоматически. Удаляйте её только при остановленных профилях и после приватной backup.
