# Memory1.6: runtime, scope и automatic vector recall

Exact `@samfp/pi-memory@1.6.1` поддерживается единым [patcher](../../patches/memory-windows-runtime/README.md).

Сохраняются четыре runtime fixes: Windows Node/настоящий CLI выбранного npm prefix, session-local ordered turns, profile settings из `PI_CODING_AGENT_DIR`, session ID из `sessionManager.getSessionId()`. Последний привязывает lessons к сессии; source facts upstream остаётся `consolidation`.

[Scope/aliases/целые записи](memory-injection.md) перенесены на1.6. Automatic injection использует upstream hybrid/RRF search с configurable embedder, а не stock FTS-only injector. Ephemeral context hook остаётся upstream: повторная инъекция при tool continuation, без записи в system prompt/history/consolidation. `injectionMode`, `embedding`, profile aliases и остальные настройки сохраняются.

## User/custom lifecycle

В начале нового run patch очищает pending recall до любых early returns или поиска. Непустой user prompt получает новый block; custom/пустой prompt/error не наследуют прежний и не ищут по system prompt. Внутри одного user-run context/tool continuation сохраняет block. Session start/before-switch тоже сбрасывают его. Для explicit recall в служебных Goal/Intercom продолжениях доступен `memory_search`.

Fresh Pi1.3.0 SDK + patched Memory1.6.1: synthetic Code/Task проверили эту последовательность, включая реальную ошибку поиска в принадлежащей fixture SQLite, и прежние Windows/profile/session-ID/scope/ordered-turns contracts. Это local mock evidence, не новый paid canary. Модели и рабочие данные не менялись.

## Модели и данные

- Консолидация: неизменённый `polza-memory/deepseek/deepseek-v4.1-flash`.
- Recall facts: Polza `qwen/qwen3-embedding-8b`,1024d, upstream openai-compatible backend.
- Session Search использует свой независимый embedder/config/index.

Xenova1.5 и его timeout patch больше не используются. До изменения vectors сделана одна consistent SQLite backup API-копия вне Git. Facts/lessons/events не удаляются. Старые384d vectors не сравниваются с новыми1024d; upstream backfill постепенно заменяет missing/wrong-dimension vectors после нового session start. Это не обещание немедленного полного reindex личной БД. При смене модели на другую с теми же dimensions старые vectors нужно отдельно перестроить: равная длина не означает одинаковое пространство.

## Проверка и применение

```text
python patches/memory-windows-runtime/apply.py --agent-dir <PROFILE_DIR> --check
python patches/memory-windows-runtime/apply.py --agent-dir <PROFILE_DIR>
python patches/memory-windows-runtime/apply.py --agent-dir <PROFILE_DIR> --restore
```

Exit0 — canonical;1 — exact stock требует apply;2 — refusal. Apply/restore сохраняют прежний bundle в выбранном профиле, unknown/mixed state не перезаписывается. Restore возвращает stock1.6, но не откатывает vectors/settings. Reinstall стирает patch.

Native SDK mock checks Both проверили scope/aliases, automatic vectors, ephemeral hook, ordered consolidation, Windows Node/CLI/profile и session ID; платный Polza canary проверил русский paraphrase без keyword match на synthetic facts. Commands/scope: [build.6](../releases/pi-1.0.4-build.6.md).

Полный перезапуск открытых Code/Task выполняет владелец; старые процессы сохраняют старые closures. Consolidation prompt передаётся child через `-p` и виден локальным наблюдателям process command line. Не используйте секреты как memory/test fixtures.
