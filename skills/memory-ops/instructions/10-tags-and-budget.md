# Mode 🏷️ Tags and budget (reachability engineering)

**Local runtime patch (optional, build-specific).** Builds that carry a scoped-injection runtime patch map shared project/worktree facts through private `memory.factProjectAliases` in the profile settings; lessons keep their existing project tags. Without that patch, stock selection applies (see `references/changelog.md`). If you have the patch repository, check the installed state with `python <PATCH_DIR>/apply.py --agent-dir=<PROFILE> --check`, and re-apply after every `pi update`. The running Pi process may hold old code until `/reload` or a fresh launch.

When: memory feels "heavy" or a large project's knowledge seems absent; the block
is repeatedly `truncated`; records were written by different sessions/worktrees
of one project; or a big project must keep working for months.

**This mode exists because two facts are easy to get wrong and were both
measured the hard way (2026-09-29 run on a 240-fact / 229-lesson store):**

1. **What reaches the model ≠ what a DB dump shows.** The injector formats each
   fact by **dropping the FIRST key segment** (`formatSemantic` does
   `key.split(".").slice(1).join(".")`), so `project.<имя>.foo` is displayed as
   `<имя>.foo`. Counting `project.*` lines in the injected block will therefore
   read **0** even when project facts are present — that is a display artifact,
   not unreachability. Always match displayed lines back to raw keys **by the
   record's FULL VALUE**, not the displayed prefix. Duplicate values can make
   even that ambiguous: instrument a throwaway bundle copy to log selected raw
   keys. Never rely on a first-50-character value prefix.
2. **The budget is a character budget, not a record budget.** The stock 1.5.0 block is a
   hard slice at `MAX_CONTEXT_CHARS` (8000); portable v2 omits excess **whole** records instead. What matters is how many
   characters the *selected* facts + lessons want, measured with the real
   builder, not how many records exist.

## Step 0 — Measure the real thing (never infer from a dump)

```bash
# 1. availability model (always works, no plugin import)
node scripts/inject-probe.mjs --estimate --db=<copy>.db
# 2. the real assembled block, on a COPY
sqlite3 "$DB" ".backup '<dir>/probe.db'"
node scripts/inject-probe.mjs --db=<dir>/probe.db
```
The probe tests **default cwds** — for a real diagnosis add the user's ACTUAL
working directories (from `~/.pi/agent/sessions/*`) as `--cases`.

### "How much does the block actually want?"
`truncated: true` only says it exceeds 8000. To learn the true demand, patch a
**throwaway copy** of the bundle (never the installed one):

```bash
cp "<pkg>/dist/index.js" "<pkg>/dist/index.nolimit.js"
# change one line: var MAX_CONTEXT_CHARS = 8e3;  ->  = 200000;
node -e 'const m=await import("file:///<pkg>/dist/index.nolimit.js"); /* buildContextBlock */'
rm "<pkg>/dist/index.nolimit.js"     # ALWAYS remove afterwards
```
This separates "slightly over" from "wants 3× the budget", which changes the fix
entirely. (The `@sinclair/typebox` shim may be required — see scripts/README.)

## Step 1 — Where the characters actually go

For each real cwd, attribute the injected lines to raw keys (by value) and group
by domain:

| Source | Cost shape |
|---|---|
| Facts | selected by semantic search (≤15) **plus co-expansion**: a hit on a 3+ segment key pulls its whole 2-segment domain (limit 20 for a semantic hit, 5 for FTS) |
| Lessons | **always-injected** when `project IS NULL`; otherwise `project = projectSlug(cwd)` |
| `project.<x>` facts, upstream 1.5.0 | FTS hits are filtered by `parts[1] === slug`, but embedding hits and sibling expansion are added **after** that filter and can leak facts from another project |

So the expensive things are: (a) NULL-project lessons, (b) large 3-segment fact
domains, (c) the generic fact corpus that matches almost every prompt.

## Step 2 — Tags (the reachability fix)

**A tag must equal `projectSlug(cwd)` exactly** — the last path segment after
`cwd.split("/")`, lower-cased, skipping a few words. Consequences:

- A tag written as a **full path** (`…/worktrees/<имя-ветки>`)
  matches **only** when the cwd arrives with **backslashes** (then
  `split("/")` yields the whole path as one segment). With forward slashes the
  slug is just `<имя-ветки>` and the tag never matches.
- The same OS, the same folder can therefore inject *different* lessons
  depending on how the path was spelled. **This is the #1 silent bug.**
- In stock builds (1.5.0–1.6.1), `project.<x>.*` FTS hits are filtered by
  `parts[1] === slug`, but embedding hits and their sibling expansion are added
  **after** that filter and can leak facts from another project. **Not
  unreachable**: foreign `project.<x>.*` facts can appear in the wrong session.
  A scoped-injection patch enforces the scope at every selection step.

**Workflow-fix per project family:**

1. Enumerate real cwds from sessions:
   ```bash
   # ~/.pi/agent/sessions/* — the session's cwd is the truth
   ```
2. Decide the canonical tag per project (see "Large projects" below).
3. Rewrite lesson tags **without touching rule text** (see
   `scripts/patch-entries.mjs`, which edits `project` in place), and/or rename
   fact keys so `parts[1]` is the canonical slug.
4. Re-run Step 0 on the real cwds and confirm the counts changed as intended.

## Step 3 — Large projects: one project, many worktrees

A big project usually has **one repo + N git worktrees**. Memory attaches to
**one cwd string per record**, so there is no built-in "all worktrees" scope.
Choose deliberately:

| Strategy | Tag | Gains | Costs |
|---|---|---|---|
| **Canonical root** | the root's actual slug (from its real cwd spelling) | root lessons work in root | worktree sessions do not inherit root lessons |
| **Per-worktree** | exact slug from that worktree's real cwd | exact local context | knowledge does not travel between worktrees |
| **Hybrid** | shared facts → `project.<x>.*` alias (runtime patch); local lessons → actual cwd slug | project facts across all worktrees, local lessons per worktree | requires the runtime patch and verification after upgrades |

**Without the runtime patch**, do not invent a synthetic umbrella lesson tag
unless a folder actually yields that slug. The patch maps declared root and
worktree paths to one shared `project.<x>.*` **fact** alias (via
`memory.factProjectAliases`) while leaving the legacy full-path lesson tags
intact. It does not make shared root lessons appear in all worktrees.

## Step 4 — Budget engineering (after tags are honest)

Order of operations, cheapest first:

1. **Move NULL-project lessons to their project** (`memory_forget`+re-add, or
   `patch-entries` in place). Anything that belongs to one project must not be
   always-injected. Re-measure: NULL set is the first term in every cwd's cost.
2. **Compress the remaining always-on set** — data, not opinion: the block is
   dominated by a handful of long records. Merge the duplicates, cap each merged
   ledger at ≤1000 chars (`apply-lessons.mjs` checks token preservation).
3. **Shrink a fact domain** by moving keys to **leaf depth (2 segments)**: a
   2-segment key pulls nothing; a 3-segment key drags its siblings. Renaming
   `a.b.x` → `a.b.y` changes nothing (prefix still `a.b`).
4. **Consider `lessonInjection: "selective"`** (see below) only after 1–3.

## Step 5 — `lessonInjection: "selective"` (a real lever)

`~/.pi/agent/settings.json`:
```json
"memory": { "consolidationModel": "…", "lessonInjection": "selective" }
```
Measured on 2026-09-29: default `"all"` injects every lesson whose
`project = slug OR project IS NULL` (≈9400 chars for one large project); unpatched
`"selective"` uses FTS/search to inject ≈217–4608, **without reliably enforcing
project scope**. On a generic worktree prompt it selected **zero** local lessons
in two sampled worktrees. The local patch now reserves up to three local lessons
before topic search, filters out foreign project lessons, and fits complete
records into the 8000-character budget. This still cannot guarantee that *all*
local lessons fit; explicitly search memory or read source documents as needed.

## Historical local injector v1 (superseded, removed)

The original machine-local patcher (v1) is **no longer shipped with this
skill** (it was tied to exact upstream bytes and its anchors stopped matching;
second scripting language on top of that). Kept as history in the skill
archive. What it did is retained here as evidence — a scoped-injection patch
(the v2 line, maintained in a separate patch repository):

- scopes `project.*` facts at FTS, embedding and sibling stages; the declared
  root and worktree paths of one project map to a shared `project.<имя>.*` alias
  without changing their lesson tags;
- reserves up to three local lessons ahead of topic search and ranks those
  first at selection; additional topic-relevant local lessons may fit. It rejects
  lessons tagged for another project;
- keeps complete fact/lesson lines within the 8000-character block, including
  a no-prompt fallback. It omits excess records rather than slicing mid-sentence.

**After `pi update`**: check the installed bundle with the repository patcher, not the historical local script. For pinned 1.5.0 exact stock or known canonical states, back up, apply the repository patch and validate a new **DB copy**; unknown/new upstream versions require re-analysis, never forced replacement. The current Pi process may hold old code until `/reload` or a fresh launch. Restore through `apply.py --restore` only with explicit acceptance that stock reintroduces leakage and mid-record truncation; private backups remain available. The patch does not rewrite the DB.

## Step 6 — Verify (the run is not done until the probe says so)

```bash
node scripts/db-copy.mjs "$DB" '<dir>/probe-after.db'   # or sqlite3 ".backup"
node scripts/inject-probe.mjs --db=<dir>/probe-after.db
```
Report **honestly**, including "still truncated". Two verifications are
mandatory on every mutation:
- **owner records intact**: `source='user'` counts unchanged and texts
  byte-identical unless explicitly approved;
- **tags match a real cwd**: build the block with the *actual* cwd spelling(s).

## Anti-patterns

- **Judging reachability from a dump.** `formatSemantic` hides the first
  segment; `project.*` looks absent when it is present. Match by value.
- **"Full path" tags.** They silently depend on backslash spelling and break
  `project.<x>.*` filtering.
- **Rewriting `source='user'` records in bulk.** Rule 6 — owner consent first,
  and `source='user'` must survive.
- **Deleting a project's worktree lessons because "the worktree is gone".** The
  repo and its branches outlive the worktree; the lesson may still be the best
  record of that work.
- **Patched-bundle experiments left behind.** Delete `index.nolimit.js` and
  restore `MAX_CONTEXT_CHARS` before finishing.

## Journal line

```
YYYY-MM-DD · 🏷️ tags · retagged N lessons (<from> → <to>) · NULL-project lessons A→B · probe: RM X→Y, truncated yes/no · user records intact N/N
```
