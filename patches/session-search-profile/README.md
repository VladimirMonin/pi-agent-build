# pi-session-search 1.4.3: изоляция именованного профиля

Поддерживаемая версия: `pi-session-search@1.4.3`.

Stock-пакет жёстко использует стандартные пути `~/.pi/agent/sessions` и `~/.pi/session-search`. Из-за этого именованный Task-профиль через `PI_CODING_AGENT_DIR` читает и индексирует историю Code-профиля.

Patch изменяет `src/config.ts`, `src/parser.ts` и собранный `dist/index.js`:

```text
<PI_CODING_AGENT_DIR>/sessions
<PI_CODING_AGENT_DIR>/sessions-archive
<PI_CODING_AGENT_DIR>/session-search/config.json
<PI_CODING_AGENT_DIR>/session-search/index/
```

Явные `PI_SESSION_DIR` и `PI_SESSION_ARCHIVE_DIR` сохраняют приоритет.

## Использование

Оба режима очищают timeout начального sync в `finally` при resolve/reject, сохраняя настоящий timeout. Code сохраняет stock-пути (меняется только `dist/index.js`):

```powershell
python .\patches\session-search-profile\apply.py `
  --agent-dir "$HOME\.pi\agent" --runtime-only --apply
```

Для Code используйте `--runtime-only` также с `--check` и `--restore`. Для Task (изоляция профиля + timeout cleanup):

```powershell
python .\patches\session-search-profile\apply.py `
  --agent-dir "$HOME\.pi\task" --check
python .\patches\session-search-profile\apply.py `
  --agent-dir "$HOME\.pi\task" --apply
```

Откат:

```powershell
python .\patches\session-search-profile\apply.py `
  --agent-dir "$HOME\.pi\task" --restore
```

После применения размести конфигурацию embeddings именно в:

```text
~/.pi/task/session-search/config.json
```

и выполни `/session-reindex` внутри `pi-task`.

Patcher жёстко проверяет версию, SHA-256 immutable store и byte-exact state. Принимает только stock, canonical выбранного режима и точный предыдущий Task canonical для backed-up upgrade; другой режим/смешанные/неизвестные bytes отклоняются.

Focused regression: `python patches/session-search-profile/tests/test_runtime.py` (resolve/reject/реальный timeout, cleanup, upgrade/idempotence/refusal, mode/path/restore). Pristine store в Git immutable; runtime-backups записываются под `.pi-agent-build-backups/session-search-profile` выбранного профиля. Неизвестная или смешанная структура завершается ошибкой.
