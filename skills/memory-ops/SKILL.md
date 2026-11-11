---
name: pi-memory-ops
description: >
  Maintain pi's persistent memory (the @samfp/pi-memory store) — audit for
  quality, clean stale or duplicated entries, split mixed-topic facts, regroup
  scattered ones, compress bloat, refresh outdated facts, and record new facts
  correctly. Use when the user asks to review, check, tidy, regroup, compress,
  update or reason about remembered facts (запомни, обнови запись, почисти
  память, инвентаризация памяти), or when a durable fact/preference should be
  stored. This is the agent's own pi memory — for Chatbox Memories use
  chatbox-memory-ops instead. Not for transient task state.
metadata:
  version: "1.0.0"
  updated: "2026-11-11"
  maintainer: local
  maintain_with: skill-builder
  harness: pi
---

# Memory Ops (pi)

Maintenance skill for pi's persistent memory. It covers the three stores
injected by `@samfp/pi-memory`, from quality assessment to thematic
regrouping. All operations act on records that are injected into the context
of future turns (both the main session and every subagent).

Core principle:

**one entry — one topic · value = cost of rediscovering it · never lose a fact**

## Hard rules (short)

1. Memory is injected on **every turn**, so every character is paid for
   repeatedly. Keep entries short.
2. The unit of storage is a **topic**, not a single fact and not a dumping
   ground.
3. **No deletions without the user's explicit "yes".**
4. Safe order: **create the new entry first, delete the old one last.**
5. Verify every fact with tools (`ls`, `grep`, `read`) before acting on it —
   never "by eye".
6. **Never prune a fact whose `source` is `user`** — that is the owner's own
   word, not machine inference. Rewriting one (compression, merge) is allowed
   only on an explicit owner instruction, keeps `source='user'` and is logged
   as a rewrite; see `instructions/00-shared-rules.md`.
7. Never store secrets (API keys, passwords) or the user's name. A secret found
   during a sweep is never reproduced in a report or journal either — only its
   provider marker (`pza_a_`, `sk-`) is named.
8. **Reply to the user in the user's language.** The skill's own files are in
   English; user-facing text is not.
9. **Check the budget before cosmetics.** A record may be injected with its
   whole prefix domain, so the first finding of any audit is whether what the
   injector *actually selects* fits `MAX_CONTEXT_CHARS = 8000` — measured with
   `scripts/inject-probe.mjs`, never inferred from a dump of the store.
   Overflow beats tidiness as a priority.

## Runtime in one minute

Three stores — `semantic` (facts, addressed by dotted `key`), `lessons`
(addressed by uuid `id`), `events` (audit trail, never injected). Facts and
lessons arrive in a `<memory>` block on **every user turn**; with the default
`context-hook` injection mode the block is an ephemeral message placed before
the latest user message (the legacy `system-prompt` mode appends to the system
prompt) — either way the cost is paid every turn. Budget is a **character**
budget, `MAX_CONTEXT_CHARS = 8000`.

Two mechanics decide what you pay for:

- **Prefix co-expansion has a threshold.** A match on a key with **3+
  segments** pulls its whole 2-segment domain (siblings, limited); keys with
  exactly two segments (`pref.editor`) are **leaves** and pull nothing. A
  3-segment domain costs like an always-on lesson; a 2-segment record costs
  only its own length. Key shape is a lever, not cosmetics.
- **Selection is version-bound.** Stock builds truncate the block with a
  `... (truncated)` marker; builds carrying a scoped-injection patch select
  whole records by section quotas and emit no marker. Which one you have
  depends on the installed `@samfp/pi-memory` version plus any local patch —
  **verify against the installed code and name the version in your report**;
  when memory and observation conflict, observation wins.

Tool surface: `memory_search`, `memory_remember`, `memory_forget`,
`memory_lessons`, `memory_stats`. Environment tools are `ls`, `grep`, `read`.
A fact `memory_remember` is an UPSERT on `key` and forces `confidence=0.95`,
`source="user"`; machine merges must therefore be written directly with
`source='consolidation'` (see `09-bulk-apply.md`). A lesson add deduplicates
(exact + Jaccard ≥ 0.7 → "Already known") — to rewrite a lesson, delete the old
id first. Deletion is soft (`is_deleted=1`).

Full mechanics — reachability tiers, the slug rule and its backslash trap,
storage metadata, the value scale, integrity tests and the entry formula — live
in `instructions/00-shared-rules.md`. **Read that file before the first
operation in a session.**

## Principle: durable vs. volatile

Split every entry by half-life:

- **Durable rules** — paths, workflows, "how to", gotchas, hard rules. Time
  does not invalidate them. Keep.
- **State snapshots** — "release v0.2.0 is out", "exam #1 has passed",
  "currently open". These rot. Do not silently delete them: **rewrite from the
  source** (`git`, the file, the current state) or date-stamp them.

## Modes

| Mode | Icon | Steps | Report sample |
|------|:----:|-------|---------------|
| Full audit | 🔍 | instructions/01-full-audit.md | reports/report-audit.md |
| Quick scan | ⚡ | instructions/02-quick-scan.md | reports/report-quick-scan.md |
| Cleanup | 💀 | instructions/03-cleanup.md | reports/report-completion.md |
| Split a mix | 🌀→✅ | instructions/04-split.md | reports/report-regroup-plan.md |
| Regroup | 📦 | instructions/05-regroup.md | reports/report-regroup-plan.md |
| Compress | 🗜️ | instructions/06-compress.md | reports/report-completion.md |
| New / update entry | ➕✏️ | instructions/07-new-entry.md | — |
| Consolidation drift | 🧬 | instructions/08-drift.md | reports/report-audit.md |
| Bulk apply (parallel lanes or serial) | 🧱 | instructions/09-bulk-apply.md + scripts/ | reports/report-completion.md |
| Tags & budget | 🏷️ | instructions/10-tags-and-budget.md + scripts/ | reports/report-completion.md |

## Roles and delegation

Bulk work over a large store may fan out to **read-only lane helpers** while
the orchestrator (this session) keeps the responsible work — owner contact,
every deletion, plan approval, and the actual apply. A complete single-agent
path always exists (sequential lanes in one context) and the choice rule is in
`instructions/09-bulk-apply.md`. Lane briefs follow
`references/lane-contract.md`. Helpers never touch the database; they analyse
exported slices and write plan files.

## Before any operation

1. Read `instructions/00-shared-rules.md`.
2. Establish reachability and budget **before judging value**: copy the store
   first (`node scripts/db-copy.mjs <live.db> <copy>.db`, or
   `sqlite3 "<live.db>" ".backup '<copy>.db>'"`), then run
   `node scripts/inject-probe.mjs --estimate --db=<copy>.db` (SQL model, always
   works) or the real probe `node scripts/inject-probe.mjs --db=<copy>.db`.
   A dump of the store is not evidence of what the model receives.
3. Pick the mode from the request (table above).
4. Follow the steps of that instruction file.
5. Pass the "Gate" at the end of the mode instruction before changing anything.
6. Report to the user in the format of the sample in `reports/`.
7. Speak to the user in the user's language.

## Permanent file map

| File | Purpose; when to read |
|---|---|
| `SKILL.md` | Entry point and routing; loaded on invocation. |
| `instructions/00-shared-rules.md` | Philosophy, runtime mechanics, reachability, value scale, integrity tests, entry formula, journal and report rules; before the first operation. |
| `instructions/01-full-audit.md` | 🔍 full audit procedure. |
| `instructions/02-quick-scan.md` | ⚡ quick scan procedure. |
| `instructions/03-cleanup.md` | 💀 cleanup procedure. |
| `instructions/04-split.md` | 🌀→✅ split-a-mix procedure. |
| `instructions/05-regroup.md` | 📦 regroup procedure. |
| `instructions/06-compress.md` | 🗜️ compress procedure. |
| `instructions/07-new-entry.md` | ➕✏️ new/update entry procedure. |
| `instructions/08-drift.md` | 🧬 consolidation drift procedure. |
| `instructions/09-bulk-apply.md` | 🧱 lanes → plans → apply; roles, serial apply, fallback. |
| `instructions/10-tags-and-budget.md` | 🏷️ reachability engineering — tags, key shape, budget levers. |
| `references/lane-contract.md` | Lane helper brief, chunking, resume, answer cap; when running lanes. |
| `references/changelog.md` | History of corrections and version-bound claims; when behaviour looks stale. |
| `evals/evals.md` | Trigger phrases, quick scenarios, regression set; before claiming the skill works. |
| `scripts/db-copy.mjs` | Consistent DB copy (`VACUUM INTO`) for probes and backups; before any measurement or apply. |
| `scripts/inject-probe.mjs` | Measures the real injected block (copy only). |
| `scripts/export-lanes.mjs` | Read-only export of disjoint lane slices. |
| `scripts/validate-apply.mjs` | Pre-apply validation of all plan files at once. |
| `scripts/normalize-apply.mjs` | Plan surgery before apply (backticks, held blocks). |
| `scripts/apply-facts.mjs` | Applies fact merge groups — dry-run default, `--apply` to write. |
| `scripts/apply-lessons.mjs` | Applies lesson merges with token-preservation check. |
| `scripts/patch-entries.mjs` | Targeted renames/value edits from a JSON manifest. |
| `scripts/check-injector.mjs` | Behavioural regression on a DB copy (needs the plugin bundle). |
| `scripts/README.md` | Script details and environment needs; when using scripts. |
| `journal/work-log.md` | Private mutation log — kept local, never synced or packaged. |
| `journal/defect-log.md` | Private defect log — same handling. |
| `LICENSE` | MIT license of this skill; ships with it. |
| `.gitignore` | Keeps runtime artifacts (databases, manifests, `runtime/`) out of version control. |
| `reports/report-audit.md` | Report template — full audit 🔍. |
| `reports/report-quick-scan.md` | Report template — quick scan ⚡. |
| `reports/report-regroup-plan.md` | Report template — split/regroup plan 🌀/📦. |
| `reports/report-completion.md` | Report template — outcome after any operation. |

## Environment

Node.js ≥ 22 (the scripts use the built-in `node:sqlite`) and the
`@samfp/pi-memory` plugin installed in the pi profile. Portable across Windows
and macOS — every script takes `--db`/`--settings`/`--bundle` explicitly and
otherwise resolves defaults from `PI_MEMORY_DB`, `PI_CODING_AGENT_DIR`,
`PI_MEMORY_BUNDLE` and finally the platform home directory
(`<home>/.pi/memory/memory.db`, `<home>/.pi/agent/settings.json`). No absolute
path of any one machine is required. Probes run on a **copy** of the store;
the live `memory.db` is refused by guard.

## Journals

- **Work log** — one line per mutation in `journal/work-log.md`, immediately
  after the mutation, before the final report. Ids, mode, counters only.
- **Defect log** — record a defect in `journal/defect-log.md` only when the
  run actually stumbled (misleading instruction, missing step, unresolved
  reference). Do **not** write a line for a clean run; a clean run leaves no
  entry.

Journals are private: keep them local, never sync or package them.

## Changelog

History of corrections and measured behaviour lives in
`references/changelog.md`. Read it when a claim in this skill disagrees with
what you observe — several corrections there are version-bound.
