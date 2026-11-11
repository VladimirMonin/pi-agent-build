# Report sample: Regroup / split plan 🌀→✅ 📦

Format for modes 🌀→✅ (split) and 📦 (regroup): a "was → becomes" table +
operations + verdict + a request for confirmation. The example is filled in
for a real regroup session.

```markdown
## Regroup plan

| Was | Becomes |
|-----|---------|
| No. 1 "Skills path + FFmpeg" 🌀 | → "Skills path" │ "FFmpeg" |
| No. 2 "yt-dlp + 429 + no-deno" 🌀 | → "Bypassing 429" │ fact "no deno" → into "Media environment" |
| No. 4 "Windows gotchas + PDF" 🌀 | → "Windows terminal and encodings" │ "PDF build" |

**Operations:** ➕ 4 new → reconcile facts → 💀 2 old.
**Verdict:** 5 → 6 records. Facts do not change — only the plates.
Confirm?
```

## Rules for this mode

- Every "was" row is a source record, marked 🌀 if it is a mix.
- Every "becomes" row is a target record; a fact moving into an existing record
  is marked with an arrow: `fact "no deno" → into "Media environment"`.
- Story-bound facts are NOT separated (the "one storyline" test).
- The operation count is mandatory: how many ➕, how many 💀.
- Mandatory phrase: "Facts do not change — only the plates."
- Execution only on an explicit "yes"; afterward a line in
  `journal/work-log.md`.
- State the store when it matters: a fact is addressed by `key`, a lesson by
  `id`. A lesson rewrite is delete-then-add, since adds deduplicate.
- When the change touches lessons, note the cost: all lessons are injected on
  every turn, so merging two lessons is a real saving.