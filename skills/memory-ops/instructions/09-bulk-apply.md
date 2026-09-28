# Режим 🧱 Массовое применение: lanes → plan → apply

> АГЕНТ: ЧИТАЙ ЭТОТ ФАЙЛ ЦЕЛИКОМ. Lanes только читают; запись выполняют проверенные скрипты после общего dry-run и подтверждения.

Когда: сотни записей, независимые домены/проекты или machine-actionable plan. Итог: lane plans вне публичного пакета и [completion report](../reports/report-completion.md).

## 1. Reachability и бюджет

Создать консистентный snapshot и измерить estimate/real block через probe. До деления на lanes зафиксировать unreachable, крупные co-expanding domains, lessons per slug и truncation.

## 2. Деление на lanes

- Facts разделяются по непересекающимся key prefixes.
- Lessons — по непересекающимся `project` values.
- Балансировать по символам, не количеству строк.
- Lane выполняет SELECT и пишет только свой plan в локальный `runtime/plans/`.
- Один key/id не может принадлежать двум lanes.
- Lane не судит весь store и не применяет изменения.

## 3. Контракт плана

Facts:

```markdown
### G<n>
KEEP KEY: <key>
НОВОЕ ЗНАЧЕНИЕ: <точное значение одной строкой>
ВОШЛО: <полный список keys; перенос строк разрешён>
ЧТО СОХРАНЕНО: <paths/flags/numbers/versions>
УДАЛИТЬ: <keys>
```

Lessons:

```markdown
### LR<n>
ПРОЕКТ: <value или NULL> · ТИП: negative=0|1 · КАТЕГОРИЯ: <category>
ГОТОВЫЙ ТЕКСТ УРОКА: <точный текст одной строкой>
ВОШЛО: <полный список UUID; перенос строк разрешён>
ЧТО СОХРАНЕНО: <identifiers/numbers/paths>
УДАЛИТЬ: <UUID>
```

Все поля обязательны и идут в точном порядке. Fenced/substring headings, 💀-группы без полного контракта, неизвестные строки, mixed backticks и дубликаты блокируют весь план. Чистое удаление оформляется отдельным явно подтверждённым планом, а не «пропускаемой» группой.

## 4. Сведение lanes

Проверить disjointness программно. Сводка каждой lane: records/chars было → станет, merge groups, delete candidates, plan path, один главный риск. Содержимое реальных записей не переносить в публичный отчёт.

## 5. Dry-run

```bash
node scripts/apply-facts.mjs runtime/plans/facts.md --db=<memory.db> --prefix=<domain>.
node scripts/apply-lessons.mjs runtime/plans/lessons.md --db=<memory.db>
```

Dry-run анализирует встроенный стабильный snapshot с WAL и не открывает source SQLite. Проверить missing/stale targets, KEEP/delete conflicts, prefix guard, owner count и 100% token coverage. Исправить plan, не отключать проверки; `--min-coverage=0` запрещён.

## 6. Owner decision

Показать точные owner rows отдельно. Без owner override они исключаются из apply. После отдельного согласия CLI получает `--owner-override`; для итогов сохраняется `source=user`.

## 7. Apply

1. Создать и проверить backup рабочей БД.
2. Повторить clean dry-run на том же плане и DB state.
3. Добавить `--apply` (и только при необходимости подтверждённый owner override).
4. Script сначала захватывает `BEGIN IMMEDIATE`, затем перечитывает plan и повторяет source/scope/preservation/owner guards внутри одной транзакции.
5. Missing/stale/malformed группа блокирует весь plan; partial apply и «пропустить группу» запрещены.
6. При ошибке транзакция откатывается; продолжать следующую lane только после диагностики и нового dry-run.

## 8. Проверка

- read-back всех KEEP/new rows;
- delete targets отсутствуют/soft-deleted по контракту;
- source/project/category/negative сохранены;
- substance tokens покрыты;
- fact reconciliation N/N;
- post-probe на свежем snapshot показывает реальный бюджет.

Честно сообщить «still truncated», если лимит всё ещё превышен.

## Gate

- [ ] Snapshot и probe выполнены до lanes.
- [ ] Lanes disjoint и read-only.
- [ ] Plans находятся в ignored runtime state.
- [ ] Формат блоков соблюдён, wrapped lists распознаны, дубликатов и fenced copies нет.
- [ ] Чистые удаления вынесены в отдельное owner decision; пропускаемых групп нет.
- [ ] Dry-run не создал файлов и сохранил byte-identical `db`/`-wal`/`-shm`.
- [ ] Owner list подтверждён отдельно либо исключён.
- [ ] Backup проверен.
- [ ] Apply транзакционный, guards повторены после `BEGIN IMMEDIATE`, self-check выполнен.
- [ ] Read-back, N/N и post-probe выполнены.
- [ ] Runtime log содержит только ids/counters.
