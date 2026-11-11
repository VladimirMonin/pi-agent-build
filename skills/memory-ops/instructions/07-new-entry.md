# Mode ➕✏️ New entry / update

When: the user states a durable fact about the environment, a tool, or a
preference that will be useful in future sessions — or a fact changes and an
existing record is now stale.

## Steps

### Step 1. Fitness filter
Do not store:
- one-off state of the current task;
- secrets (API keys, passwords) — never;
- the user's name;
- anything already baked into a SKILL.md/checklist or derivable from the
  environment in 30 seconds;
- anything the user asked not to remember.

Store: gotchas and remedies, paths, versions, flags, thresholds, durable user
working preferences.

### Step 2. Duplicate / staleness check
Scan memory (in this session use the tools; the `<memory>` block is only the
relevant slice):
- topic absent → new entry ➕;
- topic present, the new fact extends it → append (if it fits) or 📦;
- topic present, the new fact **contradicts** it → update ✏️ (step 2b).
- a lesson already says it (exact or Jaccard ≥ 0.7) → the add will be rejected
  as "Already known"; treat it as a duplicate, not a failure.

### Step 2b. Updating a stale fact ✏️
The most frequent case after ➕: "Python was updated", "deno is installed".
Order:
1. Show the user: old wording → new wording (the whole record, per the short
   entry formula) and the reason for the update.
2. Wait for "yes".
3. Execute:
   - **fact, same key** → one `memory_remember` with that key; it is an
     in-place upsert, no deletion;
   - **fact, new key** → `memory_remember` the new key, then
     `memory_forget` the old key;
   - **lesson** → `memory_forget(type="lesson", id=<old>)` first, then
     `memory_remember(type="lesson", …)` (the add deduplicates).
4. Line in `journal/work-log.md`: `old-id → new-id · ✏️ · reason`.

An update is not a compression or a regroup: the 🗜️/📦 ceremony is unnecessary,
but fact-for-fact reconciliation is mandatory — the new version keeps every
still-valid fact, only the stale one changes.

### Step 3. Choosing the plate
- Topic is new → its own record.
- Topic exists → append to the existing record, keeping it ≤ ~500 characters
  (if it does not fit and the storylines differ → 📦; 500–1000 with one
  storyline is fine, see `00-shared-rules.md`).

### Step 4. Wording
Formula: `[Topic]: [essence/gotcha] — [remedy/fact].` User's language, no
fluff, every line passes the "what breaks without it?" test.

### Step 5. Confirm and save
If the user explicitly asked ("remember this") — save immediately. If the
initiative is the agent's — show the wording first and ask. An unclear request
("remember…" what?) — clarify before saving.

### Step 6. Outcome
One line: saved, real id/key, topic. No long report. Line in
`journal/work-log.md`.

## Gate before saving

- [ ] Fitness filter passed: not one-off, no secrets or user name, does not
      duplicate a skill, not derivable in 30 seconds, not forbidden by the user
- [ ] Memory scanned: new topic / append / update — decision made
- [ ] Plate chosen: new record OR append (≤ ~500 chars)
- [ ] Formula honoured; line test passed
- [ ] Explicit request → immediate; agent initiative → show first; unclear
      request → clarify BEFORE saving
- [ ] For update ✏️: "old → new" shown; in-place upsert for a fact, or
      delete-then-add for a lesson; still-valid facts preserved
- [ ] Line in `journal/work-log.md`; the real id/key reported to the user
---

## Addendum 2026-09-24 — choose the key depth deliberately

The key of a fact decides what it costs on every turn, so choose it by intent,
not by habit:

- **3+ segments** (`a.b.c`) → the record drags its whole `a.b` domain into the
  block whenever any sibling matches (limit 20). Use it when the record belongs
  to a domain you *want* to arrive together.
- **2 segments** (`pref.editor`, `teaching_hub.task_map`) → **leaf**: the record
  arrives only if it matches by itself, and costs only its own length. Use it for
  rules that must be cheap, and as the way to *archive* knowledge out of the
  budget without deleting it.
- **`project.<slug>.*`** → only selected when the session's cwd slug equals that
  segment; keep it for genuinely project-scoped facts and never as an archive.

Do not split a 3-segment domain into `a.b.x.*`/`a.b.y.*` hoping to shrink it: the
prefix is still `a.b`. Shrink the domain or flatten the keys.
