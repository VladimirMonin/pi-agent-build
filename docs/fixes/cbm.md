# CBM 0.11: адаптер формата и схемы — патч снят

## Статус: патч снят 2026-11-11

Патч `pi-cbm-011` **снят 2026-11-11**: обе половины фикса — принудительный `format:"json"` для семи graph tools и нормализация compact-таблиц 0.11 (`cols + rows`/`groups`) в legacy-контракт — вшиты апстримом в `pi-cbm 2.0.0`. Wrapper 2.0.0 нативно поддерживает CBM 0.11+: новый вызов `cli --json` со stdin, normalize таблиц и версионный gate. Локальная правка installed `src/cbm/client.ts` больше не применяется; `apply.py --check` в сборке не требуется. При любом обновлении пары pi-cbm/CBM обязателен schema smoke на непустых graph facts («ответ — JSON» недостаточно). Каталог `patches/pi-cbm-011/` (immutable store, `apply.py` c fail-closed guard) сохранён целиком как материал для отката.

## История: связка pi-cbm 1.2.1 + CBM 0.11.x

### Назначение

`codebase-memory-mcp 0.11.0` несовместим с parser `pi-cbm 1.2.1` сразу по двум причинам:

1. graph tools по умолчанию возвращают compact `tree`, а wrapper ожидает JSON;
2. даже `format:"json"` возвращает новую таблицу `cols + rows`/`groups`, тогда как wrapper helpers ожидают `results: object[]` и старые nested arrays.

Без fix helpers могут молча вернуть `0 candidates` при существующих symbols. Patch централизован в `CbmClient.callTool()`: добавляет `format:"json"` для семи upstream tools и переводит compact 0.11 schema в старый contract.

### Применение

```bash
python patches/pi-cbm-011/apply.py \
  --agent-dir "<CODE_PROFILE_DIR>" --check
python patches/pi-cbm-011/apply.py \
  --agent-dir "<CODE_PROFILE_DIR>" --apply
```

Guard узкий: ровно `pi-cbm 1.2.1`, CBM `>=0.11.0,<0.12.0`, наличие `--format` и ожидаемых anchors. `0.12+` fail-closed.

### Конфигурация и данные

Patcher меняет installed `src/cbm/client.ts`, хранит pristine copy и runtime backup. Upstream CBM binary/index DB не изменяются. На Windows launcher обязан задавать `PI_CBM_BIN` на реальный `.exe`, а не npm shim.

### Tools/команды

Правка охватывает `search_graph`, `trace_path`, `get_architecture`, `detect_changes`, `search_code`, `get_code_snippet`, `query_graph` и косвенно wrapper helpers `resolve_symbol`, `read_symbol(s)`, batch readers.

### Риски

Schema translator, применённый к неизвестной 0.12+, способен снова дать тихо неверный результат — поэтому диапазон не расширяют без live fixture. Проверка «ответ parseable JSON» недостаточна; нужны известные non-empty graph facts. Reinstall package стирает правку.

### Проверка

```bash
python patches/pi-cbm-011/apply.py \
  --agent-dir "<CODE_PROFILE_DIR>" --check
```

Ожидается `ALREADY PATCHED`. Затем на индексированном test repo:

1. `search_graph` по заведомо существующему symbol возвращает object rows;
2. `resolve_symbol` даёт `total_candidates > 0`;
3. `read_symbol` возвращает source/location;
4. `trace_path` даёт arrays callers/callees;
5. `detect_changes` на известном Git change возвращает impacted symbols.

### Удаление/откат (историческое)

```bash
python patches/pi-cbm-011/apply.py \
  --agent-dir "<CODE_PROFILE_DIR>" --restore
```

Restore возвращает stock wrapper, который с CBM 0.11 снова несовместим. Безопасный полный откат — одновременно вернуть проверенную pre-0.11 CBM либо обновить wrapper на версию с native 0.11 support и повторить smoke.

## Откат (на связку 1.2.1 + 0.11.x)

Откат выполняется только парой: вернуть пины `pi-cbm 1.2.1` + `codebase-memory-mcp 0.11.x` (оба манифеста) и применить патч заново:

```bash
python patches/pi-cbm-011/apply.py \
  --agent-dir "<CODE_PROFILE_DIR>" --apply
```

Guard патча откажет на любых других версиях — это задумано: translator проверен только на точной паре `pi-cbm 1.2.1` × CBM `0.11.x`. Детали и synthetic regression: [README патча](../../patches/pi-cbm-011/README.md).
