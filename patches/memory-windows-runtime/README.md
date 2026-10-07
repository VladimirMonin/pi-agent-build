# pi-memory 1.6.0: runtime и автоматический scoped recall

Поддерживается только `@samfp/pi-memory@1.6.0`, exact pristine SHA-256 и canonical output. Неизвестные версии, mixed/marker-shaped изменения не перезаписываются.

## Что меняет patch

- Windows: child запускается текущим Node через настоящий Pi `cli.js` выбранного `PI_AGENT_BUILD_NPM_PREFIX`, не через `.cmd` shim.
- Session-local `pendingTurns`/`pushTurn`: консолидация сопоставляет реальные User/Assistant turns; helper остаётся в lexical scope pending arrays.
- Settings выбранного `PI_CODING_AGENT_DIR`, включая upstream `embedding` и `injectionMode`; DeepSeek-консолидация не меняется.
- Session ID из `ctx.sessionManager.getSessionId()`; source сессии получают lessons (facts upstream сохраняет как `consolidation`).
- Facts/lessons scope, приватные `memory.factProjectAliases`, section quotas и бюджет 8000 символов из целых записей.
- Automatic injection вызывает upstream `searchMemory`: configurable embedder, hybrid/RRF, diagnostics и dimension-aware backfill. Stock1.6 automatic injection использует только FTS; patch возвращает vector recall.

Upstream ephemeral `context` hook сохранён: память доступна в tool continuation, но не добавляется в system prompt, session history или consolidation transcript. Старый Xenova backend и его timeout patch удалены.

## Применение

```powershell
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>" --check
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>"
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>" --restore
```

Без `--check`/`--restore` выполняется apply. Exit: `0` canonical; `1` pristine требует apply; `2` неизвестное состояние/ошибка. Backup bundle создаётся внутри выбранного профиля; restore возвращает byte-exact stock1.6, **не откатывает SQLite или настройки**.

## Backend и данные

В личных Code/Task выбран Polza `qwen/qwen3-embedding-8b`,1024d через upstream `memory.embedding`. Консолидация остаётся `polza-memory/deepseek/deepseek-v4.1-flash`. Без embedding config работает keyword fallback, не полноценный русский vector recall.

До смены живых vectors нужна согласованная SQLite backup API-копия вне Git. Старые384d и новые1024d **не сравниваются**; upstream backfill постепенно обновляет missing/wrong-dimension vectors. Одинаковая размерность не доказывает одинаковое embedding space: при такой смене нужен отдельный rebuild. Не удаляйте facts/lessons/events и не копируйте keys в public fixtures. Patcher сам SQLite/settings не изменяет. Полностью перезапустите старые Pi-сессии перед использованием новой версии.

## Проверки

Structural: `test-memory-{pushturn,pairing,embedder,sessionid,injection,settings-path}.mjs <patched-dist>`; lifecycle/drift: `python patches/session-search-profile/tests/test_runtime.py` и Windows script regressions.

Native SDK с synthetic SQLite и local mock embedder (без платной LLM):

```text
node tests/sdk/memory-smoke.mjs <sdk-root> <synthetic-root> code
node tests/sdk/memory-smoke.mjs <sdk-root> <synthetic-root> task
```

Synthetic root должен содержать собственные `code`/`task` профили с установленным package. Рабочие профили не fixtures. Native smoke проверяет automatic recall, aliases/scope, ephemeral hook, ordered consolidation и настоящий Windows Node child со synthetic CLI, не DeepSeek provider. Real Polza Russian paraphrase canary описан в [build.6](../../docs/releases/pi-1.0.4-build.6.md).
