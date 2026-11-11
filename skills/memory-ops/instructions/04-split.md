# Mode 🌀→✅ Split a mix

When: one record holds 2+ independent topics (the tests in `00-shared-rules.md`
yielded 🌀). Plan — `reports/report-regroup-plan.md`.

## Steps

### Step 1. Diagnose
Identify the topics inside the record. For each, apply the deletion test:
"remove this part — does the rest lose meaning?" If not, it is an independent
topic.

### Step 2. Over-splitting check
Before cutting, run each extracted part through the "one storyline" test. If a
part is story-bound to the rest — do NOT cut. Guideline: a series of facts about
one subsystem is ✅. Blind fragmentation burns the character budget.

### Step 3. Destination for detached facts
For each extracted topic decide:
- it fits an existing record of another topic → append there (if that stays
  ≤ ~500 characters);
- it fits nowhere → a new record ➕ per the formula in `00-shared-rules.md`.

Note the store: a fact becomes a `key`, a lesson is its own `id`. A mix inside
one record of a single store is the common case; splitting across stores is
rare and should be deliberate.

### Step 4. Plan
Show the user the plan in the `reports/report-regroup-plan.md` format:
"was → becomes" table, number of operations. Facts do not change — only plates.
Await confirmation.

### Step 5. Execute
Strict order:
1. `memory_remember` all new records (parts of the mix) — real ids/keys from the
   tool responses;
2. `memory_forget` the old mixed record — only after all parts saved
   successfully.

Failure mid-way — see "Runtime" in `00-shared-rules.md`: do not delete what was
saved; show the user the actual state.

### Step 6. Outcome
Report `reports/report-completion.md` with the real new ids and every record
marked ✅. Line in `journal/work-log.md`.

## Gate before the report

- [ ] Topics identified with the deletion test; each extracted part checked
      with the "one storyline" test — story-bound parts NOT cut
- [ ] Budget honoured: blind fragmentation stopped
- [ ] Destination decided for every detached topic: append (≤ ~500 chars) or
      new record
- [ ] Plan per `reports/report-regroup-plan.md` ("was → becomes"), explicit
      confirmation obtained
- [ ] `memory_remember` all new records first — then `memory_forget` the mix
- [ ] Fact-for-fact reconciliation: every fact of the source record found in
      the new ones
- [ ] Outcome per `reports/report-completion.md` with real ids, all ✅
- [ ] Line in `journal/work-log.md`; defects (if any) in `journal/defect-log.md`