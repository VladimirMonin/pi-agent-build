# pi-memory 1.6.1: runtime, lifecycle и автоматический scoped recall

Поддерживается только `@samfp/pi-memory@1.6.1`, pristine SHA-256 `9517f79582b2ff71e510289c0e6d912744b3dc8a867aaa52758df371bd41891f` и canonical output. Неизвестные версии, mixed/marker-shaped изменения не перезаписываются.

## Что меняет patch

- Windows: child запускается текущим Node через настоящий Pi `cli.js` выбранного `PI_AGENT_BUILD_NPM_PREFIX`, не через `.cmd` shim.
- Session-local `pendingTurns`/`pushTurn`: консолидация сопоставляет реальные User/Assistant turns; helper остаётся в lexical scope pending arrays.
- Settings выбранного `PI_CODING_AGENT_DIR`, включая upstream `embedding` и `injectionMode`; DeepSeek-консолидация не меняется.
- Session ID из `ctx.sessionManager.getSessionId()`; source сессии получают lessons (facts upstream сохраняет как `consolidation`).
- Facts/lessons scope, приватные `memory.factProjectAliases`, section quotas и бюджет 8000 символов из целых записей.
- Automatic injection вызывает upstream `searchMemory`: configurable embedder, hybrid/RRF, diagnostics и dimension-aware backfill. Stock1.6 automatic injection использует только FTS; patch возвращает vector recall.

Upstream ephemeral `context` hook сохранён: память доступна в tool continuation, но не добавляется в system prompt, session history или consolidation transcript.

Для Pi user/custom lifecycle block сбрасывается **в начале каждого нового run**, до проверки store/settings/prompt и до поиска; также сбрасывается на session start/before-switch. Только непустой `messageType:user` запускает свежий recall. Custom, пустой prompt и ошибка поиска не наследуют предыдущий block; `systemPrompt` не используется как search query. Внутри одного user-run block сохраняется между context/tool продолжениями. В служебных Goal/Intercom продолжениях при необходимости вызывайте явный `memory_search`. Это политика сборки, не универсальное требование SDK.

Upstream1.6.1 добавляет диагностику AWS credential_process; внешние embeddings уже были доступны в1.6.0. Rebase не меняет provider/model/dimensions и не разрешает backfill/reindex рабочих данных. Старый Xenova backend и его timeout patch удалены.

## Применение

```powershell
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>" --check
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>"
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>" --restore
```

Без `--check`/`--restore` выполняется apply. Exit: `0` canonical; `1` pristine требует apply; `2` неизвестное состояние/ошибка. Backup bundle создаётся внутри выбранного профиля; restore возвращает byte-exact stock1.6.1, **не откатывает SQLite или настройки**.

## Backend и данные

В личных Code/Task выбран Polza `qwen/qwen3-embedding-8b`,1024d через upstream `memory.embedding`. Консолидация остаётся `polza-memory/deepseek/deepseek-v4.1-flash`. Без embedding config работает keyword fallback, не полноценный русский vector recall.

До смены живых vectors нужна согласованная SQLite backup API-копия вне Git. Старые384d и новые1024d **не сравниваются**; upstream backfill постепенно обновляет missing/wrong-dimension vectors. Одинаковая размерность не доказывает одинаковое embedding space: при такой смене нужен отдельный rebuild. Не удаляйте facts/lessons/events и не копируйте keys в public fixtures. Patcher сам SQLite/settings не изменяет. Полностью перезапустите старые Pi-сессии перед использованием новой версии.

## Проверки

Structural: `test-memory-{pushturn,pairing,embedder,sessionid,injection,settings-path}.mjs <patched-dist>`; lifecycle/drift: `python patches/session-search-profile/tests/test_runtime.py` и Windows script regressions.

Native SDK с synthetic SQLite и local mock embedder (без платной LLM):

```text
node tests/sdk/memory-smoke.mjs <sdk-root> <fresh-synthetic-root> code <synthetic-code-profile>
node tests/sdk/memory-smoke.mjs <sdk-root> <fresh-synthetic-root> task <synthetic-task-profile>
```

Четвёртый аргумент задаёт уже установленный synthetic profile; без него fixture использует `<root>/code|task`. Windows fixture до imports/settings I/O проверяет фактический profile/case и ancestors существующими private-root/Git/reparse guards. Девять sacrificial controls отказывают без product imports/settings access; independent valid Code/Task runs восстановили settings byte-exact. Это не OS sandbox и не native POSIX proof. Runtime case directory должен быть fresh. Native sequence проверяет user recall → тот же block в tool continuation → custom без поиска/block → пустой prompt и реальный SQLite search failure без старого block → свежий user recall → session-switch reset. Рабочие профили не fixtures. Native smoke проверяет automatic recall, aliases/scope, ephemeral hook, ordered consolidation и настоящий Windows Node child со synthetic CLI, не DeepSeek provider. Real Polza Russian paraphrase canary описан в [build.6](../../docs/releases/pi-1.0.4-build.6.md).
