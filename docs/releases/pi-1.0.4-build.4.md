# Pi 1.0.4 build.4 — Session Search 1.6.0

Release tag: `pi-v1.0.4-build.4`. Pi остаётся **1.0.4**; другие package pins не меняются.

## Изменения

Code/Task: `pi-session-search` **1.4.3 → 1.6.0**. Upstream indexing работает на Worker Thread. Exact новый profile/runtime patch сохраняет Task paths и stock Code config/index paths, передаёт roots через штатный `IndexOptions → workerData`, исправляет Windows `session_read` containment и очищает initial-sync timeout. Worker bundle не меняется. Source mirrors и compiled bundle имеют exact pristine/hash guard; неизвестное/смешанное состояние отвергается.

Config, index locations, Polza model/dimensions/fusion и session/archive files сохраняются. **Forced `/session-reindex` не выполняется.**

## Проверки

- `python patches/session-search-profile/tests/test_runtime.py`: **3/3**, включая real resolve/reject/timeout cleanup, mode/idempotence/byte-exact restore/drift refusal.
- **Native Worker, synthetic sessions**, Code и Task отдельными процессами: по1 worker started/exited; own sessions ищутся/читаются, archive/extra roots читаются; чужие paths и symlink escape отклоняются. Это FTS acceptance без paid provider.
- **Actual installed Pi1.0.4 SDK loading**: candidate и fresh live payloads — Code13/Task10, errors0/warnings0/fetch0.
- `tests/scripts/run-tests.ps1`: **24/24**. `scripts/verify.ps1 -RepositoryOnly -Profile Both -RepoRoot <REPO_ROOT>`: **0 failures/0 warnings**. Safety/diff checks перед публикацией.
- **Paid live provider, разрешён владельцем:** actual installed1.6 production index service + существующий Code config, `qwen/qwen3-embedding-8b`,1024d. Один короткий synthetic record и одна query: **2 успешных embedding requests**, hybrid result найден. Index/fixture вне Git; credentials не копируются в fixtures/logs. Личная история массово не индексировалась. Это real provider + synthetic hybrid data, не проверка всего личного архива.

Native visual TUI и semantic retrieval по всему личному архиву **NOT TESTED**. Scope не расширяется за пределы перечисленных checks.

## Личная установка

Промежуточный кандидат установлен по разрешению владельца до final publication: штатный Pi lifecycle поставил exact1.6 в Code/Task; оба режима patch применены. Assertions подтвердили сохранение других settings/package versions, существующих session-search configs, models/Goal X settings и sampled unrelated patch bytes. Fresh installed loading PASS.

Открытые Pi-сессии полностью перезапускает владелец. Не использовать полный installer, `update --all`, замену auth/settings или full reindex. Private candidate, raw receipts и provider fixture остаются вне Git.
