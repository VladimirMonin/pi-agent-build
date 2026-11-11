# Mode 🗜️ Compress

When: an entry is bloated but the topic is single (otherwise 🌀→✅ or 📦 first).
Outcome — `reports/report-completion.md`.

## Steps

### Step 1. Break down the entry
List the entry's facts one by one. Confirm the topic is genuinely single — if
not, switch to split mode (`instructions/04-split.md`).

A coherent entry in the 500–1000 character range is not a candidate for
compression "just because it is long"; cut only the fluff. Remember the
compression target is the injected block, which is capped at ~8000 characters.

### Step 2. Cut
Apply the rules from `00-shared-rules.md`:
- cut connectives ("also", "plus", "important limitations"), repeated context,
  filler words;
- cut details recoverable from the environment in 30 seconds;
- keep gotchas and remedies, exact paths, file names, flags, versions, numeric
  thresholds.

Every line passes the test: "what breaks if it is removed?" Answer "nothing" →
the line goes.

### Step 3. Completeness check
Reconcile the draft with the source: are all facts present? Compression has no
right to lose meaning — only air.

### Step 4. Confirmation
Show the user: was N characters → becomes M, plus the draft text. Only on "yes"
do you execute.

### Step 5. Execute
Fact — an update to an existing key is an **in-place upsert**: one
`memory_remember` with the same key replaces the value; there is no old record
to delete. In bulk runs write it as `source='consolidation'`
(`scripts/patch-entries.mjs`) — `memory_remember` would force `source='user'` and
mislay a machine-merged record as the owner's own words.

Lesson — prefer **editing in place**: `UPDATE lessons SET rule=? WHERE id=?`
(`scripts/patch-entries.mjs`). The id, `project`, `source` and `negative` survive,
which matters because a lesson's `project` decides whether it is ever injected:
rewriting through `memory_forget` + `memory_remember` gives the new lesson the
project of the *current* cwd and can silently lose its reachability. Use the
two-step form only when the id genuinely must change — `memory_remember`
deduplicates, so:
1. `memory_forget(type="lesson", id=<old id>)`;
2. `memory_remember(type="lesson", rule=<new text>, …)` — capture the new id.

Failure mid-way — see "Runtime" in `00-shared-rules.md`.

### Step 6. Outcome
Short line in `reports/report-completion.md`: which record was compressed,
old id → new id (real), characters saved. Line in `journal/work-log.md`.

## Gate before the report

- [ ] The entry's topic is genuinely single (otherwise 🌀→✅ or 📦 first); a
      500–1000 character single-storyline entry not cut for volume
- [ ] Facts listed before cutting
- [ ] Only connectives, repeated context, filler, recoverable details cut;
      gotchas/remedies, paths, file names, flags, versions, thresholds kept
- [ ] Every line passed the "what breaks without it?" test
- [ ] Reconciliation with the source: all facts present
- [ ] User shown "was N → becomes M" + draft, confirmation obtained
- [ ] Facts: updated in place (no delete). Lessons: edited in place where
      possible (id/project preserved); delete+add only if the id must change
- [ ] Outcome: old id → new id + savings; line in `journal/work-log.md`;
      defects (if any) in `journal/defect-log.md`