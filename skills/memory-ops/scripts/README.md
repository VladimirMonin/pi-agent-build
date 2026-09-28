# Скрипты memory-ops

> АГЕНТ: ЧИТАЙ ЭТОТ ФАЙЛ ЦЕЛИКОМ до запуска любого скрипта.

Все пути к БД задаются явно: `--db=<path>`. Скрипты не вычисляют домашний каталог и не печатают пути, prompts, содержимое записей или protected tokens.

## Общая модель безопасности

1. `apply-facts`, `apply-lessons`, `patch-entries` и `inject-probe` сначала получают стабильную byte-копию `db` + `-wal` двумя совпадающими чтениями. Исходная SQLite БД не открывается даже read-only: dry-run оставляет `db`, `-wal` и `-shm` byte-identical.
2. Snapshot открывается только во временном каталоге; локальный `-shm` SQLite создаёт там. Повреждённый или нестабильный snapshot блокирует операцию.
3. Без `--apply` mutating scripts только валидируют snapshot и печатают обезличенные счётчики. Они не создают manifest или журнал.
4. При `--apply` target открывается сразу через `BEGIN IMMEDIATE`. Затем внутри транзакции заново читаются и строго разбираются plan/manifest, повторяются scope, missing/stale, preservation и owner guards. Состояние source rows обязано совпасть со snapshot.
5. Любая ошибка в любой группе откатывает весь plan. Partial apply и пропуск «плохих» групп запрещены.
6. Любой rewrite/delete/rename `source=user` блокируется, пока вместе с `--apply` не передан `--owner-override`. Owner provenance итоговой merge-записи остаётся `user`.
7. `--owner-override` означает, что владелец отдельно увидел точный план и явно согласился; это не флаг обхода ошибки.
8. Изменение fact value/key обнуляет `embedding`, если колонка присутствует. Следующая штатная индексация должна построить embedding заново.
9. Перед apply создай и проверь внешний backup. Встроенный snapshot — изоляция анализа, а не recovery backup.

## Probe

```bash
node scripts/inject-probe.mjs --db=<path> --estimate
node scripts/inject-probe.mjs --db=<path> --cases=<cases.json> --estimate
```

Probe создаёт согласованный временный SQLite snapshot и считает консервативную структурную оценку: все leaf values плюс нижнюю границу выбранных доменов и уроков по project slug. Поле `prompt` в cases сохраняет формат сценария, но reachability по prompt намеренно не моделируется. Probe не принимает `--plugin`, не импортирует сторонний код и не обещает точное совпадение с runtime-инъекцией.

Probe сам включает активный WAL в стабильный временный snapshot. Он не исполняет код plugin, не принимает plugin path и выводит только агрегированные структурные счётчики.

`cases.json`:

```json
[
  {"cwd":"C:/workspace/example","prompt":"покажи рабочие предпочтения"}
]
```

## Строгий merge-план фактов

Раздел должен встретиться ровно один раз как точная строка `## Группы слияния фактов`. Fenced copies, дополнительные слова в heading, неизвестные строки, повторные группы/KEEP/source/delete keys, пустые значения и смешанное backtick-оформление блокируют весь plan. Поля идут ровно в указанном порядке:

```markdown
## Группы слияния фактов

### G1
KEEP KEY: `demo.domain.keep`
НОВОЕ ЗНАЧЕНИЕ: точный текст результата с FLAG_X и 42
ВОШЛО: `demo.domain.keep`, `demo.domain.old`
ЧТО СОХРАНЕНО: FLAG_X, 42
УДАЛИТЬ: `demo.domain.old`
```

`KEEP KEY` обязан входить в `ВОШЛО`; `УДАЛИТЬ` — явное подмножество `ВОШЛО` без KEEP. Скрипт удаляет только перечисленное в `УДАЛИТЬ`: неявного «удалить все ВОШЛО» нет. Каждый protected identifier/path/flag/number/version из исходных values обязан присутствовать в результате и в `ЧТО СОХРАНЕНО` byte-exact: регистр, Unicode representation, знак mantissa/exponent и форма числа значимы. Кроме того, значимые слова и все односимвольные лексемы каждого исходного value должны встречаться в результате в том же регистре и порядке; отрицание не считается стоп-словом. Потеря, перестановка или изменение блокирует весь plan.

```bash
node scripts/apply-facts.mjs plan.md --db=<path> --prefix=demo.domain.
node scripts/apply-facts.mjs plan.md --db=<path> --prefix=demo.domain. --apply
```

## Строгий merge-план уроков

Раздел — ровно одна точная строка `## Слияние уроков`. У каждого блока обязательны все поля в фиксированном порядке:

```markdown
## Слияние уроков

### LR1
ПРОЕКТ: demo · ТИП: negative=0 · КАТЕГОРИЯ: general
ГОТОВЫЙ ТЕКСТ УРОКА: RULE_A и RULE_B используют TIMEOUT 42
ВОШЛО: <uuid-a>, <uuid-b>
ЧТО СОХРАНЕНО: RULE_A, RULE_B, TIMEOUT, 42
УДАЛИТЬ: <uuid-a>, <uuid-b>
```

UUID в реальном плане должны быть canonical UUID. `УДАЛИТЬ` — явное подмножество `ВОШЛО`; только эти уроки получают `is_deleted=1`. Все входы должны существовать и быть активны. `project`, `negative`, `category`, owner provenance и все protected tokens обязаны сохраниться. Coverage всегда 100%; `--min-coverage=0` и любое значение кроме `1` отвергаются.

```bash
node scripts/apply-lessons.mjs plan.md --db=<path>
node scripts/apply-lessons.mjs plan.md --db=<path> --apply
```

## Точечные правки

`patch.json`:

```json
{
  "renames": {"demo.old.key":"demo.new.key"},
  "facts": {"demo.fact":"сокращённый текст с сохранённым FLAG_X"},
  "lessons": {"00000000-0000-4000-8000-000000000001":"сокращённое правило с FLAG_X"}
}
```

```bash
node scripts/patch-entries.mjs patch.json --db=<path>
node scripts/patch-entries.mjs patch.json --db=<path> --apply
```

Manifest — непустой JSON object только с `renames`, `facts`, `lessons`. Duplicate JSON members на любом уровне, пустые values/keys, rename chains, занятые targets и пересечение rename с fact patch блокируют весь manifest. Patches обязаны быть короче, сохранять protected tokens byte-exact и сохранять значимые слова и все односимвольные лексемы каждого source в исходном регистре и порядке, включая отрицание.

## Полная процедура apply

1. Сформируй точный plan/manifest и проверь, что он не содержит секретов.
2. Запусти dry-run против рабочей БД; скрипт сам анализирует стабильный snapshot с WAL.
3. Исправь любую ошибку. Не удаляй поля и не ослабляй preservation guard.
4. Покажи владельцу точный план. Получи отдельное согласие для `source=user`.
5. Создай внешний recovery backup и проверь его открытие.
6. Запусти `--apply` (и только при подтверждении `--owner-override`). Любая stale/missing/owner/preservation ошибка означает новый dry-run с новым планом.
7. Прочитай все targets и delete markers из той же БД; сверь source facts N/N.
8. Повтори probe. Запиши только identifiers и counters в `runtime/work-log.md` по [шаблону](../templates/work-log.example.md).
