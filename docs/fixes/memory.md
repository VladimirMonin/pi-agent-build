# Memory: профильные settings, Windows spawn, порядок реплик, русский embedder и session id

## Назначение

Patch `memory-windows-runtime` поддерживает `@samfp/pi-memory 1.5.0`.
**Отдельный дефект инъекции** (бирки Windows, чужие факты и обрезание блока)
описан в [memory-injection.md](memory-injection.md). Исправление инъекции пока
**не входит** в переносимый patcher: см. статус перед установкой поверх
локально изменённого bundle.

Текущий patch:

- заменяет жёсткий `~/.pi/agent/settings.json` на `<PI_CODING_AGENT_DIR>/settings.json`, чтобы Task использовал свой блок `memory`/`pi-memory`;
- на Windows заменяет запуск npm `.cmd` через `spawn(shell:false)` на прямой запуск Pi CLI текущим Node, устраняя `ENOENT`;
- хранит ordered `pendingTurns` в session-local lexical scope и строит пары User/Assistant по реальному порядку, а не по двум рассинхронизированным массивам;
- заменяет англоязычную модель встраивания `Xenova/all-MiniLM-L6-v2` на мультиязычную `Xenova/paraphrase-multilingual-MiniLM-L12-v2`, чтобы семантический поиск фактов работал на русском;
- читает id сессии через `ctx.sessionManager.getSessionId()`, потому что `ExtensionContext` не содержит полей `sessionId`/`session` и stock-выражение всегда давало `session:unknown`;
- исправляет старую ошибочную patch-версию, где `pushTurn` оказался module-scope и падал на `agent_end` с `pending*Messages is not defined`.

## Применение

У этого patcher нет `--apply`: отсутствие `--check`/`--restore` означает apply.

```bash
python patches/memory-windows-runtime/apply.py \
  --agent-dir "<PROFILE_DIR>" --check
python patches/memory-windows-runtime/apply.py \
  --agent-dir "<PROFILE_DIR>"
```

Примените к обоим профилям. Patcher пересобирает canonical output из vendored pristine `1.5.0`, принимает для записи только byte-exact stock или byte-exact previous canonical patch и не перезаписывает marker-shaped/unknown/custom build. Для неизвестного состояния сначала выполните штатный reinstall пакета.

## Конфигурация и данные

Patch меняет `dist/index.js`; memory DB и сами settings не преобразует. При заданном `PI_CODING_AGENT_DIR` user-global config читается из `settings.json` активного профиля, без переменной сохраняется stock fallback `~/.pi/agent/settings.json`. На Windows путь к global Pi CLI строится от `PI_AGENT_BUILD_NPM_PREFIX`, который задают rendered launchers; fallback — `%APPDATA%\npm`. Служебный child по-прежнему запускается с `--no-extensions --no-tools --no-session`; static `polza-memory` описан отдельно.

### Embedder памяти

`@samfp/pi-memory` использует **два независимых** механизма: консолидацию фактов внешней LLM (`polza-memory/deepseek/deepseek-v4.1-flash`) и **локальный** embedder для семантического поиска по фактам. Поля для смены embedder в конфиге нет — модель зашита в `dist/index.js`, поэтому её меняет patch.

Мультиязычная MiniLM сохраняет **384 измерения** и mean pooling, поэтому старые векторы и `SEMANTIC_THRESHOLD = 0.25` остаются валидными: reindex не нужен. Модель скачивается один раз (~130 МБ) в кэш `@xenova/transformers` и работает offline, без API-ключа. Это **не** тот embedder, что использует `pi-session-search` (там Polza `qwen/qwen3-embedding-8b`, 1024d) — см. [Polza memory](../polza-memory.md).

### Прогрев кэша embedder'а

Плагин загружает модель лениво с жёстким таймаутом 30 с. На холодном кэше скачивание по медленному каналу может его превысить, и тогда плагин молча откатывается на FTS-only поиск. Скорость сети разная, поэтому модель нужно скачать заранее:

```bash
node scripts/warm-memory-embedder.mjs "<PROFILE_DIR>"
```

У каждого профиля **свой** кэш `@xenova/transformers`, поэтому прогрев делается для обоих. Helper читает id модели из пропатченного `dist`, использует таймаут 10 минут с 3 повторами и не валит установку при сбое. `scripts/install.sh --apply` вызывает его автоматически после patches; `scripts/verify.sh` сообщает `WARN`, если кэш отсутствует.

### Идентификатор сессии в консолидации

Stock-пакет берёт id сессии как `ctx.sessionId ?? ctx.session?.id`. Но `ExtensionContext` (см. `dist/core/extensions/types.d.ts`) не содержит ни поля `sessionId`, ни `session` — только read-only `sessionManager`. Оба обращения дают `undefined`, поэтому каждая консолидированная запись помечается источником `session:unknown`.

Patch читает реальный id через `ctx.sessionManager?.getSessionId?.()`, сохраняя прежние fallback'и на случай отсутствия session manager. На **факты** это не влияет — у них `source` жёстко `consolidation`; корректную привязку получают **lessons**, где `source = session:<id>`. Проверено на живом ExtensionRunner и end-to-end консолидацией: запись получает `source = session:<реальный id>`.

## Tools/команды

Интерфейс package не меняется: `memory_*` и `/memory-consolidate`. Patch касается lifecycle/consolidation internals.

## Риски

Любой reinstall package стирает правку. `node --check` недостаточен: module-scope bug синтаксически валиден. Runtime test вызывает модель и может стоить денег. Полный consolidation prompt передаётся child Pi через аргумент `-p` и виден в process command line локальным наблюдателям. Restore возвращает stock с Windows-дефектом, общей привязкой settings к Code и англоязычным embedder'ом. Смена размерности embedder'а (например, на 1024d) потребовала бы полного reindex и подъёма порога — текущий patch этого не делает намеренно.

## Проверка

```bash
python patches/memory-windows-runtime/apply.py \
  --agent-dir "<PROFILE_DIR>" --check
```

Ожидается `verdict: RUNTIME-SAFE`; этот verdict также требует marker profile-aware settings.

Структурная проверка для произвольного профиля:

```bash
node patches/memory-windows-runtime/tests/test-memory-pushturn.mjs \
  "<PROFILE_DIR>/npm/node_modules/@samfp/pi-memory/dist/index.js"
node patches/memory-windows-runtime/tests/test-memory-embedder.mjs \
  "<PROFILE_DIR>/npm/node_modules/@samfp/pi-memory/dist/index.js"
node patches/memory-windows-runtime/tests/test-memory-sessionid.mjs \
  "<PROFILE_DIR>/npm/node_modules/@samfp/pi-memory/dist/index.js"
```

Реальный ExtensionRunner smoke (платный/model-dependent):

```bash
node patches/memory-windows-runtime/tests/test-memory-runtime-scope.mjs code
node patches/memory-windows-runtime/tests/test-memory-runtime-scope.mjs task
```

Дополнительно выполните `memory_stats` и осознанный `/memory-consolidate`; отсутствие visible error само по себе не доказывает запись.

Убедитесь, что кэш модели прогрет (иначе первый семантический поиск уйдёт в FTS-only):

```bash
node scripts/warm-memory-embedder.mjs "<PROFILE_DIR>"
```

## Удаление/откат

```bash
python patches/memory-windows-runtime/apply.py \
  --agent-dir "<PROFILE_DIR>" --restore
```

Restore пишет vendored pristine `1.5.0`. После package update сначала `--check`: новый version/layout требует нового аудита, а не принудительного применения старого patch.
