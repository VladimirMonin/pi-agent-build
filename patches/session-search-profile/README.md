# pi-session-search 1.6.0: profile roots и Windows session_read

Поддерживается ровно `pi-session-search@1.6.0`. Immutable store содержит exact npm `src/config.ts`, `src/parser.ts`, `src/index.ts` и `dist/index.js`; hashes проверяются до любых writes.

Task сохраняет `<TASK_PROFILE>/session-search/{config.json,index}`, `sessions` и `sessions-archive`. Code сохраняет stock `~/.pi/session-search` и стандартные sources. Project `localPath` и явные config overrides не меняются.

Оба режима:

- учитывают `PI_SESSION_DIR`, затем `PI_CODING_AGENT_SESSION_DIR`; archive override `PI_SESSION_ARCHIVE_DIR` сохраняется;
- передают выбранные sources в `IndexOptions → workerData`, поэтому **worker bundle не патчится**;
- `session_read` использует те же configured/default/extra roots, Windows-safe `path.relative` containment и canonical paths для защиты от symlink/junction escape;
- очищают проигравший initial-sync timeout в `finally` при resolve/reject, сохраняя настоящий timeout.

## Использование

```powershell
# Code: stock config/index paths
python .\patches\session-search-profile\apply.py --agent-dir "$HOME\.pi\agent" --runtime-only --apply
# Task: profile config/index paths
python .\patches\session-search-profile\apply.py --agent-dir "$HOME\.pi\task" --apply
```

Для `--check`/`--restore` используйте тот же режим. Check: 0=canonical, 1=stock, 2=unknown/mixed/wrong-version/hash mismatch. Apply идемпотентен; restore byte-exact из Git store. Backups только под выбранным профилем `.pi-agent-build-backups/session-search-profile`.

## Проверка и данные

`python patches/session-search-profile/tests/test_runtime.py` проверяет режимы, drift refusal, restore и реальные resolve/reject/timeout settlement. Windows script regression проверяет immutable stores. Native short smoke на synthetic sessions: actual worker стартует/закрывается, Code/Task ищут и читают свои sessions/archive/extra roots; посторонние пути и symlink escape отклоняются.

Индексы/config/Polza model остаются на прежних путях. **Обновление не требует forced `/session-reindex`** и не меняет fusion/embeddings. Paid semantic checks здесь не выполняются. Reinstall стирает patch: примените его снова и перезапустите Pi. Package restore не откатывает данные индекса; не удаляйте их или исходные sessions попутно.
