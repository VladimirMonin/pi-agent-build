# Mode ⚡ Quick scan

When: off the cuff, at the start of a session or mid-conversation, without deep
checks. Format — `reports/report-quick-scan.md`.

## Steps

### Step 1. Look
Read the `<memory>` block in your own system prompt for this turn. Do not call
tools — unless some record looks suspicious (a strange path, a doubtful
version) and the user asks to go deeper.

Note: the block is rebuilt on every turn, so it already reflects the current
DB. There is no "stale session snapshot" problem — but it is a *relevance*
slice, not the whole store. Use `memory_stats` / `memory_lessons` when you need
full counts.

### Step 2. Count flags
Roughly count:
- 💀 duplicate and one-off records;
- 🕰️ stale ones (doubtful paths/versions);
- 🌀 mixes (unrelated topics in one record);
- 🔁 duplicates inside memory (facts and lessons);
- 🧬 auto-generated (`source: consolidation`) records that were never checked.

### Step 3. Verdict
One or two sentences in the `report-quick-scan.md` format: how many records,
how many flags, the verdict. Remember lessons are injected in full — mention
them explicitly when they look bloated.

### Step 4. Escalate
If flags were found, propose a full audit 🔍 or a specific operation. Do not
start deep checks or changes without the user's request.

## Gate before the report

- [ ] The injected `<memory>` block read without tools (or a targeted check of
      suspicious records only)
- [ ] Remembered that the block is **truncated** at ~8000 characters: absence of a
      record is not evidence it is unused, and the visible lessons are only the head
      of the selected set. On a large store the verdict says "slice", not "nothing
      to do"
- [ ] Flags counted: 💀 · 🕰️ · 🌀 · 🔁 · 🧬
- [ ] Verdict is 1–2 sentences per `reports/report-quick-scan.md`, no tables
- [ ] No memory changes made
- [ ] If flags exist, a full audit 🔍 or a concrete operation was proposed
- [ ] No defect line needed (mode makes no mutations) — but if the run
      stumbled, record it as usual