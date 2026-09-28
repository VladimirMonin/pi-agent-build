# memory-ops

> АГЕНТ: ЧИТАЙ ЭТОТ ФАЙЛ ЦЕЛИКОМ.

Безопасная публичная редакция навыка для аудита и обслуживания SQLite-памяти фактов и уроков. Это рабочий процедурный пакет, а не учебный курс.

## Гарантии безопасности

- у каждого скрипта обязательный `--db=<path>`; пользовательские пути не зашиты;
- `apply-facts`, `apply-lessons` и `patch-entries` — dry-run по умолчанию; анализ выполняется на стабильной временной копии main DB + WAL, исходные `db`/`-wal`/`-shm` не открываются и остаются byte-identical;
- apply захватывает `BEGIN IMMEDIATE` до повторной проверки plan/source, а malformed/missing/stale/lost-token группа откатывает весь план;
- удаление, переименование или rewrite строк `source=user` дополнительно требуют `--owner-override`; owner guard повторяется внутри транзакции;
- probe делает консервативную структурную оценку на временном snapshot, включает все leaf values, не моделирует prompt reachability и не исполняет plugin-код;
- protected tokens сохраняются byte-exact; значимые слова и все односимвольные лексемы каждого source должны сохраниться в исходном регистре и порядке, включая отрицание; пустые values запрещены, embedding изменённого fact/key сбрасывается;
- примеры отчётов полностью синтетические;
- реальные журналы хранятся только в игнорируемом `runtime/`.

## Требования

- Node.js с `node:sqlite` (рекомендуется Node 22+);
- SQLite-база со схемой `semantic`/`lessons` для рабочих операций;
- внешний способ консистентного backup перед `--apply`.

## Быстрый старт

```bash
node scripts/inject-probe.mjs --db=/path/to/memory.db --estimate
node scripts/apply-facts.mjs /path/to/plan.md --db=/path/to/memory.db
# После просмотра dry-run, backup и подтверждения:
node scripts/apply-facts.mjs /path/to/plan.md --db=/path/to/memory.db --apply
```

Если план затрагивает `source=user`, обычный `--apply` будет отклонён. После отдельного подтверждения владельца:

```bash
node scripts/apply-facts.mjs /path/to/plan.md --db=/path/to/memory.db --apply --owner-override
```

Полная процедура начинается в [SKILL.md](SKILL.md). Форматы планов и команды — в [scripts/README.md](scripts/README.md).

## Проверка

Из корня репозитория:

```bash
node --check skills/memory-ops/scripts/apply-facts.mjs
node --check skills/memory-ops/scripts/apply-lessons.mjs
node --check skills/memory-ops/scripts/patch-entries.mjs
node --check skills/memory-ops/scripts/inject-probe.mjs
node --check skills/memory-ops/scripts/lib/safety.mjs
node --test tests/memory-ops/security.test.mjs
```

Тесты создают только временные SQLite fixtures.

## Лицензия

MIT — см. [LICENSE](LICENSE).
