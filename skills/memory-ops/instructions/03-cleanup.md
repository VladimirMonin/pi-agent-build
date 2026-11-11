# Mode 💀 Cleanup

When: duplicates, stale records, or one-off garbage were found — usually as a
follow-up to audit 🔍 or quick scan ⚡. Outcome — `reports/report-completion.md`.

## Steps

### Step 1. Candidates
Collect candidates with diagnoses from `00-shared-rules.md`:
- 💀 — duplicates a source of truth (SKILL.md, checklist, validator), derivable
  from the environment in seconds, belongs to a one-off task;
- 🕰️ — path no longer exists, tool removed, version changed;
- 🔁 — two records telling the same thing (facts or lessons), **including a
  cross-store duplicate**.

### Step 2. Evidence
For every candidate, record the check: what was inspected, with what, what was
seen. Checks use tools — `ls`, `grep`, `read` in the relevant skill directory
or the environment. For lessons, fetch the rule text via `memory_lessons`.

If this session already made mutations, take the current state from the tools
plus `journal/work-log.md`, not from an earlier `<memory>` block.

### Step 3. Proposal
Show the user the candidate list: id, diagnosis, one-line evidence.
Phrase it as "proposing to delete", never "deleting".

### Step 4. Confirmation
Delete only on an explicit user "yes". "Say 'delete' and I will remove it" is a
workable format. A partial confirmation ("delete 3") executes only the named
items.

### Step 5. Deletion
`memory_forget(type="fact", key=…)` or `memory_forget(type="lesson", id=…)` for
every confirmed id. A "Not found" response is a normal case: the record was
already deleted. Report it calmly and check via `journal/work-log.md` whether a
duplicate of it remains.

### Step 6. Outcome
Final report in the `reports/report-completion.md` format: how many records
deleted, what remains, and follow-up proposals if the cleanup exposed 🌀 mixes
or bloated records. A line in `journal/work-log.md`.

## Gate before the report

- [ ] Candidates of all diagnoses collected, each with evidence
      (what/with what/seen); doubtful ones deferred
- [ ] User shown the list: id + diagnosis + evidence; phrased as "proposing
      to delete"
- [ ] Deletion only on an explicit "yes"; partial confirmation touched only
      the named items
- [ ] "Not found" handled calmly; duplicates re-checked
- [ ] Outcome per `reports/report-completion.md`
- [ ] Line in `journal/work-log.md`; defects (if any) in `journal/defect-log.md`
- [ ] If 🌀 mixes or bloated records surfaced, the relevant modes proposed