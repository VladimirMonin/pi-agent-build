# Session Search: profile roots, worker и Windows session_read

Exact `pi-session-search 1.6.0` по-прежнему имеет stock config/index в `~/.pi/session-search` и sources `~/.pi/agent/sessions{,-archive}`. Task должен сохранять собственные paths; Code — прежние stock paths.

Patch использует четыре immutable npm copies: `src/config.ts`, `src/parser.ts`, `src/index.ts`, `dist/index.js`. Выбранные roots передаются в штатные `IndexOptions → workerData`; **`dist/index-worker.js` не меняется**. Reader использует те же config/default/extra roots, Windows-safe relative containment и canonical paths вместо сломанного `startsWith(root + "/")`. Initial-sync timeout удаляется в `finally` при settlement.

## Применение

```bash
# Code — сохранить stock config/index
python patches/session-search-profile/apply.py --agent-dir "<CODE_PROFILE_DIR>" --runtime-only --apply
# Task — использовать профильные config/index/sources
python patches/session-search-profile/apply.py --agent-dir "<TASK_PROFILE_DIR>" --apply
```

С тем же режимом доступны `--check` и byte-exact `--restore`. Только exact stock/canonical принимаются; неизвестное/смешанное состояние и другая версия отвергаются до writes. Backups пишутся под выбранным профилем, immutable store не изменяется.

## Конфигурация и данные

Task сохраняет `<TASK_PROFILE>/session-search/{config.json,index}`, `sessions` и `sessions-archive`. Project `localPath` не меняется. Config `sessionDir/archiveDir` имеет приоритет; default roots учитывают `PI_SESSION_DIR`, затем `PI_CODING_AGENT_SESSION_DIR`, и archive `PI_SESSION_ARCHIVE_DIR`. Extra roots разрешены и indexer, и reader.

Индексы и Polza embedding config остаются на прежних путях. **Не выполнять forced `/session-reindex` при этом обновлении.** Не переносить чужие sessions/index и не менять model/dimensions/fusion попутно. Package restore не возвращает преобразованные upstream индексы; исходные session files не трогаются.

## Проверка

`python patches/session-search-profile/tests/test_runtime.py`: mode/restore/refusal и реальный timer settlement. Native synthetic smoke: отдельные Code/Task workers стартуют и закрываются; собственные sessions/archive/extra roots ищутся и читаются, чужой путь и symlink escape отклоняются. Synthetic FTS проверка не подтверждает paid hybrid backend; live-provider evidence указывается отдельно в release notes.

Tools/commands остаются `session_search`, `session_list`, `session_read`, `/session-sync`, `/session-reindex`, `/session-embeddings-setup` и `session-history`. Reinstall стирает patch — примените снова и перезапустите Pi. Полный context/session text может быть приватным: raw receipts вне Git.
