# Session Search: префиксы моделей, смысловой поиск и Windows roots

Exact `pi-session-search 1.6.0` по-прежнему имеет stock config/index в `~/.pi/session-search` и sources `~/.pi/agent/sessions{,-archive}`. Task должен сохранять собственные paths; Code — прежние stock paths.

Patcher проверяет immutable source copies и оба исполняемых bundles **`dist/index.js`/`dist/index-worker.js`** в одном guarded check/apply/backup/restore contract. Source roots передаются в штатные `IndexOptions → workerData`; reader использует те же config/default/extra roots, Windows-safe relative containment и canonical paths. Initial-sync timeout удаляется в `finally` при settlement.

Отображение проекта и summary используют **настоящий `session.cwd`**, если он доступен; без него остаётся исходный slug. `proj-alpha` не восстанавливается в выдуманный `proj/alpha`. Main и worker следуют одному правилу. UUID, project identity, JSONL paths и фильтрация истории не меняются.

Native Windows без `HOME` больше не получает буквальный относительный `~`: default roots, file references и раскрытие `~` в reader используют `node:os.homedir()`. Это не ограничение одним проектом: без `project` поиск остаётся межпроектным внутри выбранного индекса.

Incremental sync удаляет записи только из успешно перечисленного дерева, исключая недоступные подкаталоги. Missing/unreadable root сохраняет прежние JSON/vectors/FTS rows и reader state; readable empty root позволяет обычную очистку. Отсутствующий optional archive не блокирует очистку доступного active root. Записи вне текущих roots консервативно сохраняются.

В legacy `hybrid-fts.db` таблица `s` содержит session IDs. Load дополняет отсутствующие IDs из сохранённой metadata даже при непустом sidecar и равных counts с разным составом. Существующий полный текст и JSON/vector bytes сохраняются, embedder при восстановлении не вызывается. Counts chunks другой базы не являются количеством sessions этой таблицы; отсутствовавший полный текст из stripped metadata не восстановить.

Отдельный stale-reader framework не добавлен: tools работают через тот же `IndexService`, который выполняет sync. Последующие list/search/read видят собственный успешный sync и в прежнем 1.6.0. Мгновенная видимость внешней записи JSON не обещается; обычный sync/reload остаётся штатным lifecycle.

## Scope и качество выдачи

Без `project` `session_search` ищет по всем проектам **выбранного индекса**; явный `project` сужает выборку. Профильные config/index и project `localPath` по-прежнему могут выбирать разные хранилища. Стартовая подсказка недавних сессий текущего проекта не ограничивает subsequent search.

В [build.2](../releases/pi-1.4.0-build.2.md#известное-ограничение-смыслового-поиска) исправлены доступ и сохранность, но не ранжирование: нужная сессия оставалась вне top25. Тот результат остаётся FAIL. Текущая delta отдельно добавляет инструкции embedding-моделей и смысловой режим по умолчанию; она не меняет модель, размерность или индекс. Наличие vector и успешный `session_read` не заменяют проверку ранжирования, а один контрольный вопрос не доказывает качество всех запросов.

Отсутствие нужного результата не означает отсутствия разговора. Раздельно проверяйте выбранный index/project scope, доступность list/read и качество ранжирования. Чтение по известному ID не подменяет semantic search; не меняйте query/model/vectors и не запускайте массовый reindex ради формального PASS.

## Правила документов и вопросов

Правила выбираются по имени **модели**, не по провайдеру или совместимости API с OpenAI. Одна таблица в `createEmbedder` обслуживает main и worker. `embedBatch` получает документы, `embed` — поисковый вопрос; внутренний batch-вызов провайдера не добавляет второй префикс.

| Модель | `documentPrefix` | `queryPrefix` |
|---|---|---|
| `openai/text-embedding-3-large` | `""` | `""` |
| `openai/text-embedding-3-small` | `""` | `""` |
| `qwen/qwen3-embedding-8b` | `""` | Qwen ниже |
| `google/gemini-embedding-2-preview` | `"title: none \| text: "` | `"task: search result \| query: "` |
| `Qwen3-Embedding-0.6B`, включая узнаваемые GGUF-имена | `""` | Qwen ниже |
| `embeddinggemma-2`, включая узнаваемые локальные имена | `"title: none \| text: "` | `"task: search result \| query: "` |

Точная строка Qwen в JSON: `"Instruct: Given a web search query, retrieve relevant passages that answer the query\nQuery:"`. `\n` — перевод строки; после последнего двоеточия пробела нет. Google использует пробел после последнего двоеточия. Текст документа/вопроса присоединяется без других преобразований. Для документа без отдельного заголовка используется `title: none`.

Настройки `embedder.documentPrefix` и `embedder.queryPrefix` независимо переопределяют таблицу. Отсутствующее поле выбирает правило модели; **явная пустая строка `""` ничего не добавляет**, даже у Qwen/Google. Для новой модели достаточно указать две строки в конфиге. Для общего автоматического правила добавьте одну строку таблицы в существующем `patch_embedding_prefixes` и соответствующий regression case — новый provider/adapter не нужен.

Пример для непрозрачного локального alias (значение `model` заменяется точным ID из API LM Studio):

```json
{
  "fusion": "vector-primary",
  "embedder": {
    "type": "openai-compatible",
    "baseUrl": "http://localhost:1234",
    "model": "opaque-local-alias",
    "documentPrefix": "title: none | text: ",
    "queryPrefix": "task: search result | query: "
  }
}
```

Неизвестное имя без overrides сохраняет прежнюю передачу текста без префиксов. Произвольный локальный alias не распознаётся по содержимому модели: задайте строки явно. Автовставка инструкций на стороне конкретного backend Polza/LM Studio не подтверждена; если сервер уже форматирует текст, отключите соответствующий клиентский префикс через `""`. Для поиска кода у Google можно явно выбрать `"task: code retrieval | query: "`; автоматического определения типа/языка запроса нет.

Первоисточники; для Hugging Face указаны карточка, файл и точная проверенная ревизия:

- [OpenAI embeddings](https://developers.openai.com/api/docs/guides/embeddings).
- [Qwen 8B](https://huggingface.co/Qwen/Qwen3-Embedding-8B): `config_sentence_transformers.json`, ревизия `1d8ad4ca9b3dd8059ad90a75d4983776a23d44af`.
- [Qwen 0.6B](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B): `config_sentence_transformers.json`, ревизия `97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3`.
- [Gemini Embedding 2](https://ai.google.dev/gemini-api/docs/embeddings#task-types-embeddings-2).
- [EmbeddingGemma 2](https://huggingface.co/google/embeddinggemma-2): `config_sentence_transformers.json`, ревизия `914f7f89142e33e77833254d9c9b90c3cef7303b`.

Для Gemini preview карточка направляет на текущую инструкцию stable Embedding 2: это основание формата, **не подтверждение точного alias/версии backend Polza**. Форматирование проверяется отдельно от доступности каждой модели у провайдера.

## Режим поиска и индексация

Без явного `fusion` конфигурация выбирает `"vector-primary"`: порядок определяется только косинусным сходством, FTS-ранжирование не вызывается. Существующий `"fusion": "rrf"` **сохраняет** смешивание с FTS; для перехода поменяйте только это поле. Явный RRF остаётся доступным, а работа без embedder по-прежнему использует словесный поиск. Профили и проекты не объединяются. Прежняя численная шкала `SearchResult.score` сохранена; это не вероятность ответа и не новая калибровка процентов.

Автоматических проверок совместимости индекса, миграций и переиндексации не добавлено. При смене модели, размерности или **формата документа** пользователь сам управляет `/session-reindex`. Старый индекс Google, созданный без document-префикса, не преобразуется автоматически. У текущего Qwen document-префикс остаётся пустым: исправление только вопроса не требует пересчитывать документы той же модели. Не смешивайте векторы разных моделей только потому, что их размерность совпадает.

## Применение

```bash
# Code — сохранить stock config/index
python patches/session-search-profile/apply.py --agent-dir "<CODE_PROFILE_DIR>" --runtime-only --apply
# Task — использовать профильные config/index/sources
python patches/session-search-profile/apply.py --agent-dir "<TASK_PROFILE_DIR>" --apply
```

С тем же режимом доступны `--check` и byte-exact `--restore`. Check: `patched` (exit 0), `stock`/`previous-patched`/`published-patched`/`released-patched` (exit 1), unknown/unsupported (exit 2). Исторические состояния — root/timer без display, последующий display patch и build.2 без новых prefix/ranking изменений — различаются по полным точным bytes всех файлов, не marker. Unknown/mixed main/worker, чужой режим и другая версия отвергаются до writes. Verified backups всех `REL_FILES` с hash receipt пишутся под выбранным профилем; immutable store не меняется. Interrupted mixed writes требуют verified backup recovery.

## Конфигурация и данные

Task сохраняет `<TASK_PROFILE>/session-search/{config.json,index}`, `sessions` и `sessions-archive`. Project `localPath` не меняется. Config `sessionDir/archiveDir` имеет приоритет; default roots учитывают `PI_SESSION_DIR`, затем `PI_CODING_AGENT_SESSION_DIR`, и archive `PI_SESSION_ARCHIVE_DIR`. Extra roots разрешены и indexer, и reader.

Индексы и Polza embedding config остаются на прежних путях. Производный display summary обновляется на чтении из сохранённой session, не через изменение source JSONL или vectors. **Не выполнять forced `/session-reindex` ради самого обновления.** Не переносить чужие sessions/index и не менять model/dimensions попутно. Единственное целевое переключение режима описано выше; действующий конфиг не перезаписывается patcher-ом. Package restore не возвращает преобразованные upstream индексы; исходные session files не трогаются.

До рабочего обновления освободите index writers и сохраните verified recovery snapshot. Полезный JSON с векторами остаётся на месте, missing legacy FTS IDs восстанавливаются локально при load. Если прежний writer уже опустошил JSON, нужен проверенный непустой snapshot: patch сам не возвращает потерянные vectors. Не удалять stores и не запускать массовый платный reindex как замену recovery.

## Проверка

Текущий repair проверяет no-HOME paths и round trip, scan coverage/сохранность, legacy FTS ID coverage и reader после собственного sync. Прежние display cases (cwd с дефисом, отсутствующий cwd, одинаковые main/worker и старый summary) сохранены. Фактические synthetic, independent и working-runtime результаты разделены в [release notes](../releases/pi-1.4.0-build.2.md), не предполагаются из описания patch.

`python patches/session-search-profile/tests/test_runtime.py`: mode/restore/refusal и реальный timer settlement. Native synthetic smoke: отдельные Code/Task workers стартуют и закрываются; собственные sessions/archive/extra roots ищутся и читаются, чужой путь и symlink escape отклоняются. Synthetic FTS проверка не подтверждает paid hybrid backend; live-provider evidence указывается отдельно в release notes.

Tools/commands остаются `session_search`, `session_list`, `session_read`, `/session-sync`, `/session-reindex`, `/session-embeddings-setup` и `session-history`. Reinstall стирает patch — примените снова и перезапустите Pi. Полный context/session text может быть приватным: raw receipts вне Git.

Новые no-HOME/data-preservation regressions: `python -B -m unittest discover -s patches/session-search-profile/tests -p "test_*.py" -v`. Locked Node, peer entry `SESSION_SEARCH_TYPEBOX` и private temp root — по [patch README](../../patches/session-search-profile/README.md#проверка-и-данные). Выполняются настоящие handlers в main/worker/affected TS, но Pi registry/UI — fixture. Недоступный существующий root проверяется реальным native `ENOTDIR`; native permission-denied не заявляется. Loopback fixture embeddings не подтверждают live semantic retrieval, real SDK lifecycle или личную историю.

`test_embedding_prefixes.py` дополнительно выполняет 15 пар document/query, включая шесть запрошенных моделей, узнаваемые локальные имена и пустые/собственные overrides, на настоящих factory/transport bodies исходника и обоих bundles. Проверяются точные HTTP input/model/dimensions, отсутствие двойного префикса, сохранение AbortSignal/лимита текста, default/явный RRF и отсутствие вызова keyword arm в смысловом режиме. Внешний HTTP заменён fixture; доступность всех шести backend-моделей этим не заявляется.

Prefix/ranking delta и настоящая installed приёмка относятся к [build.3](../releases/pi-1.4.0-build.3.md): прежний контрольный query нашёл target на rank1 из1293. Offline replay source/main/worker на сохранённом query vector — отдельное evidence, не свежий provider call. Исторические no-HOME/preservation результаты build.2 не переименованы в новый полный runtime/model PASS.
