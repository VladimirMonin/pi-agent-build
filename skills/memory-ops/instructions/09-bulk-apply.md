# Mode 🧱 Bulk apply (lanes → plan → apply)

When: the store is large enough that a single-context audit is wasteful — roughly
200+ records across several domains, or the work is split by independent topics.
Also use it whenever a plan will be applied mechanically rather than by hand.

Outcome — the lane plans plus `reports/report-completion.md`, and a line in
`journal/work-log.md`.

**Why lanes exist.** A 250-record store is ~110 KB of text. Read by one agent it
costs ~30k tokens of context and produces a plan nobody can check. Split into
disjoint lanes; each lane analyses only its slice and writes a plan to disk; the
orchestrator reads neither the records nor the full plans — only a short summary
and the machine-actionable blocks it must verify.

## Roles (fixed boundaries)

| Role | Who | Does | Never |
|---|---|---|---|
| **Orchestrator** | this session | slicing, briefs, collecting plans, normalize + validate, owner contact, every deletion decision, apply, verification, journals | — |
| **Lane** | read-only helper (subagent) or a sequential slice in this session | analyses its exported slice, appends to **its own** plan file | touches the database, edits others' plans, applies anything |
| **Checking** | scripts, not a role | `validate-apply`, token-preservation, insert self-check, probe | — |

Read-only is enforced **by construction**: lanes receive slice files from
`scripts/export-lanes.mjs`, not database access. Lane briefs follow
`references/lane-contract.md` (chunking 3–5 blocks per call, resume protocol,
answer cap) — the 30-minute default helper timeout kills a lane that writes a
whole plan in one breath.

**When lanes are NOT needed** — work directly:

- under ~200 records or a single domain;
- the runtime has no real helpers (or no resume) → sequential path below;
- fewer than 2 useful disjoint slices;
- inherently single work: one entry edit (07), drift review (08).

**Parallel vs sequential rule.** Parallel lane helpers when (a) the runtime
gives real helpers with resume, (b) ≥2 disjoint slices exist, (c) ≥~200
records, (d) the owner asked for or allowed delegation. Otherwise run the same
lanes **sequentially in this session** (one slice at a time, same contract,
same chunking) and say so in the report. The single-agent path is complete —
nothing here requires helpers.

**Waves of at most 3 helpers at once.** A 22-lane fan-out hit the provider's
`429 too many concurrent requests` and killed half the lanes at spawn; waves of
three ran 11/11. Launch ≤3, wait for the wave, launch the next.

**Intake check (mandatory).** When plans arrive, reconcile each lane's footer
count against what the applier/validator actually parsed (e.g. `grep -c '^### '`
vs parsed groups). A lane that reported G=18 while the dry-run parsed 0 is a
format-drift signal — stop and fix the plan before applying.

## Step 1. Reachability and budget first (never skip)

Before splitting anything, measure what the injector actually selects — see
"Reachability" in `00-shared-rules.md` and `scripts/inject-probe.mjs`:

```bash
node scripts/db-copy.mjs "<live.db>" <copy>.db          # consistent copy first
node scripts/inject-probe.mjs --estimate --db=<copy>.db # availability and domains
node scripts/inject-probe.mjs --db=<copy>.db            # the real block
```

Run the probe against a **copy**, never the live DB. Two outcomes
must be stated explicitly before any proposal:

- which records can never be injected (project is a full path; a domain that no
  prompt reaches) — optimising them buys nothing;
- which domains co-expand (keys with 3+ segments) and how big they are — that is
  where the character budget actually goes.

## Step 2. Split into lanes

Export disjoint slices (read-only) and hand each lane its file:

```bash
node scripts/export-lanes.mjs --db=<copy>.db --out=<plans-dir>/slices --lanes=4
```

Rules for a split that cannot corrupt the result:

- lanes are **disjoint by key prefix** (facts) and by **`project` value**
  (lessons) — `export-lanes` keeps whole 2-segment domains and whole projects
  together; an id or key touched by two lanes is a merge bug waiting to happen;
- each lane writes **its own plan file** (a plans directory outside `reports/`);
- balance is by **characters**, not record count — one 16k domain is not "small"
  because it has 100 records;
- a lane judges its slice, never the whole store.

## Step 3. Plan format (contract, not style)

Lanes MUST emit the same machine-actionable structure; without it the plan
cannot be applied by script and becomes hand-work again. Facts:

```
### G<n>
KEEP KEY: <key>
НОВОЕ ЗНАЧЕНИЕ: <one line, the exact value to write>
ВОШЛО: <key>, <key>            ← the full member list (may wrap lines)
ЧТО СОХРАНЕНО: paths/flags/numbers/versions kept — for the completeness check
УДАЛИТЬ: <key>, <key>
```

Lessons (no keys, so project must be explicit):

```
### LR<n>
ПРОЕКТ: <project value, or NULL> · ТИП: negative=1|negative=0 · КАТЕГОРИЯ: <cat>
ГОТОВЫЙ ТЕКСТ УРОКА: <one line>
ВОШЛО: <uuid>, <uuid>
ЧТО СОХРАНЕНО: <identifiers, numbers, paths kept>
УДАЛИТЬ: <uuid>, <uuid>
```

Hard requirements learned the hard way:

- **lists may wrap across lines** (a parser that reads one line silently drops
  members), and keys must be written in **one** style across all lanes
  (backticked or bare — the scripts accept both, but mixed styles inside one
  plan is a defect);
- plan files are written **UTF-8 via file tools** (never shell echo) — the
  parsers read UTF-8 Cyrillic markers and a CP866/UTF-16 shell write silently
  yields zero blocks;
- blocks whose heading contains 💀 are **never** applied by script: pure
  deletion stays an owner decision; a title marked «ЖДЁТ/⚠️» must land in
  «Ждёт подтверждения», not in an applied section.

## Step 4. Lanes report back

Cap the reply: status, was → becomes in characters, number of merge groups,
number of 💀/🕰️, the plan path, one risk. Full texts stay in the plan file.
Chunking and timeout-resume follow `references/lane-contract.md`.

## Step 5. Apply mechanics (one writer, strictly serial)

```bash
node scripts/normalize-apply.mjs <plans...>                 # 1. plan surgery
node scripts/validate-apply.mjs --db=<copy>.db <plans...>   # 2. ALL plans at once
#    … показать владельцу 💀-блоки и удаления, получить явное «да» …
node scripts/db-copy.mjs "<live.db>" <dir>/memory-before-apply.db   # 3. backup
node scripts/apply-facts.mjs   <plan.md> --db="<live.db>"           # 4. dry-run
node scripts/apply-lessons.mjs <plan.md> --db="<live.db>"           #    dry-run
#    … проверить «проблемы» и отчёт по токенам, затем:
node scripts/apply-facts.mjs   <plan.md> --prefix=<domain>. --db="<live.db>" --apply
node scripts/apply-lessons.mjs <plan.md> --db="<live.db>" --apply
```

Order rules (each one is a past accident):

- **`normalize-apply` then `validate-apply` over ALL plans in one call** —
  cross-plan disjointness is the only thing that catches a key consumed by two
  lanes. Never validate plans one by one.
- **Owner's explicit "yes" before any deletion** — 💀-blocks and delete lists
  are decisions, not mechanics.
- **Appliers run strictly one at a time, one plan per call.** Parallel
  appliers are forbidden: the store is a single SQLite file, a second writer
  gets `SQLITE_BUSY` after 5 s, and validation state goes stale mid-run.
- **dry-run first**, with validation: every delete target exists, KEEP is not
  deleted by another group, prefix guard, no empty/oversized values;
- **one transaction** per plan: `BEGIN IMMEDIATE` … `COMMIT`, rollback on any
  error;
- **self-check inside the transaction**: after inserting, re-read and confirm
  the new rows exist, otherwise abort. (On 2026-09-24 an edit put the insert
  call inside a comment; the deletes ran and the inserts did not — 210 lessons
  were deleted with no replacement. It was caught only by comparing
  `created_at` against the plan. The backup made it recoverable.)
- **never rewrite through `memory_remember` in bulk**: for facts it forces
  `source='user'` (a merged, machine-derived record would be mislabelled as
  the owner's words and become un-prunable). Write merged entries with
  `source='consolidation'`.
- **lessons with explicit `project`**: the merged lesson must inherit the
  project of the consumed records (or the value the plan states) — otherwise
  it silently becomes unreachable, which is exactly what the old `forget +
  add` dance caused;
- **deletion is soft** (`is_deleted=1`); report counts, not impressions.

## Step 6. Verify the merge, do not trust it

Token preservation: from every consumed text extract substance — identifiers
(snake_case, camelCase, CONSTANTS), numbers, paths, backticked strings — and
require the union to appear in the merged text. Below threshold (default 0.9
with ≥3 tokens) the group is **not applied**. A plan that loses `utf8` or a
config key name is a defect, not a stylistic choice.

Then reconcile fact-for-fact against "ЧТО СОХРАНЕНО" for the applied groups,
and re-run the probe on a fresh copy to confirm the actual effect:

```bash
node scripts/db-copy.mjs "<live.db>" <dir>/probe-after.db
node scripts/inject-probe.mjs --db=<dir>/probe-after.db
```

Report before/after honestly, including "still truncated" if that is what the
probe says.

## Gate before the report

- [ ] Reachability + budget measured with the probe (or explicitly declared as an
      estimate) before any proposal
- [ ] Choice of parallel vs sequential lanes made by the rule above and stated
      in the report; waves ≤3 helpers; lane briefs used
      `references/lane-contract.md` (единственный диалект формата)
- [ ] Intake check done: footer counts of every plan reconciled with parsed
      group counts; no silent skips (validator reports zero unrecognized blocks)
- [ ] Lanes disjoint by key prefix / `project`; each read-only (slice files,
      no DB access); each wrote its own plan file outside `reports/`
- [ ] Plan format followed (lists may wrap; UTF-8 file tools; 💀-blocks and
      «ЖДЁТ» blocks not applied by script)
- [ ] `normalize-apply` ran; `validate-apply` ran over ALL plans in one call
      and passed
- [ ] Owner's explicit "yes" recorded for every deletion / 💀-block
- [ ] Backup taken; dry-run clean; apply strictly serial, one plan per call,
      one transaction with an insert self-check
- [ ] `source` preserved correctly (`consolidation` for merged entries); lesson
      `project` preserved
- [ ] Token-preservation check run; failing groups not applied and named
- [ ] Post-apply probe run on a fresh copy; was → becomes reported with real
      numbers, including unchanged overflow
- [ ] Line in `journal/work-log.md`; incidents recorded, not smoothed over
