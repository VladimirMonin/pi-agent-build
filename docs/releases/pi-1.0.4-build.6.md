# Pi1.0.4 build.6 — Memory1.6

Date: 2026-10-07. Tag: `pi-v1.0.4-build.6`.

## Scope

Exact `@samfp/pi-memory@1.6.0` установлен Code/Task. Pi1.0.4, Serena Agent1.7.0, остальные выбранные версии и Background Tasks disabled не менялись. Goal X settings/load order, auth, sessions и существующие private настройки сохранены; добавлен только нужный `memory.embedding`.

Rebase patch: четыре runtime fixes (Windows Node/CLI/prefix, ordered session-local turns, profile settings, real session ID), scope/aliases/section quotas/целые записи и automatic upstream hybrid/RRF recall. Новый context hook остаётся ephemeral; `embedding`/`injectionMode` сохраняются. Старый Xenova backend, timeout patch и installer warm-up удалены. Version/body/hash guards принимают только exact stock1.6 или canonical; drift/mixed/unknown отказывают.

Memory embedder: существующий Polza `qwen/qwen3-embedding-8b`,1024d, upstream openai-compatible config. DeepSeek-консолидация `polza-memory/deepseek/deepseek-v4.1-flash` неизменна. Session Search config/index независимы.

## Evidence: command / source / scope

- `python <private-root>/prepare.py`: candidate Code13/Task10 extensions, errors0/warnings0/fetch0; selected exact install и patch checks PASS.
- `node tests/sdk/memory-smoke.mjs <sdk-root> <synthetic-root> code|task`: real Pi SDK + synthetic SQLite/local mock embedder PASS Both. Проверены automatic vector recall, fact/lesson scope и aliases, ephemeral tool continuation без system/history/consolidation injection, lexical `agent_end`, ordered transcript, реальный Windows Node child через выбранный prefix со **synthetic CLI**, profile model и session ID на сохранённом lesson. Это не paid DeepSeek consolidation.
- `python <private-root>/install-live.py`: actual installed Code/Task1.6 PASS; settings diff только selected version/embedding; остальные versions, auth/model/Goal settings и sampled patch bytes сохранены. Fresh installed payload loading13/10, errors0/warnings0/fetch0.
- `node <private-root>/live-paid.mjs`: **installed module + real Polza + synthetic facts**, русский paraphrase без keyword match автоматически recalled; scope/aliases и ephemeral continuation PASS.2 successful embedding requests (один batch трёх synthetic facts и один query); исходный неверный seed endpoint дал404 и был исправлен. Личная БД не provider fixture, personal reindex не запускался.
- `node patches/memory-windows-runtime/tests/test-memory-{pushturn,pairing,embedder,sessionid,injection,settings-path}.mjs <dist>`: focused structural/projection checks PASS.
- `python patches/session-search-profile/tests/test_runtime.py`:3/3 PASS (canonical/refusal/restore и retained Session Search timer).
- `powershell -File tests/scripts/run-tests.ps1`:24/24 PASS.
- `powershell -File scripts/verify.ps1 -RepositoryOnly -Profile Both`:0 errors/0 warnings. `scripts/safety-check.ps1 -Scope Both`: PASS; public diff reviewed.

## Data and remaining boundaries

Одна consistent SQLite backup API-копия сделана до переключения и хранится вне Git вместе с receipts. Facts/lessons/events не удалены. Старые384d не сравниваются с1024d; upstream backfill постепенно обновляет missing/wrong-dimension vectors при новых sessions. Немедленный полный personal reindex **не заявляется**. Одинаковая размерность разных моделей не означает одинаковое embedding space; такая смена требует отдельного rebuild.

Полностью перезапустите Code/Task: открытые процессы сохраняют старый code/embedder. Их принудительно не закрывали. Restore package не восстанавливает SQLite/config; сохранённая DB-копия отдельна. Visual Inspector TUI/editor/OS clipboard и live DeepSeek consolidation не повторялись; предыдущий scoped evidence применим только к неизменённым границам.

Предыдущий mini-release: [build.5](pi-1.0.4-build.5.md). Следующий этап — итоговое согласование документов; новых инструментов в этот scope не добавлено.
