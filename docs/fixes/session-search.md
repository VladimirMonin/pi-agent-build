# Session Search: изоляция профиля Task

## Назначение

Stock `pi-session-search 1.4.3` жёстко использует:

- `~/.pi/session-search` для config/index;
- `~/.pi/agent/sessions` и `sessions-archive` как sources.

Из-за этого Task читает историю Code. Patch `session-search-profile` заставляет package учитывать `PI_CODING_AGENT_DIR`, сохраняя более явные `PI_SESSION_DIR`/`PI_SESSION_ARCHIVE_DIR` как overrides.

Code patch не нужен: его стандартный путь и так `~/.pi/agent`. Patch применяют только к Task.

## Применение

```bash
python patches/session-search-profile/apply.py \
  --agent-dir "<TASK_PROFILE_DIR>" --check
python patches/session-search-profile/apply.py \
  --agent-dir "<TASK_PROFILE_DIR>" --apply
```

Поддерживается ровно `1.4.3`; меняются `src/config.ts`, `src/parser.ts`, `dist/index.js`. Перед первой правкой pristine copies сохраняются в patch store, после записи запускается `node --check`.

## Конфигурация и данные

После patch Task использует:

```text
~/.pi/task/session-search/config.json
~/.pi/task/session-search/index/
~/.pi/task/sessions/
~/.pi/task/sessions-archive/
```

Старый общий index автоматически не переносится. Создайте Task config заново и выполните `/session-reindex`.

## Tools/команды

Tool surface не меняется: `session_search`, `session_list`, `session_read`, `/session-sync`, `/session-reindex`, `/session-embeddings-setup`, skill `session-history`.

## Риски

Full reindex может отправить приватный текст внешнему embedder и стоить денег. Partial patch state блокируется. Reinstall package стирает правку. Explicit `PI_SESSION_DIR` всё ещё может сознательно нарушить изоляцию.

## Проверка

```bash
python patches/session-search-profile/apply.py \
  --agent-dir "<TASK_PROFILE_DIR>" --check
```

Ожидается `ALREADY PATCHED`. В Task выполните `/session-reindex`, затем `session_list`; создайте контрольные sessions с разными marker в Code/Task и подтвердите отсутствие перекрёстных результатов.

## Удаление/откат

```bash
python patches/session-search-profile/apply.py \
  --agent-dir "<TASK_PROFILE_DIR>" --restore
```

Restore byte-exact требует сохранённых pristine files. После отката Task снова видит Code paths; удалите/архивируйте профильный Task index отдельно, если он больше не нужен.
