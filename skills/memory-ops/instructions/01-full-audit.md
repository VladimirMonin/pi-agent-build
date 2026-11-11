# Mode 🔍 Full audit

When: on user request, every few weeks, after major environment changes.
Report format — `reports/report-audit.md`.

## Steps

> **Read the store, not the implementation.** An audit works from `memory.db`
> and the injected block. Never open a package's `dist/` or `node_modules`
> during an audit to "understand the mechanism" — those files are large
> (100 KB+) and a subagent sent down that path stalls and dies. If a mechanism
> genuinely matters, confirm it from the source you already have or state it as
> an assumption; the store is the authority on what is stored.

### Step 1. Inventory
List all records across the three stores:
- facts — `memory_search` (or the injected block as a starting map);
- lessons — `memory_lessons`;
- counts — `memory_stats`.

**Filter out deleted rows.** `memory_forget` is a soft delete (`is_deleted = 1`),
so a raw table scan shows records that are no longer injected. Count only live
records (`is_deleted = 0` in `lessons`).

**Opening finding — budget check (do this first), measured not guessed.**
Because of prefix co-expansion (see `00-shared-rules.md`), a record is never
injected alone: a 3+ segment key arrives with its whole domain. Before any
cosmetic proposal, run the real injector on a **copy** of the DB —
`node scripts/inject-probe.mjs --db=<copy> --estimate` for reachability, then
`--db=<copy>` without `--estimate` for the actual block:

1. the lesson set the filter `project = <slug of cwd> OR project IS NULL` selects;
2. the character total of each **expanding** domain (3+ segment keys) — domains
   of 2-segment keys are leaf and pull nothing;
3. those numbers against `MAX_CONTEXT_CHARS` (8000 as of the installed version —
   state the version you measured against).

If that sum exceeds the cap, it is the headline 🔴 finding — part of memory is
silently truncated and never reaches the model. Report it before anything else.
Equally, name the records that **no** session can reach (see "Reachability"):
they cost no budget and must not be "optimised".

Present each record as: id / key + a one-line summary + `source` + `confidence` (for
facts) or category / `negative` / `project` (for lessons). This is the working
map; show it to the user only in the final report.

### Step 2. Verify facts with tools
For every record naming paths, files, script names, or versions:
1. `ls` — does the mentioned folder/file exist.
2. `grep` — are the mentioned rules/scripts where you expect them.
3. `read` — to reconcile a specific rule when needed.

Key duplication check: does the record merely restate something already baked
into a skill? Search the record's keywords inside the relevant skill directory
(for this skill family: `~/.pi/agent/skills/`, `~/.agents/skills/`, and
package skills under `~/.pi/agent/npm/node_modules/<pkg>/skills/`). If the rule
is in a SKILL.md, checklist, or validator, the record is 💀.

### Step 3. Value classification
Give every record a circle 🔴🟠🟡🟢 per the scale in `00-shared-rules.md`
(cost of rediscovery + modifiers: frequency, recoverability, duplication of a
source of truth).

### Step 4. Integrity
Run every record through the "one plate", "one storyline", and size rules from
`00-shared-rules.md`. Mark mixes 🌀, atomic entries ✅. Narrow clusters about
one process/subsystem are ✅ — do **not** propose splitting them; run the
"over-splitting" check (step 2 of 🌀→✅) before any 🌀 proposal. Bloat alone is
not an argument for splitting.

### Step 5. Garbage
Find 💀 (duplicates / one-off), 🕰️ (stale paths and versions), 🔁 (duplicates
inside memory, **including cross-store fact ↔ lesson duplicates**), and 🧬
(auto-generated `source: consolidation`). For each candidate, record the
evidence — what exactly, checked with what, what was seen.

### Step 6. Durable vs. volatile
Separate each record into "durable rule" and "state snapshot". For a snapshot,
do not propose deletion by default: propose **rewriting it from the source**
(`git`, the file, current state) or date-stamping it. Version-pinned facts
("release X is out") age fastest.

### Step 7. Secrets sweep
Scan the DB for secret-shaped strings. Facts and lessons are designed to be
shared; a leaked token is the worst failure mode.
```
grep -a -i -E "pza_|sk-|ghp_|api[_-]?key|password|secret" \
  "<home>/.pi/memory/memory.db"
```
Any hit is a 🔴 finding: propose removing or masking it immediately, and note
that the fix belongs in the source too (config, trace, log).

**Redact in your own artifacts too.** When writing the report, dump, or journal,
replace every secret with `pza_<REDACTED>`-style text. Never copy the value, and
never a fragment beyond the public provider marker — a report is a shareable
artifact, so leaking there recreates the very problem this step exists to find.
Verify before finishing: `grep -o 'pza_a_[A-Za-z0-9]\+' <report>` must return
nothing but the marker.

### Step 8. Report
Emit the report in the `reports/report-audit.md` format: table
(No., id, topic, value, integrity, source, summary) + legend + verdict. Use
real ids. Change nothing — proposals only.

### Step 9. Await decision
Explicitly ask for confirmation on every proposed
deletion/compression/update. The user may confirm point by point
("delete 3", "compress 1").

### Step 10. Execute (after confirmation)
Strict order: first `memory_remember` all new/compressed/updated records
(an update to an existing fact key is an in-place upsert), then
`memory_forget` the old ones. Then the final report in
`reports/report-completion.md` with real ids, and a line in
`journal/work-log.md`.

## Gate before the report

- [ ] `instructions/00-shared-rules.md` read (first operation in the session)
- [ ] User confirmed a full audit is wanted (not ⚡)
- [ ] **Budget check done first and measured with the probe** (not from a dump):
      lesson set per slug + expanding domains against the cap; overflow reported as
      the headline 🔴 if present
- [ ] Unreachable records (never selected by the injector) named and excluded
      from the optimisation proposal
- [ ] Deleted rows excluded (`is_deleted = 1` filtered out) before counting
- [ ] All three stores inventoried; `source` and `confidence` shown
- [ ] `ls`/`grep`/`read` run for every record with paths/files/versions
- [ ] Every record checked against sources of truth (skill dirs searched for
      its keywords), including cross-store fact ↔ lesson duplicates
- [ ] Every 💀/🕰️/🔁/🧬 diagnosis has evidence (what, checked with what, seen)
- [ ] Every record given a value circle and run through the integrity tests
- [ ] Durable vs. volatile split done; snapshots get "rewrite from source"
      rather than default deletion
- [ ] Secrets sweep performed; hits marked 🔴
- [ ] Report per `reports/report-audit.md`; nothing deleted or changed
- [ ] Confirmation explicitly requested for every proposal
- [ ] Operations executed in "create first → delete last" order
- [ ] Final report per `reports/report-completion.md` with real ids
- [ ] Line in `journal/work-log.md`; defect line only if the run stumbled