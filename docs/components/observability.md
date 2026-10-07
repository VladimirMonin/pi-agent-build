# Наблюдаемость

## `pi-trace-extension` 0.1.16

### Назначение

Преобразует lifecycle events Pi в локальный execution trace: append-only `events.jsonl`, single-file `trace.html` и cross-session dashboard.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:pi-trace-extension@0.1.16
python patches/trace-ru-windows-profile/apply.py --agent-dir "<PROFILE_DIR>" --apply
```

Нужен Python `3.8+`.

### Конфигурация и данные

После profile patch данные пишутся в `<PROFILE_DIR>/traces/<session-id>/`; dashboard — `<PROFILE_DIR>/traces/index.html`. `PI_TRACE_PYTHON` задаёт interpreter. В сборке patch также русифицирует UI и переводит stdout/stderr renderer в UTF-8.

### Команды, tools и skills

- `/trace` — render текущей сессии;
- `/trace all` — dashboard;
- других slash commands, tools и skills нет; `/trace-dashboard` не существует.

### Риски

Trace содержит prompts, model responses, tool args/results и может содержать secrets, не совпавшие с key-name redaction. Retention/rotation отсутствуют, файлы растут. Не публикуйте `trace.html`/`events.jsonl` без ручной проверки.

### Проверка

После `/reload` запустите `/trace` и `/trace all`, откройте HTML и убедитесь, что UI русский, а каталог принадлежит активному профилю. Patch state проверяется `--check`.

### Удаление/откат

Сначала `apply.py --restore`, затем:

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:pi-trace-extension
```

Trace data остаётся и удаляется отдельно. Подробности: [fix trace](../fixes/trace.md).

## `pi-context-inspector` 1.3.0

### Назначение

Интерактивный снимок того, что LLM видит сейчас: system prompt, tools schemas, messages и оценка распределения tokens. Он дополняет Trace: context inspector показывает текущий полный prompt, Trace — исполнение во времени.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:pi-context-inspector@1.3.0
```

### Конфигурация и данные

Конфиг и persistent data не нужны. Overlay строится из текущей session context. Оценка категорий — `chars/4`, масштабированная к provider-reported total; абсолютные значения по категориям не являются точным tokenizer count.

### Команды, tools и skills

Только `/context`: tabs Stats/System/Tools/Messages/Full; `Tab`, `/`, `n`/`N`, `y`, `q`/Esc. Overlay и PageUp/PageDown учитывают текущую высоту терминала после resize. В content tabs `e` открывает временный snapshot через `$EDITOR`; изменения snapshot не меняют session. Model-facing tools/skills нет. Команда работает только в TUI и требует хотя бы один завершённый turn для usage data.

### Риски

Tabs, clipboard и editor snapshot могут раскрыть полный system prompt, tool schemas и приватные messages. Не копируйте Full в issue/log без redaction. `$EDITOR` optional: `notepad` или `code --wait`; parser1.3 не поддерживает quoted executable paths с пробелами. Сборка не меняет EDITOR и не добавляет локальный patch.

### Проверка

После одного сообщения выполните `/context`; убедитесь, что открываются пять tabs и Tools соответствует профилю. Standalone `require.resolve('@earendil-works/pi-tui')` из package dir не является корректной проверкой: host Pi предоставляет dependency из своего дерева.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:pi-context-inspector
```

Данные удалять не требуется.
