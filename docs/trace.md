# Trace: default-off и явное включение

В **Code и Task** пакет `pi-trace-extension@0.1.16` установлен и patched, но его canonical package entry содержит `extensions: []`. Обычный запуск не загружает extension и не начинает plugin-owned tracing. Третьего профиля нет.

## Однократный opt-in в Windows

Выберите тот же существующий профиль. Для Code — `agent`, для Task — `task`; если установка использует другой Pi root, подставьте его вместо `~/.pi`.

```powershell
$profile = 'agent' # либо 'task'
$env:PI_CODING_AGENT_DIR = Join-Path $env:USERPROFILE ".pi\$profile"
$env:PI_TRACE_PYTHON = (Get-Command python -CommandType Application).Source
$trace = Join-Path $env:PI_CODING_AGENT_DIR 'npm\node_modules\pi-trace-extension\extensions\trace\index.ts'
pi -e $trace
```

`-e` явно добавляет уже установленный extension только к этому запуску; package filters и `settings.json` не меняются. Нужен настоящий установленный Python, не Windows Store alias. В интерактивной сессии `/trace` строит/открывает текущую HTML-трассу; `/trace all` — dashboard. При shutdown extension также генерирует HTML, не открывая браузер.

Для обычной сохраняемой сессии trace находится в `<agentDir>/traces/<sessionId>/`. В `--no-session` extension использует `PI_TRACE_PARENT_DIR`; без parent dir он сознательно пропускает tracing. Для synthetic headless-проверки задавайте private parent directory вне Git. Не подставляйте туда личные session files.

## Возврат off

Завершите opt-in сессию и запустите тот же Code/Task обычным способом, **без `-e $trace`**. Никакой обратной правки JSON не нужно. При переключении окружений уберите унаследованный `PI_TRACE_PARENT_DIR`, если задавали его вручную. Оба canonical templates остаются `extensions: []`.

Для SDK opt-in используется существующий `DefaultResourceLoader.additionalExtensionPaths: [traceEntry]`; в следующем loader этот список пуст. Это не новый launcher/режим.

## Проверено на Pi 1.0.2

- **Code и Task × off-before/on/off-after**: шесть реальных SDK runs и шесть реальных CLI `--print --no-session` runs, с local mock provider без внешних provider calls.
- Явный CLI `-e` проверен с установленным entry. On создаёт `events.jsonl` и `trace.html`: session start, interaction/turn/step summary и shutdown. Следующий обычный запуск снова off.
- Точные Pi/AI **1.0.2**, естественный exit 0, без forced exit и load/lifecycle errors. Canonical settings не изменились; Both installed verifier и повторный Apply NO-OP сохраняют filters.
- Холодные HF embedding downloads блокировались, memory работала в FTS fallback; это не semantic embedding acceptance. Browser opening/dashboard UI и платные реальные providers этой проверкой не подтверждены.

Raw synthetic traces/receipts остаются вне Git; исходные личные трассы не использовались.
