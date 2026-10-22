# Session Search: profile roots, worker и Windows session_read

Exact `pi-session-search 1.6.0` по-прежнему имеет stock config/index в `~/.pi/session-search` и sources `~/.pi/agent/sessions{,-archive}`. Task должен сохранять собственные paths; Code — прежние stock paths.

Patcher проверяет immutable source copies и оба исполняемых bundles **`dist/index.js`/`dist/index-worker.js`** в одном guarded check/apply/backup/restore contract. Source roots передаются в штатные `IndexOptions → workerData`; reader использует те же config/default/extra roots, Windows-safe relative containment и canonical paths. Initial-sync timeout удаляется в `finally` при settlement.

Отображение проекта и summary используют **настоящий `session.cwd`**, если он доступен; без него остаётся исходный slug. `proj-alpha` не восстанавливается в выдуманный `proj/alpha`. Main и worker следуют одному правилу. UUID, project identity, JSONL paths и фильтрация истории не меняются.

## Применение

```bash
# Code — сохранить stock config/index
python patches/session-search-profile/apply.py --agent-dir "<CODE_PROFILE_DIR>" --runtime-only --apply
# Task — использовать профильные config/index/sources
python patches/session-search-profile/apply.py --agent-dir "<TASK_PROFILE_DIR>" --apply
```

С тем же режимом доступны `--check` и byte-exact `--restore`. Exact stock, известный previous patch и canonical различаются по bytes всех файлов. Unknown/mixed state и другая версия отвергаются до writes, marker не достаточен. Backups пишутся под выбранным профилем, immutable store не изменяется.

## Конфигурация и данные

Task сохраняет `<TASK_PROFILE>/session-search/{config.json,index}`, `sessions` и `sessions-archive`. Project `localPath` не меняется. Config `sessionDir/archiveDir` имеет приоритет; default roots учитывают `PI_SESSION_DIR`, затем `PI_CODING_AGENT_SESSION_DIR`, и archive `PI_SESSION_ARCHIVE_DIR`. Extra roots разрешены и indexer, и reader.

Индексы и Polza embedding config остаются на прежних путях. Производный display summary обновляется на чтении из сохранённой session, не через изменение source JSONL или vectors. **Не выполнять forced `/session-reindex` при этом обновлении.** Не переносить чужие sessions/index и не менять model/dimensions/fusion попутно. Package restore не возвращает преобразованные upstream индексы; исходные session files не трогаются.

## Проверка

Текущая display delta: проект с дефисом, отсутствующий cwd, одинаковые main/worker и производный summary старой записи; без paid reindex. Запуск/результат указываются отдельно в release evidence, не предполагаются из описания patch.

`python patches/session-search-profile/tests/test_runtime.py`: mode/restore/refusal и реальный timer settlement. Native synthetic smoke: отдельные Code/Task workers стартуют и закрываются; собственные sessions/archive/extra roots ищутся и читаются, чужой путь и symlink escape отклоняются. Synthetic FTS проверка не подтверждает paid hybrid backend; live-provider evidence указывается отдельно в release notes.

Tools/commands остаются `session_search`, `session_list`, `session_read`, `/session-sync`, `/session-reindex`, `/session-embeddings-setup` и `session-history`. Reinstall стирает patch — примените снова и перезапустите Pi. Полный context/session text может быть приватным: raw receipts вне Git.
