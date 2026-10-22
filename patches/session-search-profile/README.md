# pi-session-search 1.6.0: profile roots и Windows session_read

Поддерживается ровно `pi-session-search@1.6.0`. Immutable store и hashes охватывают source files из `REL_FILES` в [patcher-е](apply.py) и **оба `dist/index.js`/`dist/index-worker.js`**; проверка предшествует writes. Display path включает utils, session/FTS index и index-service. Исполняемый worker входит в тот же check/apply/backup/restore contract, не только исходный TypeScript.

Task сохраняет `<TASK_PROFILE>/session-search/{config.json,index}`, `sessions` и `sessions-archive`. Code сохраняет stock `~/.pi/session-search` и стандартные sources. Project `localPath` и явные config overrides не меняются.

Оба режима:

- учитывают `PI_SESSION_DIR`, затем `PI_CODING_AGENT_SESSION_DIR`; archive override `PI_SESSION_ARCHIVE_DIR` сохраняется;
- передают выбранные source roots в `IndexOptions → workerData`;
- показывают настоящий `session.cwd`, если он есть; без cwd сохраняют исходный slug, не угадывают путь заменой дефисов. Одинаковое правило действует в main/worker и производном summary;
- `session_read` использует те же configured/default/extra roots, Windows-safe `path.relative` containment и canonical paths для защиты от symlink/junction escape;
- очищают проигравший initial-sync timeout в `finally` при resolve/reject, сохраняя настоящий timeout.

## Использование

```powershell
# Code: stock config/index paths
python .\patches\session-search-profile\apply.py --agent-dir "$HOME\.pi\agent" --runtime-only --apply
# Task: profile config/index paths
python .\patches\session-search-profile\apply.py --agent-dir "$HOME\.pi\task" --apply
```

Для `--check`/`--restore` используйте тот же режим. Canonical no-op, exact stock, известный previous patch и unknown/mixed state различаются по полному набору bytes; marker не доказательство. Apply идемпотентен, known previous получает backup перед переходом; restore byte-exact из immutable store. Backups только под выбранным профилем `.pi-agent-build-backups/session-search-profile`. Точные state/exit значения принадлежат CLI выбранной ревизии.

## Проверка и данные

`python patches/session-search-profile/tests/test_runtime.py` проверяет режимы, drift refusal, restore и реальные resolve/reject/timeout settlement. Windows script regression проверяет immutable stores. Native short smoke на synthetic sessions: actual worker стартует/закрывается, Code/Task ищут и читают свои sessions/archive/extra roots; посторонние пути и symlink escape отклоняются.

Индексы/config/Polza model остаются на прежних путях. Старые сохранённые FTS/vector summaries обновляются для display при чтении из session с cwd, без изменения сохранённых rows/vectors. При будущем естественном индексировании новой/изменённой сессии embedding input также получает исправленный `Project:`/cwd; это не миграция UUID, project identity, JSONL paths, фильтров или vectors. **Не нужен forced `/session-reindex`**, не меняются fusion/embedding model/dimensions и не отправляется вся история ради display fix. Reinstall стирает patch: примените его снова и перезапустите Pi. Package restore не откатывает данные индекса; не удаляйте их или исходные sessions попутно.

Для приёмки текущей delta проверяются cwd с дефисом, отсутствующий cwd, равенство main/worker и чтение прежнего summary без mass reindex. Наличие этих правил/команд в README не является результатом запуска; фактическая область — в release evidence.
