# Session Search: profile roots, worker и Windows session_read

Exact `pi-session-search 1.6.0` по-прежнему имеет stock config/index в `~/.pi/session-search` и sources `~/.pi/agent/sessions{,-archive}`. Task должен сохранять собственные paths; Code — прежние stock paths.

Patcher проверяет immutable source copies и оба исполняемых bundles **`dist/index.js`/`dist/index-worker.js`** в одном guarded check/apply/backup/restore contract. Source roots передаются в штатные `IndexOptions → workerData`; reader использует те же config/default/extra roots, Windows-safe relative containment и canonical paths. Initial-sync timeout удаляется в `finally` при settlement.

Отображение проекта и summary используют **настоящий `session.cwd`**, если он доступен; без него остаётся исходный slug. `proj-alpha` не восстанавливается в выдуманный `proj/alpha`. Main и worker следуют одному правилу. UUID, project identity, JSONL paths и фильтрация истории не меняются.

Native Windows без `HOME` больше не получает буквальный относительный `~`: default roots, file references и раскрытие `~` в reader используют `node:os.homedir()`. Это не ограничение одним проектом: без `project` поиск остаётся межпроектным внутри выбранного индекса.

Incremental sync удаляет записи только из успешно перечисленного дерева, исключая недоступные подкаталоги. Missing/unreadable root сохраняет прежние JSON/vectors/FTS rows и reader state; readable empty root позволяет обычную очистку. Отсутствующий optional archive не блокирует очистку доступного active root. Записи вне текущих roots консервативно сохраняются.

В legacy `hybrid-fts.db` таблица `s` содержит session IDs. Load дополняет отсутствующие IDs из сохранённой metadata даже при непустом sidecar и равных counts с разным составом. Существующий полный текст и JSON/vector bytes сохраняются, embedder при восстановлении не вызывается. Counts chunks другой базы не являются количеством sessions этой таблицы; отсутствовавший полный текст из stripped metadata не восстановить.

Отдельный stale-reader framework не добавлен: tools работают через тот же `IndexService`, который выполняет sync. Последующие list/search/read видят собственный успешный sync и в прежнем 1.6.0. Мгновенная видимость внешней записи JSON не обещается; обычный sync/reload остаётся штатным lifecycle.

## Scope и качество выдачи

Без `project` `session_search` ищет по всем проектам **выбранного индекса**; явный `project` сужает выборку. Профильные config/index и project `localPath` по-прежнему могут выбирать разные хранилища. Стартовая подсказка недавних сессий текущего проекта не ограничивает subsequent search.

Этот patch чинит доступ к sources/index, file-reference → read и недеструктивный sync/FTS coverage, **не обещая улучшения semantic recall/ранжирования**. Embedding model/dimensions и ranking/fusion не переключаются. Непустой индекс, наличие vector и успешный `session_read` не доказывают полноту semantic выдачи. В [build.2](../releases/pi-1.4.0-build.2.md#известное-ограничение-смыслового-поиска) контрольный широкий тематический запрос дошёл до настоящего provider/SDK, но нужная сессия осталась вне top25. Offline replay с одним свежим embedding точного текущего payload также оставил её вне top25, без записи нового vector в индекс. Исходный результат остаётся FAIL; это известное ограничение качества, не установленный новый implementation defect.

Отсутствие нужного результата не означает отсутствия разговора. Раздельно проверяйте выбранный index/project scope, доступность list/read и качество ранжирования. Чтение по известному ID не подменяет semantic search; не меняйте query/model/vectors и не запускайте массовый reindex ради формального PASS.

## Применение

```bash
# Code — сохранить stock config/index
python patches/session-search-profile/apply.py --agent-dir "<CODE_PROFILE_DIR>" --runtime-only --apply
# Task — использовать профильные config/index/sources
python patches/session-search-profile/apply.py --agent-dir "<TASK_PROFILE_DIR>" --apply
```

С тем же режимом доступны `--check` и byte-exact `--restore`. Check: `patched` (exit 0), `stock`/`previous-patched`/`published-patched` (exit 1), unknown/unsupported (exit 2). Два исторических состояния — root/timer без display и последующий опубликованный display patch — различаются по полным точным bytes всех файлов, не marker. Unknown/mixed main/worker, чужой режим и другая версия отвергаются до writes. Verified backups всех `REL_FILES` с hash receipt пишутся под выбранным профилем; immutable store не меняется. Interrupted mixed writes требуют verified backup recovery.

## Конфигурация и данные

Task сохраняет `<TASK_PROFILE>/session-search/{config.json,index}`, `sessions` и `sessions-archive`. Project `localPath` не меняется. Config `sessionDir/archiveDir` имеет приоритет; default roots учитывают `PI_SESSION_DIR`, затем `PI_CODING_AGENT_SESSION_DIR`, и archive `PI_SESSION_ARCHIVE_DIR`. Extra roots разрешены и indexer, и reader.

Индексы и Polza embedding config остаются на прежних путях. Производный display summary обновляется на чтении из сохранённой session, не через изменение source JSONL или vectors. **Не выполнять forced `/session-reindex` при этом обновлении.** Не переносить чужие sessions/index и не менять model/dimensions/fusion попутно. Package restore не возвращает преобразованные upstream индексы; исходные session files не трогаются.

До рабочего обновления освободите index writers и сохраните verified recovery snapshot. Полезный JSON с векторами остаётся на месте, missing legacy FTS IDs восстанавливаются локально при load. Если прежний writer уже опустошил JSON, нужен проверенный непустой snapshot: patch сам не возвращает потерянные vectors. Не удалять stores и не запускать массовый платный reindex как замену recovery.

## Проверка

Текущий repair проверяет no-HOME paths и round trip, scan coverage/сохранность, legacy FTS ID coverage и reader после собственного sync. Прежние display cases (cwd с дефисом, отсутствующий cwd, одинаковые main/worker и старый summary) сохранены. Фактические synthetic, independent и working-runtime результаты разделены в [release notes](../releases/pi-1.4.0-build.2.md), не предполагаются из описания patch.

`python patches/session-search-profile/tests/test_runtime.py`: mode/restore/refusal и реальный timer settlement. Native synthetic smoke: отдельные Code/Task workers стартуют и закрываются; собственные sessions/archive/extra roots ищутся и читаются, чужой путь и symlink escape отклоняются. Synthetic FTS проверка не подтверждает paid hybrid backend; live-provider evidence указывается отдельно в release notes.

Tools/commands остаются `session_search`, `session_list`, `session_read`, `/session-sync`, `/session-reindex`, `/session-embeddings-setup` и `session-history`. Reinstall стирает patch — примените снова и перезапустите Pi. Полный context/session text может быть приватным: raw receipts вне Git.

Новые no-HOME/data-preservation regressions: `python -B -m unittest discover -s patches/session-search-profile/tests -p "test_*.py" -v`. Locked Node, peer entry `SESSION_SEARCH_TYPEBOX` и private temp root — по [patch README](../../patches/session-search-profile/README.md#проверка-и-данные). Выполняются настоящие handlers в main/worker/affected TS, но Pi registry/UI — fixture. Недоступный существующий root проверяется реальным native `ENOTDIR`; native permission-denied не заявляется. Loopback fixture embeddings не подтверждают live semantic retrieval, real SDK lifecycle или личную историю.
