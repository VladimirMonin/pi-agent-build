# Журнал изменений

Все значимые изменения сборки документируются здесь. Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/). Старые накопленные записи `Unreleased` ниже сохранены без переатрибуции новому выпуску.

## [pi-v1.5.2-build.10] — 2026-11-11

- MCP-адаптер **5.3.2 → 7.0.1** (оба профиля): приёмка переведена с удалённого в 6.0.0 инструмента `mcpScript` на встроенный **codemode**; мёртвые ключи `scriptMode`/`scriptSkill`/`settings.jev` вычищены из конфигов (на 7.x конфиг с ними грузится с уведомлением). Выигрыш 7.0.1: фикс имён инструментов >64 символов для OpenAI-совместимых шлюзов (наш Polza-путь) и быстрый старт. `ensure-context7.mjs` переведён на новую версию: exact-guard обновлён, **все пять внутренних функций адаптера сверены с установленным кодом 7.0.1 — контракт не изменился** (факты внесены в compatibilityNote). Встроенный `builtin:mcp` остаётся выключенным (единственный владелец `/mcp`; ядро не даёт legacy SSE fallback).
- **Транспортные заглушки (compat-мидлвари WVM `server.py`) не трогались** (требование владельца) и приняты живьём ОБОИМИ транспортами отдельными кейсами: legacy SSE `127.0.0.1:7558/sse` и streamable `127.0.0.1:7558/mcp` — каждый реальным вызовом `wvm_settings_schema` (схема 51 192 симв.). Дополнительная проба подтвердила: SSE-диалект НЕ проходит через `/mcp` (детерминированная остановка инициализации) — ровно как предупреждали наши доки. Context7 — живая цепочка discovery → resolve-library-id → query-docs через codemode свежей сессией (реальная документация useState).
- Проверки: установка 0/0 в оба профиля (версия 7.0.1 подтверждена обратным считыванием), `ensure-context7 --check` PASS, `context7-defaults` 15/15 + обе конфигурационные стадии installer-тестов, `verify.sh`/`verify.ps1` Both raw 0/0, полный прогон лаборатории **25/25** (включая новый контракт «adapter 7.x codemode»). Артефакты: `ОБРАТНАЯ СВЯЗЬ\SLICE3-mcp-log.md`, `ОБРАТНАЯ СВЯЗЬ\SLICE3-transport-report.md`.

## [pi-v1.5.2-build.9] — 2026-11-11

- Патч `pi-cbm-011` **снят** (вшит апстримом в pi-cbm 2.0.0 — обе половины: `format:"json"` и нормализация таблиц `cols/rows`/`groups[].rows`): убран из манифеста, notices, доков и тестов; исторический каталог `patches/pi-cbm-011/` с immutable store и guard сохранён для отката (откат — только парой 1.2.1 × 0.11.x). Пара **pi-cbm 1.2.1 → 2.0.0** + **codebase-memory-mcp 0.11.0 → 0.12.1** закреплена в manifests и шаблоне Code, установлена в живой профиль штатным `pi install` + npm-инструментом. Peer-зависимости pi-goal-x сверены с установленным пакетом (compatibilityNote).
- Проверки (реальные прогоны, артефакты субагентов): verify Both raw 0/0 (оба варианта); полный прогон `tests/scripts/run-tests.ps1` — **24/24** (было 9/15: три точечных фикса ТЕСТОВОЙ обвязки — ожидание exit-3 readiness вместо отказа по контракту P44/§6, изоляция ключа Polza по всем трём scope, фикстура `embedder.ts`+docs; продукт не трогался, гейты не ослаблялись); **живой schema smoke 6/6 независимой свежей сессией** (search_graph/resolve_symbol/групповая строка/read/trace_path/detect_changes/negative control); CBM Lens — слушает только `127.0.0.1:9749` (loopback подтверждён netstat). Артефакты: `ОБРАТНАЯ СВЯЗЬ\SLICE2-cbm-log.md`, `SLICE2-smoke-report.md`.
- Тестовая обвязка навыка памяти перенесена на новые скрипты: **13/13** (охрана — секреты/UTF-8/симлинки/ссылки — сохранена полностью; путь-гигиена ограничена журналами с обоснованием). Независимые прогоны зафиксировали 11 дефектов СКРИПТОВ навыка (D1/D5 класса потери данных) — переданы владельцу: `ОБРАТНАЯ СВЯЗЬ\TEST-memory-ops-port.md`.
- Пины среза №1 в `tests/scripts/run-tests.ps1` обновлены (subagents 0.88.0 / goal-x 0.34.1 / intercom 0.18.1) — просчёт среза №1 закрыт.

## [pi-v1.5.2-build.8] — 2026-11-11

- Пакеты (срез №1 по [разведке 2026-11-11](docs/recon/2026-11-11-plugins.md)): pi-ollama-cloud **0.12.1 → 0.13.1** (актуальный каталог после списаний моделей Ollama, новый API баланса `/api/balance`), pi-subagents **0.79.1 → 0.88.0** и pi-intercom **0.17.1 → 0.18.1** строгой парой (скрытые межпакетные контракты idle-wake/session-identity обязаны меняться вместе), pi-goal-x **0.32.3 → 0.34.1** (порядок загрузки до intercom сохранён; peer range сверен с установленным пакетом: `@earendil-works/* >=1.4.0 <2.0.0`, `typebox ^1.3.11`, Node `>=22.19.0`), @juicesharp/rpiv-todo **2.12.0 → 2.15.0** (фикс краша восстановления сессии с битым снимком задач). Установка: штатный `pi install` exact-sources, 10/10 в оба профиля; порядок `goal-x` раньше `intercom` сохранён (D.8).
- Дефолты моделей (решение владельца): Code → `ollama-cloud/deepseek-v4-pro:0813`, Task → `ollama-cloud/deepseek-v4.1-flash:1017` (закреплённый снимок 10/17; оба имени сегодня указывают на одну сборку `567966df89fe`, гарантия неизменности — только у тега), `defaultThinkingLevel: "xhigh"` (максимум из объявленных моделями; уходит провайдеру как `reasoning_effort: "max"`). Служебные маршруты консолидации/embedding/поиска не менялись. Решение с доказательствами: [docs/notes/model-defaults.md](docs/notes/model-defaults.md).
- Навык обслуживания памяти: включена обновлённая ревизия `pi-memory-ops` из универсальной папки навыков (по решению владельца — как есть, без правок содержимого; LICENSE/.gitignore сборки сохранены). Документация установки: профиль Pi — автоматически installer'ом, универсальная папка `~/.agents/skills/pi-memory-ops` — командой копирования для Windows/macOS ([INSTALL_FOR_AGENTS](INSTALL_FOR_AGENTS.md)).
- Опыт установки этого среза: `install.ps1 -Apply` упёрся в занятый нативный модуль `pi-tui\win32-platform.node` (EBUSY при живых процессах Pi); прерванная установка ядра оставила неполный вложенный `openai` (старт субагентов падал с «Cannot find module … turns.mjs»). Восстановлено точечным npm-ремонтом `openai@7.19.0` внутри каталога ядра; пакеты профилей поставлены штатным `pi install`. Известное ограничение: полная переустановка ядра возможна только при закрытых процессах Pi.
- Проверки (реальные прогоны): `verify.sh --profile Both` и `verify.ps1` — **failures=0 warnings=0**, оба raw exit 0; патчи 5/5 PASS. Канарейки моделей: `v4-pro:0813` PASS в Code и Task, `v4.1-flash:1017` PASS в Code (на Task тег блокирован известной болезнью пакета «неполное обновление каталога», лечение — `pi update --models`; модель доказана живым ответом). Пробы стыков D.1–D.8: D.2 запись `polza-cost` (`origin=background-subagent`, `runId`, полная разбивка токенов; при длинном выводе запись также полная (D.6b: 77 979 токенов, `runId` пробы; точечный кейс «обрезка × расходы» — NOT VERIFIED)); D.3 доставка `sent→delivered→received→injected` за 3 мс, ровно один ответ, без «Agent is already processing»; D.4 round-trip саб↔руководитель; D.5 headless-ходы чистые (активная Goal-часть — TUI); D.6 честная ошибка «Response was truncated» (семантика 0.88.0); D.7 NOT TESTED (TUI); D.8 парность/порядок ✓. Навык: синтаксис скриптов 9/9; старая проверочная обвязка 5/21 (написана под прежние скрипты — приведение отдельным срезом).

## [pi-v1.5.2-build.7] — 2026-11-10

- Ядро Pi **1.4.0 → 1.5.2** закреплено в `runtime.lock.json` и обоих профильных templates (`lastChangelogVersion`): владелец обновил рабочую установку на месте, принят поток багфиксов upstream core. Node 25.8.1 / npm 11.11.0 и все пакеты профилей не менялись.
- Bash-проверки/установщик на Windows перестали врать: CRLF от Windows-python через git-bash пайсы портил последнее поле строк manifest. Ложные «patcher missing» (fatal exit 2 в `apply-patches.sh`), ложный «pi-polza release tag object differs» при совпадающем теге/коммите и ложный WARN по пути `codebase-memory-mcp` устранены: `manifest_packages`, `patches_for_profile` и внешние циклы manifests отдают байт-точные LF-строки (`tr -d '\r'`; в inline-циклах применён существующий `manifest_lines_lf`).
- Проверки: `verify.sh --profile Both` — **failures=0 warnings=0** (83 PASS); `verify.ps1` — **failures=0 warnings=0**; `apply-patches.sh --profile Both --mode Check` — все патчи PASS (8 PASS-строк: 5 в Code и 3 в Task; trace-ru и session-search patched, memory `runtime-safe`, serena-tools, pi-cbm-011). Живая канарейка `check-main-model.mjs` PASS на обоих профилях (по одному запросу; Task — та, что падала по P40). Живой smoke Code-профиля: memory (инъекция + гибридный recall), subagents (2 прогона), intercom, MCP (4 сервера, ленивые), Serena 1.7.0, граф кода. Живой старт Task — канарейка уровня SDK, полный TUI-прогон NOT TESTED.
- Приёмка исправлена (обратная связь P40–P46): `check-main-model.mjs` вызывает `initTheme` (канарейка Task больше не падает с «Theme not initialized»), self-run guard нормализует пути (нет молчаливого exit 0), отчёт содержит текст ответа и детали ошибок расширений; `verify.ps1`/`verify.sh` помечают «ещё не настроено» (креденшл/PATH) как WARN, `check-memory-model.mjs` различает exit 3 (не настроено) и exit 2 (плохо поставлено). P44: креденшл-переменная маршрута памяти передаётся в проверочный процесс явно (Process/User/Machine scope, `Get-CredentialEnvOverrides`) — результат не зависит от запускающего shell; `install.ps1` при незаданном ключе продолжает установку с пометкой «credential NOT TESTED», а не прерывает. P45: сверка канарейки терпима к регистру, пробелам/подчёркиваниям и хвостовым знакам (offline-тесты; живой повтор канарейки в этом срезе не запускался). P46: верификаторы проверяют конфиг session-search (новый `check-session-search-config.mjs`, точная запись `modelPrefixes`), установленные лаунчеры и наличие git-bash (Windows); кейс-варианты ID моделей — валидные отдельные ключи. Ограничения: полная plugin/live-provider приёмка не выполнялась, `--verbose` helper'а нет. Подробности: [заметка выпуска](docs/releases/pi-1.5.2-build.7.md).
- Документация: точные версии инструментов больше не выдаются за требование к пользователю — введено разделение на **рабочий диапазон для установки** (Node ≥ 22.19 — engines ядра Pi и `pi-session-search` 1.6.0, проверено на 24+; npm из комплекта Node, Python ≥ 3.8, uv без жёсткого пина, Git 2.x) и **lab-пины воспроизводимости** (Node 25.8.1 / npm 11.11.0 / Git 2.54.0.windows.1 / uv 0.9.27 — приёмка сборки и верификатора; расхождение не означает нерабочую установку). По замечаниям обратной связи (P01–P02). Точный runtime-гейт верификатора/установщика не менялся; смежное изменение — readiness-состояния больше не помечаются FAIL (см. выше).

## [pi-v1.4.0-build.6] — 2026-10-30

- `pi-polza` **0.3.1** закреплён опубликованным commit `878fd144fd7eebe12b34342a8eb21a2cb8b143c9` (release `v0.3.1`, tag object `a9dc20ef831a425cd0ab2e26f3a6981fb62e1691`) в manifest и обоих профильных templates. Код провайдера идентичен 0.3.0; исправлен пример установки в README, который ставил `v0.2.2` без исправлений каталога и учёта.
- Оформление выпусков приведено к принятому виду: заголовок и тело GitHub Release для `pi-polza` 0.3.0/0.3.1 и для этой сборки начинаются с одной строки-питча, содержат скриншот, разделы возможностей, установки, проверок, ограничений и лицензии.
- Проверки: `npm test` провайдера — 225 тестов, 170 прошли, 8 предсуществующих падений в `startup-native` (нет установленного SDK в checkout), 47 пропущено. Оба профиля переустановлены из опубликованного commit, `verify.ps1 -Profile Both` — `failures=0 warnings=0`, тег `v0.3.1` присутствует в установленных клонах. Сборка: safety scan PASS.

## [pi-v1.4.0-build.5] — 2026-10-30

- `pi-polza` **0.3.0** закреплён опубликованным commit `377b4e6142ae943d7eaf2d33e166139217cae543` (release `v0.3.0`, tag object `1e8fc7674e54171df5cd7342fb03b3dce60fe4db`) в manifest и обоих профильных templates.
- Каталог Polza больше не теряет модели из-за неизвестного предела ответа: на реальном снимке предлагается 298 моделей из 300 вместо 274, включая `anthropic/claude-sonnet-5.5` и `anthropic/claude-opus-5.5`. Отказ остаётся только для доказанно непригодных записей.
- Уровни рассуждений `xhigh`/`max` показываются там, где каталог их заявляет (`supported_efforts` у 85 моделей, `xhigh` у 44; `reasoning_effort` объявлен у 187). Отсутствие заявки больше не подменяется догадкой; влияние уровня на живой ответ не проверялось.
- Импорт расходов фоновых подагентов действительно включается: ответ `pi-subagents` читается из версионного конверта; `/polza-cost` показывает состояние импорта и не заявляет `complete` без него. Полученная цена сохраняется при обрыве ответа.
- Справочник метаданных: читается свежайшая копия из проекта или общая `<home>/.pi/pi-polza-cache`, запись идёт в общую.
- Проверки: `npm test` провайдера — 225 тестов, 170 прошли, 8 предсуществующих падений в `startup-native` (нет установленного SDK в checkout), 47 пропущено; офлайн-пересчёт каталога 274 → 298; release asset `pi-polza-0.3.0.tgz` опубликован. Установка на рабочую машину и её живые проверки описаны отдельно в [заметке выпуска](docs/releases/pi-1.4.0-build.5.md).

## [pi-v1.4.0-build.4] — 2026-10-25

- Session Search: обязательный exact-ID `embedder.modelPrefixes`, обе literal string-prefixes, отказ неизвестной/неполной записи до HTTP. Форматирование документов/вопросов у индексатора, общий formatter source/main/worker; providers не добавляют повторные prefixes.
- Новый default `semantic-only` возвращает фактический cosine без FTS/fusion и без скрытого lexical fallback; проектный фильтр сохранён. Явные legacy `rrf`/`vector-primary` остаются opt-in. Мастер настройки сохраняет весь существующий config и неизвестные поля.
- Четыре точных Nemotron 3/3.5 HF ID в публичном примере, раздельные NIM API-role records и optional `embeddingsEndpoint`/`input_type`. Открытые источники проверены; live Nemotron/LM Studio и OpenRouter forwarding не заявлены. Новые endpoints не включались для личной истории.
- Code/Task сначала установлены и проверены, затем обновлены docs. Normal SDK Both без extension errors, Code control rank1/1293 с cosine32,1%, все прежние1293 vectors сохранены; Task получает недостающий config того же Qwen, его собственный индекс пуст. Pinned verifier0/0. Memory, основной provider/model, package pins и пользовательские данные не мигрировались; forced reindex не запускался.
- До установки 17 адресных методов и независимое узкое ревью приняты. Exact build.3 transition/backup/no-op/restore сохранены; build.3 не переиздаётся задним числом. [Контракт, проверки и ограничения](docs/releases/pi-1.4.0-build.4.md).

## [pi-v1.4.0-build.3] — 2026-10-25

- Exact package/runtime pins сохранены. Session Search: раздельные префиксы документов/вопросов по модели и независимые overrides, включая пустые строки; semantic-first default без FTS arm, явный RRF сохранён. Контрольный installed поиск дал нужную сессию на rank1 из1293 без пересчёта исходных vectors.
- Memory: только векторный вопрос общего `searchMemory` получает Qwen3-инструкцию; необязательный `memory.embedding.queryPrefix` сохраняет точную/пустую строку. Документы, FTS, RRF и консолидация неизменны. Exact previous-state admission, backup/check/apply/no-op/restore и unknown refusal проверены.
- Code/Task обновлены до документации/публикации: normal SDK startup и штатный verifier0/0. Собственный временный факт в Code найден tool-ом и настоящим automatic context-hook, доступен в continuation, удалён через product tool с readback; три реальных Qwen1024d запроса. Main/consolidation LLM в рабочей проверке не вызывалась.
- Переиндексация/compatibility registry/migration не добавлены. Один контрольный результат не оценивает полноту архива или качество всех моделей. [Компонентные контракты и область выпуска](docs/releases/pi-1.4.0-build.3.md).

## [pi-v1.4.0-build.2] — 2026-10-24

- Версии сохранены: Pi **1.4.0**, Node **25.8.1**, npm **11.11.0**, Polza **0.2.2**, Session Search **1.6.0**, Memory **1.6.1**; manifests, installer и профильные templates не менялись.
- Session Search: native Windows без `HOME` использует системный home; file reference из поиска читается через `session_read`. Missing/unreadable source не удаляет прежние записи; доступное пустое дерево по-прежнему очищает действительно исчезнувшие сессии. Legacy FTS дополняется по отсутствующим session IDs без перезаписи vectors и существующего полного текста.
- CBM: известный полный current/previous patch body распознаётся при CRLF/LF, включая mixed endings; stock/version/unknown guards, byte-exact restore и no-op без перезаписи сохранены.
- Preserving рабочее обновление Windows, обычный Code/Task SDK startup, регистрация tools, patch checks/verifier и сохранность приняты. Основной live LLM-запрос в этом ремонте не выполнялся.
- **Известное ограничение:** фиксированный широкий semantic query дошёл до настоящего provider/SDK, но нужная сессия не вошла в top25. Сохранённое и одно свежее embedding дают ranks39/33; это не PASS точности поиска и не доказанный новый implementation defect. Без `project` scope межпроектный внутри выбранного индекса, а не гарантия нужного результата. [Проверки и ограничения](docs/releases/pi-1.4.0-build.2.md).

## [pi-v1.4.0-build.1] — 2026-10-22

- Pi **1.4.0**, Node **25.8.1**, npm **11.11.0**; exact установленный SDK family graph и оба профиля проверены. Остальные top-level версии сохранены, кроме исправленного Polza.
- `pi-polza` **0.2.2** закреплён опубликованным commit `e91b09504f7a445b477eaab77cc02d1db067a1e7` в manifest и обоих templates. Штатный сохранённый credential обеспечивает cold-start каталог без обязательного env-обхода.
- Новый `check-main-model.mjs` сверяет expected/actual provider/model и структурированный ответ новой сессии; mismatch, unavailable, error, abort и timeout дают настоящий отказ.
- Memory 1.6.1: единый exact project scope для remember/consolidation/recall, aliases и global keys сохранены; guarded переход из конкретных известных состояний без принятия unknown edits.
- Session Search 1.6.0: display использует настоящий cwd, fallback сохраняет slug; согласованы main/worker, hashes, backup и restore без массового reindex.
- Remote Context7 устанавливается по умолчанию Code/Task через adapter 5.3.2; effective loader сохраняет shared sources, пользовательский URL/auth и явный disable. Новые npm/node child boundaries используют существующую sanitization.
- Короткий [установочный вход](INSTALL_FOR_AGENTS.md), реальные launcher paths, companion links и правила affected checks/logging согласованы с PFK. [Результаты и ограничения выпуска](docs/releases/pi-1.4.0-build.1.md); рабочие auth/профили/БД/Goal X не менялись.

## [Unreleased]

### Документация установки

- Добавлен [короткий установочный вход](INSTALL_FOR_AGENTS.md) из README/AGENTS: источник и commit, fresh/update/reinstall, Windows/POSIX, Code/Task, отдельные main/consolidation/embedding/search routes, Context7 и короткая приёмка/restore.
- Исторический ручной Pi 0.87 рецепт отделён в [справку](docs/history/pi-0.87-install.md); обычная установка принятой ревизии не требует заново разрабатывать выпуск.
- Правила affected checks, переиспользования доказательств и диагностики уточнены у существующих owners по методам PFK. Целевой номер ремонта не переименовывает исторические результаты в новую runtime/live-приёмку.

### Добавлено

- Русская инструкция чистой установки Windows x64, двух профилей, exact-version packages, внешних CLI, patches и verification.
- Документация границ Code/Task, профильных и общих данных, безопасной миграции state.
- Компонентная документация всех 15 Pi-пакетов в семи тематических группах: назначение, установка, конфигурация/данные, commands/tools/skills, риски, проверка и удаление.
- Отдельные документы по `pi-polza` v0.2.0 и служебному static provider `polza-memory`.
- Конфигурация Polza embeddings `qwen/qwen3-embedding-8b` (1024 dimensions) для hybrid session search.
- Конфигурация `deepseek/deepseek-v4.1-flash` для pi-memory через core `models.json`, поскольку consolidation child запускается с `--no-extensions`.
- Runbooks шести локальных исправлений: Trace, memory, session-search, Serena, CBM и Windows spawn для ast-grep.
- `THIRD_PARTY.md` с прямыми компонентами, версиями, лицензиями, источниками и оговорками внешних сервисов.
- `THIRD_PARTY_NOTICES.md` и patch-local notices/licenses с точным file-level происхождением, опубликованными npm `gitHead` и SHA-256 vendored/modified upstream source.
- Ручная установка optional MCP servers `@upstash/context7-mcp@3.2.2`, `@brave/brave-search-mcp-server@2.0.85` и `mcp-server-fetch==2025.4.7`.
- Русскоязычный локальный embedder памяти: patch `memory-windows-runtime` заменяет англоязычную `Xenova/all-MiniLM-L6-v2` на мультиязычную `Xenova/paraphrase-multilingual-MiniLM-L12-v2` (384d, offline, без ключа) и добавляет структурный тест `test-memory-embedder.mjs`.
- Прогрев кэша embedder'а памяти: `scripts/warm-memory-embedder.mjs` скачивает модель заранее (таймаут 10 мин, 3 повтора); installer вызывает его автоматически, verifier сообщает WARN при отсутствии кэша. Учитывает разную скорость сети и 30-секундный таймаут ленивой загрузки плагина.
- Пакет `pi-goal-x@0.31.9` (MIT) в оба профиля: команды `/goal`, `/sisyphus` и автономное продолжение работы с персистентным состоянием в `<cwd>/.pi/goals/`. Собран против Pi 0.87.0, но peer range `>=0.83.0 <0.88.0` требует повторной проверки после апгрейда Pi. В манифесте и шаблонах размещён перед `pi-intercom`: обратный порядок в headless-режиме ломает `turn_end` boundary ([заметка](docs/notes/goal-x-intercom-order.md)).
- Исправление session id в консолидации памяти: patch `memory-windows-runtime` читает id через `sessionManager.getSessionId()`, так как `ExtensionContext` не содержит полей `sessionId`/`session` и stock-выражение всегда давало `session:unknown`. Добавлен структурный тест `test-memory-sessionid.mjs`.
- Раздел `docs/notes/` с заметками о поведении upstream-компонентов: `session:unknown` в консолидации памяти, квадратичный рост файлов трассировки `pi-trace-extension` (до 144 МБ на длинной сессии) и порядок загрузки `pi-goal-x` относительно `pi-intercom` (полная матрица проверок в [`docs/notes/goal-x-intercom-order.md`](docs/notes/goal-x-intercom-order.md)).

### Изменено

- Граница repeatability описана как exact top-level/version-pinned, без обещания bit-reproducibility до появления transitive locks и artifact hashes.
- Existing profile configs сохраняются по умолчанию; полная замена документирована только как явный `-ReplaceProfileConfigs` с backup и без автоматического merge.
- Profile packages устанавливаются через штатный `pi install` в sanitized child environment; Git source закреплён immutable object id и отдельно проверяется по tag object/peeled checkout.
- Memory patch учитывает `PI_CODING_AGENT_DIR` при чтении user-global settings, поэтому Task больше не зависит от Code `settings.json`; общая memory DB остаётся общей.
- Memory patch также меняет локальную модель встраивания фактов на мультиязычную (384d, mean pooling, порог `0.25` не меняется, reindex не требуется).

### Исправлено

- Навык `memory-ops` в сборке: добавлен раздел «Типовые ложные выводы». Реальный замер обязан передавать профильный `memory`-конфиг (`factProjectAliases`, `lessonInjection`) в сборщик — без него проектные факты молча отфильтровываются и регрессионный чекер даёт ложное «missing»; `--estimate` считает потенциальную стоимость, а не нижнюю границу блока; отсутствие маркера `truncated` означает целые **выбранные** строки, а не отсутствие потерь. Там же уточнено, что version-guarded патч привязан к 1.5.0, снимается `pi update`/пересборкой и требует повторного применения (версия навыка `1.0.1-public`).
- Уточнены prerequisites/runtime roles, semantics `verify.ps1`, отсутствие `update.ps1` и pending status корневого `AGENTS.md`.

### Безопасность

- Во всех примерах используются placeholders и profile-relative/user-relative пути; credentials, живые sessions, traces и memory DB не добавлены.
- Документировано, что session-search config хранит Polza key как literal, Trace/indexes содержат sensitive derived data, а runtime state переносится только зашифрованным каналом вне Git.
- Документировано, что pi-memory передаёт consolidation prompt дочернему Pi через process command line, видимую локальным monitors/администраторам/telemetry.

### Известные ограничения

- `pi-background-tasks 2.6.2` остаётся installed-disabled из-за несовместимости с system-role conversation blocks Pi 0.87.0.
- Локальные package patches нужно повторно проверять и применять после reinstall/update.
- Закреплённые top-level versions не фиксируют transitive dependency tree; release bundle требует отдельного lock/hash/SBOM шага.

## [pi-v1.0.4-build.6]

- Memory1.6 установлен Code/Task; exact rebase runtime fixes, scoped whole-record automatic upstream hybrid/RRF recall и ephemeral context-hook. Xenova/warm-up удалены.
- Polza Qwen1024d отдельно от неизменённой DeepSeek-консолидации; consistent SQLite backup вне Git. Старые384d не сравниваются с1024d, upstream backfill после restart; personal reindex не запускался.
- Native SDK Both, installed Russian real-Polza synthetic canary (2 successful requests), structural checks, regressions24/24, verifier0/0 и safety PASS. [Scope и ограничения](docs/releases/pi-1.0.4-build.6.md).

## [pi-v1.0.4-build.5]

- MCP Adapter2.36.0 → **5.1.0** Both, единственный MCP owner; existing shared config и `-builtin:mcp` сохранены.
- Actual installed native Code/Task: WVM/Context7/Fetch/Brave connect PASS; WVM schema-call PASS Both, Code Context7/Fetch/Brave calls PASS. WVM запущен `run_debug.bat` и закрыт после проверки. [Scope](docs/releases/pi-1.0.4-build.5.md).

## [pi-v1.0.4-build.4]

- Session Search1.4.3 → **1.6.0** Both: новый exact patch, explicit roots через штатный workerData, Windows-safe reader containment, initial-sync timer cleanup. Worker bundle не патчится; index/config/model/fusion сохранены, forced reindex не требуется.
- Native synthetic Code/Task workers/search/read/escape rejection PASS; real Polza hybrid canary PASS (2 embedding requests). Fresh installed loading13/10 errors0/warnings0/fetch0, regressions24/24, verifier0/0. [Scope и личная установка](docs/releases/pi-1.0.4-build.4.md).

## [pi-v1.0.4-build.3]

- Context Inspector1.1.1 → **1.3.0** в Code/Task: resize-aware overlay/paging и optional external-editor snapshot; без локального patch.
- Code Serena wrapper0.9.16 → **0.9.20**: exact rebase двух hidden tools, truthful guidance, обе immutable pristine copies с provenance. Serena Agent1.7.0/Pyright остаются.
- Both loading13/10 errors0/warnings0/fetch0; native Serena symbol и synthetic Inspector UI checks PASS; Windows regressions24/24, verifier0/0. Native visual TUI/editor/clipboard NOT TESTED. [Scope и установка](docs/releases/pi-1.0.4-build.3.md).

## [pi-v1.0.4-build.2]

### Изменено

- Только три пакета: Subagents **0.76.1**, Goal X **0.32.3**, Intercom **0.16.1**; Pi остаётся **1.0.4**. Goal X preset, картинки, Trace/MCP filters и остальные версии сохранены.
- Both candidate loading — 13/10 extensions, 0 errors/warnings/fetch; synthetic completion wake, два процесса Intercom через настоящий Windows broker и старый synthetic Goal с `nextAction` → complete — PASS. Windows script regressions 24/24; repository verifier 0/0. [Проверки и короткая установка](docs/releases/pi-1.0.4-build.2.md).

## [pi-v1.0.4-build.1]

### Изменено

- Только Pi core: exact pin **1.0.2 → 1.0.4**, без обновления плагинов, внешних инструментов и Node/npm.
- В Code/Task явно разрешены картинки для модели (`blockImages: false`), auto-resize и terminal preview (`showImages: true`, ширина 60, протокол auto).
- Core SDK local-mock на actual Pi/AI 1.0.4, repository verifier и safety scan — PASS. Полная plugin/live-provider приёмка и визуальная проверка terminal preview не выполнялись. [Scope, обновление и ограничения](docs/releases/pi-1.0.4.md).

## [pi-v1.0.2-build.3]

### Изменено

- Source-only интеграция опубликованного `pi-polza` **0.2.1**: exact commit/tag metadata обновлены вместе в manifest, Code/Task templates, synthetic installer fixtures и текущей документации. Core остаётся **1.0.2**; Goal X, фильтры Trace/MCP и skill bytes не изменены.
- Plugin исправляет однократный нативный RUB-учёт после успешного ответа Pi1.0.2 и сохраняет последний баланс с `stale` при ошибке refresh. Принятый upstream handoff: 203/203 offline checks, включая 47 native на actual installed Pi1.0.2 + synthetic SSE; audit/pack PASS. Live acceptance новой сессии сообщена владельцем, не полный background-live.
- Выпуск включает ранее добавленный `memory-ops` **1.0.1-public** без новых изменений навыка. История выше сохранена; прежний публичный build.2 не заменяется. [Release notes и ограничения](docs/releases/pi-1.0.2-build.3.md); публикация нового tag/release выполняется отдельно.
