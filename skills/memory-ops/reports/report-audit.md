# Report sample: Full audit 🔍

Full format — table + legend + verdict. Nothing is changed, proposals only.
The example below is filled in for a real audit of six records. The ids in the
sample are illustrative; a live report uses real identifiers: dotted `key` for
facts, uuid for lessons.

```markdown
## Memory audit — 2026-09-19

| No. | Id / key | Topic | Value | Integrity | Source | Summary |
|-----|----------|-------|:-----:|:---------:|--------|---------|
| 1 | `project.x.skills_ffmpeg` | Skills path + FFmpeg install | 🟡 | 🌀 | user | Two unrelated topics — propose split (04-split) |
| 2 | `tool.media.env` | Media environment: yt-dlp, Python 3.14, no deno | 🟡 | ✅ | consolidation | Keep — environment facts, cheap to verify |
| 3 | `tool.ytdlp.subtitles_429` | Subtitle download: bypassing HTTP 429 | 🟠 | ✅ | user | Keep — trick found experimentally, costly to rediscover |
| 4 | `tool.windows.terminal_encoding` | Windows terminal and encodings: cp1251, @files, MiKTeX | 🔴 | ✅ | user | Keep — silent failures, expensive to recover |
| 5 | `project.pdf.build` | PDF build: pipeline, scripts, Paged.js quirks | 🔴 | ✅ | user | Keep — one narrow cluster, do NOT propose splitting |
| 6 | `pref.memory_brevity` | Meta-rule: keep memory short and clean | 🟢 | ✅ | user | Keep — meta-rule for all future records |
| L1 | `3f2a…` (lesson) | Do not run `pi` inside subagents | 🟠 | ✅ | user | Keep — lessons are injected in full, price justifies it |

**Legend:** 🔴 critical (9–10) · 🟠 very important (8) · 🟡 important (7) · 🟢 useful (≤6) ·
✅ atomic · 🌀 mix · 🕰️ stale · 💀 delete · 🔁 duplicate · 🧬 auto-generated

**Verdict:** 6 facts + 1 lesson, average value 7.7, block well under the 8000
character budget. Proposals: 🌀→✅ split of No. 1 (mode `04-split.md`).
No deletions. Confirm?
```

## Variations

**Garbage found** — a row with dashes and a diagnosis:
`| 3 | project.x.notes_format | — | — | — | user | 💀 duplicates skill checklists — delete |`

**Duplicate found:**
`| 5 | tool.x.ffmpeg_installed | — | — | — | user | 🔁 duplicates No. 2 — keep one |`

**Stale found:**
`| 4 | project.x.python_path | — | — | — | user | 🕰️ actually 3.14 (checked with ls) — update (✏️) or delete |`

**Snapshot found (version-pinned):**
`| 7 | project.pi-polza.repo | — | — | — | user | 🕰️ pins release 0.2.0 — rewrite from git instead of deleting |`

**Auto-generated found:**
`| 6 | project.x.practice_db | — | — | — | 🧬 consolidation | Unverified inference (confidence 0.8) — verify then rewrite or delete (08-drift) |`

## Rules for this report

- Real identifiers only: dotted keys for facts, real uuids for lessons.
- The `Source` column is mandatory — `consolidation` records are always
  suspect and reviewed via 🧬.
- Lessons appear as their own rows when audited; they are injected in full, so
  a bloated lesson is more expensive than a bloated fact.
- Nothing is changed by an audit.