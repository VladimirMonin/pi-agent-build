# Pi 1.4.0 build.3 — смысловой поиск и query-формат памяти

Дата: 2026-10-25. Тег: `pi-v1.4.0-build.3` (аннотированный). Предыдущий выпуск: [Pi 1.4.0 build.2](pi-1.4.0-build.2.md).

## Состав и изменение

Exact pins не менялись: **Pi 1.4.0 / Node 25.8.1 / npm 11.11.0**, Polza **0.2.2**, Session Search **1.6.0**, Memory **1.6.1**; Code **15**, Task **12** верхнеуровневых пакетов. [Runtime lock](../../manifests/runtime.lock.json), [packages lock](../../manifests/pi-packages.lock.json), [внешние инструменты](../../manifests/external-tools.lock.json).

- **Session Search:** раздельные model-specific `documentPrefix`/`queryPrefix`, включая явные пустые строки. Поддержаны правила шести описанных моделей/вариантов OpenAI, Qwen и Google; неизвестные имена остаются raw. Смысловое cosine ранжирование (`vector-primary`) стало default без вызова FTS arm. Явный `fusion: "rrf"` сохраняется; без embedder остаётся keyword fallback. [Точная таблица, backend-ограничения и конфигурация](../fixes/session-search.md#правила-документов-и-вопросов).
- **Memory:** только общий `searchMemory` форматирует Qwen3-Embedding query; то же исправление действует в `memory_search` и automatic recall. Документы, batch/backfill, FTS query, Memory RRF и консолидация не меняются. Необязательный `memory.embedding.queryPrefix` допускает собственную точную строку или `""`. [Контракт](../fixes/memory.md#query-only-формат-qwen).
- Оба изменения встроены в существующие guarded patchers. Добавлено распознавание точных предыдущих canonical bytes; unknown/mixed/version guards, backup/check/apply/no-op/restore сохранены. Новый индексатор, compatibility registry, migration или автоматический reindex не добавлены.

У текущего Qwen document-prefix пустой: исправление вопроса не требует пересчитывать прежние документы той же модели. Для другого семейства смена **document**-формата может требовать отдельно управляемого пользователем reindex; старые Google vectors не преобразуются автоматически. Автовставка инструкций конкретным Polza/LM Studio backend не подтверждена — при подтверждённом серверном форматировании используйте пустой клиентский override.

## Проверенный результат

Платформа свежей проверки — **Windows 11 x64**, Node **25.8.1**. Проверки перекрываются и не складываются в новую полную матрицу.

| Граница | Результат и область |
|---|---|
| Search source | Независимый scoped ACCEPT; 17 авторских unittest methods. Настоящие source/main/worker factory/transport bodies, model prefixes и overrides, semantic-first/явный RRF; external I/O synthetic. Не доказательство доступности всех шести моделей у провайдера |
| Search replay | Сохранённый точный query vector дал target rank1 в source/main/worker × all-projects/project. Шесть вариантов на прежнем индексе, без новых network/model calls; это offline evidence |
| Installed Search | Обычные Code/Task SDK startup и tool lifecycle. Прежний контрольный запрос через настоящий `session_search` нашёл нужную сессию **на rank1 из1293**. Task history осталась пустой. Исторический top25 FAIL build.2 не переписан; один удачный запрос не оценивает качество всего архива |
| Memory source | Независимый ACCEPT: 12 behavioral cases PASS. Тот же тест на точном прежнем raw-query canonical: 3 safeguard PASS /9 целевых FAIL. Два unittest methods включают эти сценарии и guarded state/backup/restore matrix; шесть прежних Node checks и четыре composition/timer methods прошли отдельно |
| Installed Memory | После установки свежие обычные Code/Task SDK startup без extension errors, actual main-model selections сохранены. В Code один собственный временный факт через product tools записан, найден, попал в настоящий automatic context-hook и tool continuation, не в session history; product removal и отсутствие записи подтверждены |
| Memory provider | **3 успешных запроса**, HTTP200/1024d: один raw document и два prefixed query через существующий Qwen8B provider. Других embedding requests в наблюдаемом Memory transport не было. Main/consolidation LLM в этой рабочей проверке не вызывалась; стоимость не измерялась |
| Рабочая установка | Обновлены только два принятых patch-среза в Code/Task, без package reinstall. Штатный `verify.ps1 -Profile Both` и patch checks: **0 failures /0 warnings**. Memory settings/auth/models/AGENTS byte witnesses сохранены; Main/Goal X/Trace/MCP policies не переопределялись |

В рабочем Search-конфиге Code отдельно изменён только ранее явный `fusion: "rrf"` на `vector-primary`; Task уже использовал смысловой режим. Остальные поля Search config, исходные sessions/IDs/vectors сохранены. Это целевая настройка данной установки, **не** обещание, что patcher переписывает существующее предпочтение RRF у всех пользователей.

Консистентная SQLite online backup и прежние bundles сохранены приватно до рабочего изменения. Сам Memory patcher не пишет БД/settings; только контрольный факт создавался и удалялся штатными tools. Ручной/массовый backfill или reindex не запускался. Неизменённые общие Pi/Polza/Trace/Context7/координационные результаты прежних выпусков переиспользуются в исходной применимой области, не называются свежими.

## Установка и откат

Основной вход — [INSTALL_FOR_AGENTS](../../INSTALL_FOR_AGENTS.md). Source ZIP — описание сборки, **не offline runtime**. При уже установленных exact pins не переустанавливайте все пакеты ради этого исправления: проверьте исходное известное состояние и выполните нужный preserving tail по [workflow](../pi-upgrade-workflow.md#рабочая-установка-короткое-продолжение-не-повтор-installer).

- Search: Code — `--runtime-only --apply`, Task — `--apply`; [команды и режим](../fixes/session-search.md#применение). Существующий явный RRF сохраняется: для смыслового режима меняйте только `fusion` на `vector-primary`.
- Memory: [apply/check/restore](../../patches/memory-windows-runtime/README.md#применение); `--check` должен вернуть `runtime-safe`. Restore возвращает byte-exact stock1.6.1, не откатывает пользовательские данные/настройки.
- До замены освободите фактических runtime/index writers и сохраните verified private recovery. После собственного обновления полностью перезапустите старые Pi-сессии; публикация не требует снова закрывать уже проверенные новые Code/Task.

Не выполнять forced `/session-reindex` ради query-only Qwen repair. Модель, размерность, credentials, индексы и настройки Goal X не меняются попутно. [Восстановление данных](../state-migration.md).

## Поставка и ограничения

Release поставляет `pi-agent-build-1.4.0-build.3-source.zip` через `git archive` точного принятого commit и `SHA256SUMS.txt`. Ни личные profiles/auth/БД/сессии, ни установленный runtime/модели/кеши/raw receipts не входят. Лицензионные notices сохранены; Memory provenance уточнён до настоящего 1.6.1 tarball/pristine hash. Верхнеуровневые pins не означают bit-for-bit transitive reproducibility. Build.2 tag/notes/Release не перемещаются; npm/PyPI publication не выполняется.

Повторяемые release-gates: repository verifier, schemas/syntax/relative links, public tree+staged safety и selective diff/committed-byte checks. Аннотированный тег ставится на последний проверенный commit с чистым working tree; branch/tag/Release/assets читаются повторно после публикации.

Не заявляются новая macOS/Linux или visual TUI приёмка, полная live model/embedding/consolidation matrix, общий recall всех запросов, OS containment или новая WVM/Context7 проверка. Их неизменённое прежнее evidence сохраняет исходный scope. Установленный формат и один удачный контрольный результат не гарантируют поведение непрозрачных aliases или серверное форматирование.
