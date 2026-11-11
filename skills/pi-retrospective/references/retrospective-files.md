# Retrospective files — layout and in-place updates

> Read before workflow step 6.

## Where the files go

1. If the project already has a retrospective file or folder — use that exact
   place, whatever it is called.
2. Otherwise create `retrospectives/` at the project root with `README.md` as the
   index and one file per day of work.
3. If project rules forbid in-tree reports, respect them and ask the user where
   the file should live instead of inventing a destination.

## One file per day, interval sections inside

A long task spans days; each day gets one file `retrospectives/<YYYY-MM-DD>.md`.
Several work sessions on the same day become separate sections with exact
boundaries:

```
## Interval A — 09:10–11:40 (zone)
anchor: interval-a
## Interval B — 13:00–14:30 (zone)
anchor: interval-b; previous: this-file#interval-a
```

Boundaries matter more than rounded times: the start of a new interval excludes
the end event of the previous one. Never merge intervals retroactively.

## Update in place, never rewrite

- New work on the same day: append a new interval section, do not touch earlier
  ones.
- Always refresh the `Last updated:` line at the top of the file.
- Never recreate a file that already exists — rewriting loses history.
- If an earlier claim needs a correction, add a short correction note with its
  reason; do not edit the old text silently.

## README index

`retrospectives/README.md` gets one line per period entry — date, one-line
outcome, link to the file or anchor. It grows one line at a time. For long
projects group rows by month headings so "what was done when" stays a
seconds-level lookup. Update the index's `Last updated:` line too.

## Privacy

From the first write: no passwords, tokens, cookies, account names, home paths or
contacts. Use project-relative paths and session ids as identifiers. Never stage a
dirty draft to sanitize later — filter before the first write.
