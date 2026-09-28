# Serena: удаление двух мёртвых tools

## Назначение

Связка `@bacnh85/pi-serena 0.9.16` + `serena-agent 1.7.0` рекламирует два неработающих tools:

- `serena_check_onboarding_performed`: удалён из Serena; onboarding теперь agent mode;
- `serena_find_implementations`: текущий Python/Pyright backend не объявляет LSP `implementationProvider` и отвечает `-32601 Unhandled method`.

Patch скрывает эти tools из model surface, не подменяя implementations на references и не меняя Serena/worker/project config.

## Применение

```bash
python patches/serena-tools/apply.py \
  --agent-dir "<CODE_PROFILE_DIR>" --check
python patches/serena-tools/apply.py \
  --agent-dir "<CODE_PROFILE_DIR>" --apply
```

Patcher сохраняет pristine `index.ts`, затем детерминированно комментирует два `pi.registerTool` blocks. Он работает с bytes, чтобы не разрушить CRLF, и создаёт runtime backup.

## Конфигурация и данные

Правка только Code wrapper. `.serena/project.yml`, cache, memories и `serena-agent` не изменяются. Для onboarding вызывайте `serena_onboarding` и проверяйте `.serena/memories/`.

## Tools/команды

После patch остаётся 18 active `serena_*` tools. Для Python implementation search используйте `serena_find_referencing_symbols` только когда references действительно отвечают задаче; это не семантический эквивалент implementation.

## Риски

Другой backend (например JetBrains) может поддерживать implementations — тогда patch скрывает полезный tool. Wrapper/Serena быстро меняют API; version change требует нового live smoke. Применение по одному marker без pristine rebuild недопустимо.

## Проверка

`--check` должен вернуть `ALREADY PATCHED` и показать оба tools disabled. В `/context`/tool list они отсутствуют, а `serena_status`, overview, symbol, references и onboarding работают. `serena_status.pid` может меняться между requests; liveness оценивайте по успешным results/cachedAgents, не по PID.

## Удаление/откат

```bash
python patches/serena-tools/apply.py \
  --agent-dir "<CODE_PROFILE_DIR>" --restore
```

Restore byte-exact возвращает pristine wrapper и оба registrations. Делайте это только после проверки backend capabilities и upstream API. Затем `/reload`.
