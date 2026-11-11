# Memory Ops — Shared Rules

## Philosophy

1. **Memory is expensive space.** Entries are injected on every turn (both in
   the main session and in every subagent) and consume context even when
   irrelevant. Saving characters saves context.
2. **The unit of storage is a topic, not a fact.** Not ultra-fragmentation
   (10 facts = 10 entries) and not a dumping ground ("flies, compote and
   puree on one plate"). One entry answers one question: "what is this about?"
3. **Facts are never lost.** Regrouping moves facts between plates; it does
   not edit their content. A lost fact is a broken operation.
4. **No deletion without an explicit user "yes".** Proposed → confirmed →
   done. No exceptions.
5. **Safe order:** every new entry is saved before any old entry is deleted.
6. **Never prune a fact with `source: user`.** It is the owner's own word.
   Machine-inferred (`consolidation`) entries are the reviewable ones.
7. Entries are stored in the user's language. Secrets and the user's name are
   never stored.
8. Skill files are English; **user-facing output follows the user's language.**
9. **A secret must never be reproduced in an artifact either.** When you find a
   secret-shaped value during a sweep, the report, dump, or journal records only
   `pza_<REDACTED>` — never the value, and never a prefix longer than the
   provider's public key marker (`pza_a_`, `sk-`, `ghp_`). Writing a fragment of
   a real key into a report creates exactly the leak the sweep was meant to
   find.

## Runtime: confirmed behaviour of pi-memory

- Facts live under a dotted `key`; `memory_remember` for a fact is an
  **UPSERT** (`ON CONFLICT(key) DO UPDATE`). Update in place — one step.
- `memory_remember` for a fact **forces `confidence = 0.95`,
  `source = "user"`**. `source: consolidation` cannot be written through the
  tool; it only appears on entries the auto-consolidation wrote.
- Lessons are addressed by `id` (uuid) and **deduplicated** on add: exact
  match (case-insensitive) and Jaccard ≥ 0.7 are rejected as "Already known".
  Rewriting a lesson = `memory_forget(type=lesson, id=…)` first, then add.
- `memory_forget(type=fact, key=…)` deletes by key. A miss returns
  "Not found" — normal, not a failure. Check the work log for a duplicate.
- **Injection is per-turn**, not per-session: a `<memory>` block arrives on
  every user turn — by default (`context-hook` mode) as an ephemeral message
  before the latest user message; the legacy `system-prompt` mode appends to
  the system prompt. Facts are selected by semantic relevance (≤15) plus
  embedding hits and then co-expanded; lessons are selected by
  `project = <slug of cwd> OR project IS NULL`, up to 50 (`all` mode) or
  searched with up to 3 local slots (`selective` mode). **Never rank lessons
  vs facts by intuition** — one 3-segment fact domain can outweigh the whole
  lessons section; measure (see Reachability below).
- **Prefix co-expansion — the biggest hidden cost, and it has a threshold.**
  `keyDomainPrefix` returns the first **two** segments **only for keys with 3+
  segments**: `<a>.<b>.<c>` → `<a>.<b>`, and a hit anywhere in that domain pulls
  **all its siblings** (limit 20 for a semantic/embedding hit, 5 for an FTS hit).
  Keys with exactly two segments (`pref.editor`, `teaching_hub.task_map`) are
  **leaf** — they pull nothing at all. So a 3-segment domain is as expensive as an
  always-injected lesson, while a 2-segment record costs only its own length.
  (An earlier revision of this file used `teaching_hub.task_map` as the example of
  a drag; that example was wrong — that family is leaf.)
- **Key shape is a lever, not cosmetics.** To take knowledge out of the injected
  block without deleting it, move the key to a leaf depth (2 segments). To shrink a
  domain, shorten the domain — renaming `a.b.x` to `a.b.y` or splitting it into
  `a.b.x.*`/`a.b.y.*` changes nothing, because the prefix is still `a.b`.
- The block budget is **`MAX_CONTEXT_CHARS = 8000`** — a **character budget**,
  not a slot count. Stock builds truncate the block with a `... (truncated)`
  marker; scoped-injection builds fit whole records by section quotas and emit
  no marker. Which behaviour applies is version-bound — verify against the
  installed code.
- **Overflow is silent and is the first thing to check.** If the domains that
  a typical session pulls plus all lessons exceed 8000 characters, the tail is
  cut off and part of memory never reaches the model. Quantify it before
  proposing cosmetics: sum the largest domain + all active lessons against
  8000.
- **Storage metadata.** A fact carries `confidence`, `source`, `created_at`,
  `updated_at`, `last_accessed`. A lesson carries `id`, `rule`, `category`,
  `source`, `negative`, `project`, `created_at`, and **`is_deleted`**. The
  `source` values seen in practice are `user`, `consolidation`, and
  `session:unknown` (written by session-end consolidation; treat like
  `consolidation`).
- **Deletion is a soft delete.** `memory_forget` sets `is_deleted = 1`; the row
  stays in the table for history. So "row count from the table" is not the
  live count — always filter `is_deleted = 0`, or you will audit records that
  are no longer injected. `memory_lessons` already filters them.
- **Subagents get their own injection.** They start with `context: "fresh"`
  and `inheritGlobalContext: false`, but share the cwd, so their own
  `pi-memory` instance searches the same DB. Do not assume a subagent is
  memory-free.
- If a tool call fails mid-operation: if old entries are not yet deleted the
  state is safe — retry the save. If failure happened after partial deletion,
  **do not continue silently**: show the user exactly what was saved and what
  remains of the old entries, and agree on how to finish.

## Value scale

Value = cost of rediscovering the fact. The key question: "what happens if
this entry disappears?"

| Circle | Points | Meaning |
|:------:|:------:|---------|
| 🔴 | 9–10 | Without it: hours of debugging, or the operation is impossible |
| 🟠 | 8 | A trick found through experimentation |
| 🟡 | 7 | Paths, versions, environment facts |
| 🟢 | ≤6 | Useful, but no real loss |

Modifiers:
- **Frequency:** needed in every project → up; once a year → down.
- **Recoverability:** rediscovered in 30 seconds (`ls`, `git log`, `pip list`)
  → down.
- **Source of truth elsewhere:** the rule is already baked into a SKILL.md,
  checklist, or validator → that is not value, that is 💀 (see below).
- **`source: consolidation`** (and `session:unknown`) → treat as unverified
  until checked; it never had a human filter.
- **Infrastructure cost is part of value.** A record inside a large domain
  costs more than its own length, because of prefix co-expansion. A short
  record in an oversized domain can still be the most expensive one in the
  store.

## Entry integrity

The "one plate" test — mark an entry 🌀 (mix) when:

1. An enumerating conjunction links independent facts ("also", "plus",
   "important limitations: a), b), c)") whose items share no storyline.
2. **Deletion test:** remove one part — does the rest still make sense? If yes,
   they are different topics → 🌀.
3. **Different medicines:** two problems with two independent solutions → 🌀.
4. **Different spheres:** an environment fact ("no deno") and a workflow fact
   ("how to fetch subtitles") are not one plate.

The "one storyline" test — a series of facts is ✅, not 🌀, when it forms the
story of one scenario or one subsystem:

- cp1251 in Python + cp1251 in PowerShell + masks via @files + MiKTeX in
  elevated → ✅ one topic "Windows terminal and encodings";
- PDF pipeline + its script paths + Paged.js quirks → ✅ one topic "PDF build";
- path to skills + FFmpeg install → 🌀 (unrelated).

A narrow cluster of facts about one process/subsystem is one topic; proposing
to split it is an error even when the deletion test formally passes. Priority:
the "one storyline" test outranks the deletion test.

**On conflict:** thematic integrity beats blind atomicity. The character
budget matters more than cosmetics.

### Entry size

- Guideline: 1 entry = 1 topic ≈ **200–500 characters**.
- Hard ceiling: **1000 characters**.
- 500 is the target for *appending* to an existing entry. Cut an entry in the
  500–1000 range only when **different storylines** appeared inside it (modes
  🌀→✅ or 📦), not merely because "it got long". A coherent cluster of
  600–800 dense characters is normal; splitting it is harmful.
- Remember the budget is global: ~8000 characters for the whole injected
  block, shared with lessons. A few bloated entries can push others out.

## Garbage diagnoses

| Icon | Diagnosis | How it is checked |
|:----:|-----------|-------------------|
| 💀 | Unneeded | Duplicates a skill's SKILL.md / checklist / validator; derivable from the environment; belongs to a one-off task |
| 🕰️ | Stale | Path does not exist, tool removed, version changed, contradicts current practice |
| 🔁 | Duplicate | Two records tell the same thing — keep the fresher/more complete one; includes cross-store duplicates (fact ↔ lesson) |
| 🧬 | Auto-generated | `source: consolidation`; never human-filtered — always review |

Check only with tools — `ls`, `grep`, `read`. Never "I think it's like that".

## Cross-store duplicates

The same knowledge can live in two stores at once: as a **fact**
(`semantic`) and as a **lesson** (`lessons`). Since lessons are injected in
full on every turn, a duplicated lesson is the expensive copy. On a
cross-store duplicate, prefer keeping the **fact** (selectively injected) and
dropping the lesson, unless the lesson is a genuine correction
(`negative: true`) that must always be present.

## Short entry formula

```
[Topic]: [essence/gotcha] — [remedy/fact].
```

**Cut:** connectives ("also", "plus", "important limitations"), repeated
context, filler words, details recoverable from the environment.
**Keep:** gotchas and remedies, exact paths, file names, flags, versions,
numeric thresholds.

**Line test:** "what breaks if this line is removed?" Answer "nothing" → the
line is superfluous.

Example:

- ❌ "It is also important to remember that when calling the script through
  group you cannot pass a *.png mask, because PowerShell does not expand it
  for Python"
- ✅ "PowerShell does not expand *.png masks for Python — pass the list via
  @files"

## File encoding (Windows)

Plan files, slice exports and journals are written as **UTF-8 via file tools**,
never through shell `echo`/redirection — on Windows a shell write can land as
CP866/UTF-16, and the plan parsers read UTF-8 Cyrillic markers
(НОВОЕ ЗНАЧЕНИЕ, ВОШЛО, ПРОЕКТ) and then silently find zero blocks.

## Work log

Every memory mutation is one line in `journal/work-log.md`, written right
after the operation and before the final report. Rules:

- only date, mode, ids, counters — **entry content is not logged**;
- a series of operations in one session may be one summary line;
- facts must not be lost: record `facts preserved N/N` where relevant.

Format:

```
YYYY-MM-DD · mode · old-id → new-id · counters · facts preserved N/N
```

Cleanup without recreation: `YYYY-MM-DD · 💀 · deleted: key1, key2 · no facts lost`.
Key change: `YYYY-MM-DD · ✏️ · old.key → new.key`.

## Reports

Formats and filled-in samples live in `reports/`:

- `report-audit.md` — full audit 🔍;
- `report-quick-scan.md` — quick scan ⚡;
- `report-regroup-plan.md` — split/regroup plan 🌀/📦;
- `report-completion.md` — outcome after any operation.

In every report use real identifiers: dotted keys for facts, real uuids for
lessons — never invented labels.