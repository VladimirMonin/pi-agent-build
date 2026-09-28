# pi-serena 0.9.16: скрытие двух неработающих инструментов

Целевая связка:

```text
@bacnh85/pi-serena 0.9.16
serena-agent 1.7.0
Python backend: Pyright
```

Wrapper регистрирует 20 инструментов, но два не работают:

- `serena_check_onboarding_performed`: удалён в Serena 1.7; onboarding теперь режим агента;
- `serena_find_implementations`: Pyright не объявляет `implementationProvider`, поэтому LSP возвращает `-32601`.

Patch не подменяет их другими инструментами, а убирает ложные capabilities из tool surface. После применения остаётся 18 инструментов.

## Использование

```powershell
python .\patches\serena-tools\apply.py `
  --agent-dir "$HOME\.pi\agent" --check
python .\patches\serena-tools\apply.py `
  --agent-dir "$HOME\.pi\agent" --apply
```

Ожидаемый verdict:

```text
ALREADY PATCHED
```

Откат:

```powershell
python .\patches\serena-tools\apply.py `
  --agent-dir "$HOME\.pi\agent" --restore
```

Откат возвращает stock tool surface, но не делает отсутствующие backend capabilities рабочими.

Pristine-файл в Git immutable; apply его не создаёт и не меняет. Runtime-backups находятся под профилем `.pi-agent-build-backups/serena-tools`. Любое расхождение с точным stock/canonical state завершается отказом. После обновления wrapper/Serena/Pyright требуется повторный capability audit.
