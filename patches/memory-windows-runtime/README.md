# pi-memory 1.5.0: Windows spawn и порядок реплик

Поддерживаемая версия: `@samfp/pi-memory@1.5.0`.

## Два исправления

### Windows spawn

Stock-пакет запускает дочерний `pi` через `spawn("pi", ..., shell:false)`. На Windows глобальный npm предоставляет `.cmd`-shim, который такой вызов не запускает. Patch использует текущий `process.execPath` и реальный `cli.js` Pi.

### Правильное сопоставление реплик

Stock-пакет ведёт два независимых массива user/assistant messages и сопоставляет их по индексу. При tool turns, ошибках или неполных ответах пары смещаются. Patch сохраняет session-local упорядоченный поток `pendingTurns` и строит consolidation input по реальному порядку.

Важно: `pushTurn` обязан находиться внутри `index_default` рядом с pending state. Ранняя версия patch размещала helper в module scope и падала на `agent_end`; простого `node --check` недостаточно.

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

## Проверки

```powershell
node .\patches\memory-windows-runtime\tests\test-memory-pushturn.mjs `
  "$HOME\.pi\agent\npm\node_modules\@samfp\pi-memory\dist\index.js"
node .\patches\memory-windows-runtime\tests\test-memory-pairing.mjs
```

`test-memory-runtime-scope.mjs` выполняет настоящий одноразовый запрос модели. Он не входит в бесплатную автоматическую проверку и запускается только владельцем осознанно.

## Откат

```powershell
python .\patches\memory-windows-runtime\apply.py `
  --agent-dir "$HOME\.pi\agent" --restore
```

Patcher сверяет SHA-256 stock-файла и отказывается перезаписывать неизвестное состояние.

## После обновления

Повторить `--check` для Code и Task. Не применять stock `1.5.0` patch к новой версии без нового анализа.
