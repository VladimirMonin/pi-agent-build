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

В [build.2](../releases/pi-1.4.0-build.2.md#известное-ограничение-смыслового-поиска) нужная сессия оставалась вне top25; тот FAIL сохранён. [Build.3](../releases/pi-1.4.0-build.3.md) исправил контрольный поиск, но использовал эвристику имён и прежнюю шкалу fusion. [Build.4](../releases/pi-1.4.0-build.4.md) заменяет их обязательным точным mapping и отдельным `semantic-only`. Модель, размерность и исходные векторы не меняются. Наличие vector и успешный `session_read` не заменяют проверку ранжирования, а один контрольный вопрос не доказывает качество всех запросов.

Отсутствие нужного результата не означает отсутствия разговора. Раздельно проверяйте выбранный index/project scope, доступность list/read и качество ранжирования. Чтение по известному ID не подменяет semantic search; не меняйте query/model/vectors и не запускайте массовый reindex ради формального PASS.

## Правила документов и вопросов

Обязательный `embedder.modelPrefixes` содержит запись по **точному** `embedder.model`. Обе строки `queryPrefix` и `documentPrefix` обязательны, включая намеренно пустые `""`. Регистр, локальные aliases и суффиксы не угадываются. Неизвестная модель, отсутствующая запись или неверный тип дают ошибку до embedding-запроса, а не raw/keyword fallback. Каталог находится в [безопасном примере](../../config/session-search.polza.example.json); наличие записи не доказывает доступность модели на выбранном сервере.

Общие `resolveModelPrefixes` / `prepareEmbeddingInput` работают в source/main/worker. **Индексатор** форматирует документ перед `embedBatch`, вопрос перед `embed`. Провайдер передаёт уже подготовленный текст без повторного форматирования; внутренний singleton→batch сохраняет роль. Прежние поля `embedder.queryPrefix/documentPrefix` больше не выбирают формат: перенесите строки внутрь точной записи `modelPrefixes`.

| Модель | `documentPrefix` | `queryPrefix` |
|---|---|---|
| `openai/text-embedding-3-large` | `""` | `""` |
| `openai/text-embedding-3-small` | `""` | `""` |
| `qwen/qwen3-embedding-8b` | `""` | Qwen ниже |
| `google/gemini-embedding-2-preview` | `"title: none \| text: "` | `"task: search result \| query: "` |
| `Qwen/Qwen3-Embedding-0.6B` | `""` | Qwen ниже |
| `google/embeddinggemma-2` | `"title: none \| text: "` | `"task: search result \| query: "` |
| Четыре точных HF ID Nemotron ниже, локальный подготовленный текст | `"passage: "` | `"query: "` |

Точная строка Qwen в JSON: `"Instruct: Given a web search query, retrieve relevant passages that answer the query\nQuery:"`. `\n` — перевод строки; после последнего двоеточия пробела нет. Google использует пробел после последнего двоеточия. Текст документа/вопроса присоединяется без других преобразований. Для документа без отдельного заголовка используется `title: none`.

Для новой модели или непрозрачного локального alias добавьте одну явную запись в конфиге; новый provider/adapter не нужен. Возьмите точный ID, который обслуживает сервер, не название семейства или предположительный GGUF alias. Пример ниже задаёт Google-формат явно; он подходит только если этот сервер ожидает такую строку.

Пример для непрозрачного локального alias (значение `model` заменяется точным ID из API LM Studio):

```json
{
  "fusion": "semantic-only",
  "embedder": {
    "type": "openai-compatible",
    "baseUrl": "http://localhost:1234",
    "model": "opaque-local-alias",
    "modelPrefixes": {
      "opaque-local-alias": {
        "documentPrefix": "title: none | text: ",
        "queryPrefix": "task: search result | query: "
      }
    }
  }
}
```

Автовставка инструкций конкретным backend Polza/LM Studio не подтверждена. Если сервер уже форматирует текст, задайте обе строки явно с учётом его контракта; `""` отключает соответствующий клиентский префикс. Для поиска кода у Google можно явно выбрать `"task: code retrieval | query: "`; автоматического определения типа/языка запроса нет.

Первоисточники; для Hugging Face указаны карточка, файл и точная проверенная ревизия:

- [OpenAI embeddings](https://developers.openai.com/api/docs/guides/embeddings).
- [Qwen 8B](https://huggingface.co/Qwen/Qwen3-Embedding-8B): `config_sentence_transformers.json`, ревизия `1d8ad4ca9b3dd8059ad90a75d4983776a23d44af`.
- [Qwen 0.6B](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B): `config_sentence_transformers.json`, ревизия `97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3`.
- [Gemini Embedding 2](https://ai.google.dev/gemini-api/docs/embeddings#task-types-embeddings-2).
- [EmbeddingGemma 2](https://huggingface.co/google/embeddinggemma-2): `config_sentence_transformers.json`, ревизия `914f7f89142e33e77833254d9c9b90c3cef7303b`.

Для Gemini preview карточка направляет на текущую инструкцию stable Embedding 2: это основание формата, **не подтверждение точного alias/версии backend Polza**. Форматирование проверяется отдельно от доступности каждой модели у провайдера.

## Nemotron: четыре модели и два способа передачи роли

Проверены официальные карточки и `config_sentence_transformers.json` на закреплённых ревизиях. Все четыре задают `query: ` / `passage: `, включая пробел. Это **правила подготовки текста**, не подтверждение установленного GGUF или совместимости LM Studio.

| Точный HF ID | Размерность HF | Проверенный prompt config / revision |
|---|---|---|
| [nvidia/Nemotron-3-Embed-1B-BF16](https://huggingface.co/nvidia/Nemotron-3-Embed-1B-BF16) | 2048 | `config_sentence_transformers.json` @ `c0c9fea93ea424587517f2c59e20db9f1d6bf615` |
| [nvidia/Nemotron-3-Embed-8B-BF16](https://huggingface.co/nvidia/Nemotron-3-Embed-8B-BF16) | 4096 | `config_sentence_transformers.json` @ `d1f2f25730bbd775b99b29185134bc86653bf2d1` |
| [nvidia/Nemotron-3.5-Embed-1B-BF16](https://huggingface.co/nvidia/Nemotron-3.5-Embed-1B-BF16) | 2048 | `config_sentence_transformers.json` @ `e24ca1e346bcc53572bd7bdc02b3e8ebf66c197c` |
| [nvidia/Nemotron-3.5-Embed-8B-BF16](https://huggingface.co/nvidia/Nemotron-3.5-Embed-8B-BF16) | 4096 | `config_sentence_transformers.json` @ `781e779ee4ca9c2d2a4f38321993556baeab49a1` |

- **Локальный подготовленный текст:** одна запись с двумя префиксами. Если фактический served ID отличается от HF ID, добавьте его явно. Если сервер сам применяет native processor, не дублируйте его форматирование. Native templates 3.5 дополнительно экранируют `[` и `<` символом U+200C; две строки не воспроизводят весь процессор и не добавляют поиск по изображениям.
- **NVIDIA NIM:** raw input плюс API `input_type: "query"` / `"passage"`, без ручного префикса. [NIM 2.4 API](https://docs.nvidia.com/nim/nemo-retriever/embedding/2.4/use-the-api-openai.html) и [support matrix](https://docs.nvidia.com/nim/nemo-retriever/embedding/2.4/support-matrix.html). Для hosted подтверждены request IDs `nvidia/nemotron-3-embed-1b`, `nvidia/nemotron-3.5-embed-1b`, `nvidia/nemotron-3.5-embed-8b`; это отдельные, явно записанные IDs, не автоматическое приведение регистра. Hosted Nemotron 3 Embed 8B не подтверждён.
- **OpenRouter:** [API](https://openrouter.ai/docs/api/api-reference/embeddings/submit-an-embedding-request) имеет строковое `input_type`; [каталог embeddings](https://openrouter.ai/api/v1/embeddings/models) перечислял три `:free` ID для 3/1B, 3.5/1B и 3.5/8B. Передача/преобразование NVIDIA `query`/`passage` **не проверены**. Эти routes намеренно не добавлены в готовый mapping. Бесплатные NVIDIA endpoints предупреждают о журналировании запросов; не отправляйте личную историю без отдельного решения.

Для NIM используется тот же необязательный механизм существующего `openai-compatible` адаптера, без отдельной архитектуры. Пример отдельного конфига **для нового индекса**, а не замена работающего Qwen:

```json
{
  "fusion": "semantic-only",
  "embedder": {
    "type": "openai-compatible",
    "baseUrl": "https://integrate.api.nvidia.com",
    "embeddingsEndpoint": "https://integrate.api.nvidia.com/v1/embeddings",
    "model": "nvidia/nemotron-3-embed-1b",
    "dimensions": 2048,
    "sendDimensions": false,
    "apiKey": "<LOCAL_SECRET>",
    "modelPrefixes": {
      "nvidia/nemotron-3-embed-1b": {
        "queryPrefix": "", "documentPrefix": "",
        "inputType": { "query": "query", "document": "passage" }
      }
    }
  }
}
```

`inputType` разрешён только для `openai-compatible`, с обеими пустыми строками; сочетание API-роли и ручного префикса отвергается. `embeddingsEndpoint` — точный URL; без него сохраняется `baseUrl + /v1/embeddings`. Настройка проверена на loopback transport, **не live NIM**. Размерность 3.5/8B в NIM matrix — 2048, а в HF config/pooling и hosted reference — 4096: фактический endpoint нужно проверять отдельно, конфликт нельзя разрешать предположением. Веса не скачивались, Nemotron inference не выполнялся, рабочий Qwen не переключался.

## Режим поиска и индексация

Без явного `fusion` конфигурация выбирает **`"semantic-only"`**: только cosine, без вызова FTS-поиска и fusion; `SearchResult.score` — фактическое косинусное сходство, отображаемый процент не является вероятностью правильного ответа. Фильтр проекта сохраняется. Отсутствующий embedder или ошибка модели не подменяются словесной выдачей. FTS sidecar может существовать для явных legacy-режимов, но `semantic-only` его не опрашивает.

Явные `"rrf"` и `"vector-primary"` сохраняют прежнее поведение и шкалу. Для чисто словесного поиска без embedder выберите `"fusion": "rrf"` явно. Профили и проекты не объединяются. Для перехода с build.3 добавьте точную запись mapping и выберите `"fusion": "semantic-only"`; patcher сам не перезаписывает конфиг.

Автоматических проверок совместимости индекса, миграций и переиндексации не добавлено. При смене модели, размерности или **формата документа** пользователь сам управляет `/session-reindex`. Старый индекс Google, созданный без document-префикса, не преобразуется автоматически. У текущего Qwen document-префикс остаётся пустым: исправление только вопроса не требует пересчитывать документы той же модели. Не смешивайте векторы разных моделей только потому, что их размерность совпадает.

## Применение

```bash
# Code — сохранить stock config/index
python patches/session-search-profile/apply.py --agent-dir "<CODE_PROFILE_DIR>" --runtime-only --apply
# Task — использовать профильные config/index/sources
python patches/session-search-profile/apply.py --agent-dir "<TASK_PROFILE_DIR>" --apply
```

С тем же режимом доступны `--check` и byte-exact `--restore`. Check: `patched` (exit 0), `stock`/`previous-patched`/`published-patched`/`released-patched`/`build3-patched` (exit 1), unknown/unsupported (exit 2). Исторические состояния — root/timer без display, последующий display patch и build.2 без новых prefix/ranking изменений — различаются по полным точным bytes всех файлов, не marker. Unknown/mixed main/worker, чужой режим и другая версия отвергаются до writes. Verified backups всех `REL_FILES` с hash receipt пишутся под выбранным профилем; immutable store не меняется. Interrupted mixed writes требуют verified backup recovery.

## Мастер настройки и обновление прежнего конфига

`/session-embeddings-setup` читает весь существующий JSON, показывает точные строки/роль и сохраняет изменяемые поля поверх него. Неизвестные будущие поля, `fusion`, `sync`, roots, размерность, endpoint и остальные embedder-настройки не теряются из-за частичного сохранения. Отмена до save ничего не записывает. Для нового ID мастер просит две буквальные строки и подтверждение; API `inputType` задаётся явно в JSON. После изменения — `/reload`.

При обновлении build.3 **не заменяйте свой конфиг публичным примером**: сохраните endpoint, ключ, модель, размерность, roots и остальные поля; добавьте нужную запись `embedder.modelPrefixes` и измените только выбранный режим на `semantic-only`. Installer сохраняет существующие config files, а package patcher не дописывает в них каталог. Без обязательной записи поиск сообщит об ошибке настройки. Новую конфигурацию можно создать из безопасного примера; Code и Task настраиваются раздельно. Не запускайте `/session-reindex` ради этого перехода при прежнем Qwen document-формате.

## Конфигурация и данные

Task сохраняет `<TASK_PROFILE>/session-search/{config.json,index}`, `sessions` и `sessions-archive`. Project `localPath` не меняется. Config `sessionDir/archiveDir` имеет приоритет; default roots учитывают `PI_SESSION_DIR`, затем `PI_CODING_AGENT_SESSION_DIR`, и archive `PI_SESSION_ARCHIVE_DIR`. Extra roots разрешены и indexer, и reader.

Индексы и Polza embedding config остаются на прежних путях. Производный display summary обновляется на чтении из сохранённой session, не через изменение source JSONL или vectors. **Не выполнять forced `/session-reindex` ради самого обновления.** Не переносить чужие sessions/index и не менять model/dimensions попутно. Единственное целевое переключение режима описано выше; действующий конфиг не перезаписывается patcher-ом. Package restore не возвращает преобразованные upstream индексы; исходные session files не трогаются.

До рабочего обновления освободите index writers и сохраните verified recovery snapshot. Полезный JSON с векторами остаётся на месте, missing legacy FTS IDs восстанавливаются локально при load. Если прежний writer уже опустошил JSON, нужен проверенный непустой snapshot: patch сам не возвращает потерянные vectors. Не удалять stores и не запускать массовый платный reindex как замену recovery.

## Проверка

Текущий repair проверяет no-HOME paths и round trip, scan coverage/сохранность, legacy FTS ID coverage и reader после собственного sync. Прежние display cases (cwd с дефисом, отсутствующий cwd, одинаковые main/worker и старый summary) сохранены. Фактические synthetic, independent и working-runtime результаты разделены в [release notes](../releases/pi-1.4.0-build.2.md), не предполагаются из описания patch.

`python patches/session-search-profile/tests/test_runtime.py`: mode/restore/refusal и реальный timer settlement. Native synthetic smoke: отдельные Code/Task workers стартуют и закрываются; собственные sessions/archive/extra roots ищутся и читаются, чужой путь и symlink escape отклоняются. Synthetic FTS проверка не подтверждает paid hybrid backend; live-provider evidence указывается отдельно в release notes.

Tools/commands остаются `session_search`, `session_list`, `session_read`, `/session-sync`, `/session-reindex`, `/session-embeddings-setup` и `session-history`. Reinstall стирает patch — примените снова и перезапустите Pi. Полный context/session text может быть приватным: raw receipts вне Git.

Новые no-HOME/data-preservation regressions: `python -B -m unittest discover -s patches/session-search-profile/tests -p "test_*.py" -v`. Locked Node, peer entry `SESSION_SEARCH_TYPEBOX` и private temp root — по [patch README](../../patches/session-search-profile/README.md#проверка-и-данные). Выполняются настоящие handlers в main/worker/affected TS, но Pi registry/UI — fixture. Недоступный существующий root проверяется реальным native `ENOTDIR`; native permission-denied не заявляется. Loopback fixture embeddings не подтверждают live semantic retrieval, real SDK lifecycle или личную историю.

`test_embedding_contracts.py` проверяет текущие exact mapping, отказ неизвестным/неполным записям, literal empty, все четыре Nemotron, role-aware HTTP без двойного префикса, прямой endpoint, чистый cosine/проектный фильтр/no FTS/error и preserving save. `test_regression.py` выполняет реальные пути форматирования документов/вопросов Qwen/Google/API-role в main/worker/affected source и сохранение полей мастера. Сетевой ответ синтетический, не подтверждение доступности моделей у провайдеров. `test_embedding_prefixes.py` сохраняет frozen build.3 поведение для exact historical transition, не спецификацию текущего formatter.

Текущая [build.4 приёмка](../releases/pi-1.4.0-build.4.md): 17 адресных методов на pinned runtime и независимое source review приняты до установки; затем normal Code/Task SDK, настоящий Code search rank1/32,1%, сохранение 1293 исходных vectors и verifier0/0. Task имеет собственную конфигурацию, но пустой индекс; качество Task retrieval не заявляется. Результаты build.2/build.3 сохранены отдельно, не переименованы в новую полную runtime/model матрицу.
