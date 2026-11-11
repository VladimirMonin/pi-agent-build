# Report sample: Outcome after operations

Final format after any operations (💀 cleanup, 🌀→✅ split, 📦 regroup,
🗜️ compress, ✏️ update, 🧬 drift). Example from a real session outcome:

```markdown
## Regroup complete

| No. | Id / key | Topic | Value | Integrity | Source |
|-----|----------|-------|:-----:|:---------:|--------|
| 1 | `pref.memory_brevity` | Meta-rule: keep memory short and clean | 🟢 | ✅ | user |
| 2 | `tool.skills.location` | Where skills live | 🟡 | ✅ | user |
| 3 | `tool.media.env` | Media environment: FFmpeg, yt-dlp, Python 3.14, no deno | 🟡 | ✅ | user |
| 4 | `tool.ytdlp.subtitles_429` | YouTube subtitle download: bypassing HTTP 429 | 🟠 | ✅ | user |
| 5 | `tool.windows.terminal_encoding` | Windows terminal and encodings: cp1251, @files, MiKTeX | 🔴 | ✅ | user |
| 6 | `project.pdf.build` | PDF build: pipeline, scripts, Paged.js quirks | 🔴 | ✅ | user |

Done: ➕ 4, 💀 2, 🔁 1. No errors, all facts preserved.
```

## Closing-line variations

**After cleanup:**
`Done: 💀 2. 4 records remain, all ✅. No garbage left.`

**After compression:**
`Done: 🗜️ 1 (<old key> → same key, 340 → 180 characters). All facts in place.`
(facts update in place — the key does not change; only a key change produces
an arrow pair)

**After a lesson rewrite:**
`Done: ✏️ lesson <old uuid> → <new uuid>. Delete-then-add was required because
lesson adds deduplicate.`

**After partial confirmation:**
`Done: 💀 1 (only No. 3, as confirmed). No. 1 and No. 5 untouched — awaiting
your decision.`

**On "Not found":**
`Record <id> was already deleted earlier — not an error. Checked for
duplicates: none.`

**After a drift pass:**
`Done: 🧬 3 reviewed — 2 rewritten from source, 1 deleted as duplicated.
No source: user record touched.`

## Rules for this mode

- The final-state table is always complete (all records, real ids).
- Operation counter: ➕ created · 💀 deleted · 🔁 duplicates removed · 🗜️
  compressed · ✏️ updated · 🧬 auto-generated reviewed.
- A mandatory statement about fact preservation.
- If unresolved proposals remain, name them at the end.
- Real identifiers only: dotted keys for facts, real uuids for lessons; never
  invented labels.