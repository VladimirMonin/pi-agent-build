# Mode 🧬 Consolidation drift

When: reviewing what the **auto-consolidation** wrote on our behalf. This is the
pi-specific mode — on pi, memory is written by a background model as well as by
the agent, so a class of records exists that never passed a human filter.

Report format — `reports/report-audit.md` (drift rows marked 🧬).

## Why this mode exists

`@samfp/pi-memory` runs consolidation at session boundaries and writes facts
and lessons with `source: consolidation`. Those records:
- were never confirmed by the user;
- may be inferences, summaries, or paraphrases rather than stated facts;
- can conflict with records the user wrote (`source: user`).

When the user manually saves through `memory_remember`, the tool forces
`source: user` — so there is no way for the agent to *create* a consolidation
record, only to review, rewrite, or delete one.

## Steps

### Step 1. Select candidates
Get all records with `source: consolidation`:
- facts — from `memory_search` results / the injected block, or the DB directly;
- lessons — `memory_lessons`, filter `source`.

If needed, query the DB for the full set:
```
python -c "import sqlite3; db=sqlite3.connect(r'<home>/.pi/memory/memory.db');
print(*db.execute(\"select key,source,confidence from semantic where source='consolidation'\"),sep='\n')"
```

### Step 2. Classify each candidate
For every `consolidation` record ask:
1. **Is it true now?** Verify with tools (`ls`, `grep`, `read`, `git`).
2. **Is it a fact or a snapshot?** A snapshot gets rewritten/date-stamped, not
   kept as-is.
3. **Does it contradict a `user` record?** The user record wins; the
   consolidation one is corrected or deleted.
4. **Does it duplicate a skill or an existing record?** → 💀/🔁.
5. **Would the user endorse it as written?** If unsure, propose a rewrite.

### Step 3. Never prune blindly
A `consolidation` record can be the *only* trace of a real decision. Deletion is
the last resort; preference order is:
1. **rewrite** from the verified source (upsert, `source` becomes `user`);
2. **merge** into a related record;
3. **delete** only when proven wrong, duplicated, or derivable.

Never touch `source: user` records on the grounds that they "look like"
inference — that is the owner's word.

### Step 4. Lessons from consolidation
Auto-generated lessons are the most expensive class: **all lessons are injected
on every turn**. Audit them first by count and size. A vague or duplicated auto
lesson is worth deleting even if harmless.

### Step 5. Proposal and confirmation
Show the user a table: id/key, `source`, classification, proposed action
(rewrite / merge / delete), evidence. Await explicit "yes" per item.

### Step 6. Execute
Strict order: rewrite/merge (upsert) first, delete last. Then the completion
report and a line in `journal/work-log.md`.

## Gate before the report

- [ ] All `source: consolidation` records selected (facts and lessons)
- [ ] Each verified with tools; snapshots identified
- [ ] Contradictions with `user` records resolved in favour of the user record
- [ ] Preference order applied: rewrite → merge → delete
- [ ] No `source: user` record touched
- [ ] Auto-generated lessons audited by count and size first
- [ ] Proposal table + per-item confirmation obtained
- [ ] Execute: rewrite first, delete last; completion report; work-log line