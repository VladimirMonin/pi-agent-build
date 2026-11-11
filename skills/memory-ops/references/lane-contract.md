# Lane contract (bulk work helpers)

A lane is a bounded, read-only helper that analyses **one exported slice** of
the memory store and writes **one plan file**. It never sees the database and
never decides anything for the owner. The orchestrator slices, briefs,
collects, validates and applies.

## Why slices, not the database

Read-only by declaration is a promise; read-only by construction is a fact.
A lane receives a slice file produced by `scripts/export-lanes.mjs` and writes
one plan file — there is no code path from a lane to a mutation. This also
keeps lane helpers usable in runtimes that cannot be given database access at
all.

## Формат плана — ЕДИНЫЙ диалект (не изобретать!)

Полки одного прогона писали в шести диалектах, и применители молча выпустили
290 блоков из 400. Поэтому образец ниже — единственный разрешённый вид.
Запрещено: `НОВОЕ:` (только `НОВОЕ ЗНАЧЕНИЕ:`), `УРОК:`/`ГОТОВЫЙ ТЕКСТ:` (только
`ГОТОВЫЙ ТЕКСТ УРОКА:`), `= ВОШЛО` и «вошедший» в УДАЛИТЬ (только явный список),
метаданные в заголовке `###`, листовые имена ключей без полного пути, строки,
обёрнутые целиком в backticks. Каждый вызов записи ≤700 символов, чанк 3–5
блоков. Валидатор и применители теперь РУГАЮТСЯ на любой нераспознанный блок —
конвертер не должен понадобиться.

```
### G1
KEEP KEY: `project.example.topic`
НОВОЕ ЗНАЧЕНИЕ: одна строка, полное значение
ВОШЛО: `project.example.old_a`, `project.example.old_b`
ЧТО СОХРАНЕНО: пути/числа/версии/флаги
УДАЛИТЬ: `project.example.old_a`, `project.example.old_b`
```

## Lane brief (template)

```
Slice file: <path to your lane-N dump>       (records assigned to you, nobody else)
Plan file:  <path to lane-N-apply.md>        (your only write; append chunks to it)
Format:     contract in instructions/09-bulk-apply.md, Step 3 — VERBATIM markers
Style:      keys in one style across all lanes (backticked or bare, same everywhere)
Rules:      💀-blocks go to the plan only, never applied; lists may wrap lines;
            "ЖДЁТ/⚠️" title marks a block that must NOT be applied silently;
            plans are written as UTF-8 files via file tools (never shell echo)
Reply:      short cap only — status, was → becomes in characters, number of
            groups, number of 💀/🕰️, plan path, one risk
```

## Chunking (timeout survival)

Default helper lifetimes (~30 min) kill a lane that tries to emit a whole plan
in one breath. Instead:

- analyse and write the plan in **chunks of 3–5 blocks per call**, appending to
  the plan file after each chunk — the file is the durable state;
- number blocks continuously (G1…Gn / LR1…LRn) and never rewrite written
  chunks;
- if a lane dies mid-plan, **resume the same helper** with "finalise now" (its
  context survives), or hand the plan file to a fresh helper and continue
  numbering from the highest block already on disk. Never re-analyse what is
  already written.

## Footer checklist (every plan file ends with it)

- blocks written: G = n, LR = m;
- the whole slice is accounted for — every record is KEEP / consumed by a
  merge / 💀-candidate / listed under «ЖДЁТ»;
- key style used (backticked or bare);
- list of «ЖДЁТ» blocks;
- one known limitation of this plan.

## Balance and disjointness

The orchestrator balances lanes by **characters**, not record counts, and
makes them disjoint (facts by key prefix, lessons by `project`). A lane asked
to judge "the whole store" is a lane that will invent overlap — slices only.

## What a lane must never do

- open or write the database (its toolset should not include this at all);
- edit another lane's plan or "fix" the format of a finished one;
- delete anything, including proposing deletions outside the plan format;
- apply its own plan — applying is the orchestrator's, after owner approval.
