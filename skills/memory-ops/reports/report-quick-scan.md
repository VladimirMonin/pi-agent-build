# Report sample: Quick scan ⚡

Express format: 1–2 sentences, no tables. Examples:

## Clean memory

```markdown
Memory: 6 facts + 3 lessons, all ✅. No red flags —
💀 0 · 🕰️ 0 · 🌀 0 · 🔁 0 · 🧬 0. Good as is.
```

## Flags found

```markdown
Memory: 7 facts. Flags: 🌀 1 (a PDF record carries 3 topics),
🕰️ 1 (stale Python path), 🧬 2 auto-generated never verified.
Propose a full audit 🔍?
```

## Auto-generated records in focus

```markdown
Memory: 22 facts, 5 of them `source: consolidation`. Flags:
🧬 5 — none ever checked by a human. Propose drift review (08-drift)?
```

## Empty or new memory

```markdown
Memory: 2 facts, both ✅, tiny volume. Nothing to do —
record facts as they appear, no cleanup needed.
```

## Rules for this mode

- No more than 2–3 sentences.
- Flag counter on one line: `💀 N · 🕰️ N · 🌀 N · 🔁 N · 🧬 N`.
- A closing question when flags exist.
- No tables, no tools, no memory changes.
- The block is rebuilt every turn, so it is current — but it is a **relevance
  slice and it is silently truncated** at ~8000 characters. A record missing from
  the block is therefore not "unused": it may be past the cut, or unreachable at
  this cwd (lessons are selected by `project = <last path segment of cwd>`). Say
  "slice" instead of drawing conclusions from absence.
- Mention lessons explicitly when they look heavy — they are selected as a whole
  set, unlike facts, which arrive in domains.