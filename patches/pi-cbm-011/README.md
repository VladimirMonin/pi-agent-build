# pi-cbm 1.2.1 ↔ Codebase Memory 0.11.x

Целевая связка:

```text
pi-cbm 1.2.1
codebase-memory-mcp >=0.11.0,<0.12.0
```

## Дефект

CBM 0.11 изменил два контракта:

1. graph tools по умолчанию возвращают компактный `tree`, а wrapper ожидает JSON;
2. даже JSON изменился с `results: object[]` на `cols + rows` и сжатые `groups`.

Stock-wrapper молча интерпретирует корректный ответ как пустой результат. Отсутствие ошибки не означает работоспособность.

## Исправление

Адаптер в одном месте — `CbmClient.callTool()`:

- добавляет `format: "json"` семи graph tools, если caller не выбрал формат;
- переводит compact tables/groups 0.11 в legacy shape, ожидаемый `pi-cbm 1.2.1`;
- сохраняет caller-supplied format;
- отказывается работать с CBM 0.12+ до нового schema smoke-test.

## Использование

```powershell
python .\patches\pi-cbm-011\apply.py `
  --agent-dir "$HOME\.pi\agent" --check
python .\patches\pi-cbm-011\apply.py `
  --agent-dir "$HOME\.pi\agent" --apply
```

Минимальный живой критерий после `/reload`: `resolve_symbol` для известного символа возвращает ненулевой `total_candidates` и корректные location fields. Проверка только «ответ — JSON» недостаточна.

Откат:

```powershell
python .\patches\pi-cbm-011\apply.py `
  --agent-dir "$HOME\.pi\agent" --restore
```

Stock `pi-cbm 1.2.1` после отката остаётся несовместимым с CBM 0.11. Функциональный rollback требует CBM 0.8.1, отключения wrapper или новой совместимой версии.

На Windows launcher обязан задавать `CODEBASE_MEMORY_MCP_BIN` на настоящий `.exe`, а не npm shim.

Pristine store в Git immutable. Apply принимает только точный stock/canonical body, пишет backup под `.pi-agent-build-backups/pi-cbm-011` выбранного профиля и отказывается перезаписывать неизвестное состояние.
