# pi-memory 1.5.0: Windows spawn, порядок реплик и русский embedder

Поддерживаемая версия: `@samfp/pi-memory@1.5.0`.

## Четыре исправления

### Windows spawn

Stock-пакет запускает дочерний `pi` через `spawn("pi", ..., shell:false)`. На Windows глобальный npm предоставляет `.cmd`-shim, который такой вызов не запускает. Patch использует текущий `process.execPath`, `PI_AGENT_BUILD_NPM_PREFIX` от launcher и реальный `cli.js` Pi.

### Правильное сопоставление реплик

Stock-пакет ведёт два независимых массива user/assistant messages и сопоставляет их по индексу. При tool turns, ошибках или неполных ответах пары смещаются. Patch сохраняет session-local упорядоченный поток `pendingTurns` и строит consolidation input по реальному порядку.

Важно: `pushTurn` обязан находиться внутри `index_default` рядом с pending state. Ранняя версия patch размещала helper в module scope и падала на `agent_end`; простого `node --check` недостаточно.

### Настройки выбранного профиля

Stock-пакет всегда читает `~/.pi/agent/settings.json`. Patch строит путь к `settings.json` из `PI_CODING_AGENT_DIR`, поэтому Task-only запуск использует настройки Task-профиля. Общий `~/.pi/memory/memory.db` не переносится.

### Русскоязычный локальный embedder

Stock-пакет считает embeddings моделью `Xenova/all-MiniLM-L6-v2` — англоязычной. На русских фактах она даёт плохую разделимость: перефразированный запрос часто ближе к постороннему факту, чем к нужному, а порог `SEMANTIC_THRESHOLD = 0.25` пропускает почти весь шум. Patch заменяет модель на `Xenova/paraphrase-multilingual-MiniLM-L12-v2`.

Модель остаётся локальной (offline, без API-ключа), сохраняет **384 измерения** и mean pooling, поэтому существующие векторы и порог остаются валидными — reindex не требуется. На контрольном наборе (12 русских фактов, 8 перефразированных запросов) точность top-1 выросла с 4/8 до 7/8.

## Использование

```powershell
python .\patches\memory-windows-runtime\apply.py `
  --agent-dir "$HOME\.pi\agent" --check
python .\patches\memory-windows-runtime\apply.py `
  --agent-dir "$HOME\.pi\agent"
```

У patcher нет отдельного `--apply`: запись выполняется при отсутствии `--check`/`--restore`.

Применить к обоим профилям. Допустимый итог `--check`:

```text
verdict: RUNTIME-SAFE
```

Контракт exit code: `0` — canonical patch уже применён; `1` — byte-exact stock или byte-exact previous canonical patch требует применения; `2` — fatal/unknown/marker-shaped drift, автоматическая запись запрещена.

## Проверки

```powershell
node .\patches\memory-windows-runtime\tests\test-memory-pushturn.mjs `
  "$HOME\.pi\agent\npm\node_modules\@samfp\pi-memory\dist\index.js"
node .\patches\memory-windows-runtime\tests\test-memory-pairing.mjs
node .\patches\memory-windows-runtime\tests\test-memory-embedder.mjs `
  "$HOME\.pi\agent\npm\node_modules\@samfp\pi-memory\dist\index.js"
```

`test-memory-embedder.mjs` подтверждает выбор мультиязычной модели, 384d, mean pooling, отсутствие сетевых вызовов в `embed()` и неизменность порога.

`test-memory-runtime-scope.mjs` выполняет настоящий одноразовый запрос модели. Он не входит в бесплатную автоматическую проверку и запускается только владельцем осознанно.

## Откат

```powershell
python .\patches\memory-windows-runtime\apply.py `
  --agent-dir "$HOME\.pi\agent" --restore
```

Patcher сверяет SHA-256 stock-файла и отказывается перезаписывать неизвестное состояние.

## После обновления

Повторить `--check` для Code и Task. Не применять stock `1.5.0` patch к новой версии без нового анализа.
