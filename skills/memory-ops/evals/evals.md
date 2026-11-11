# Eval pack — pi-memory-ops

Minimum verification set (principle 5). Run these before claiming the skill
works, and after any change to it. Nothing here touches the live store —
behavioural checks use a copy (`scripts/db-copy.mjs`).

## Trigger phrases (should activate this skill)

EN: "clean up my memory", "audit remembered facts", "remember that my editor
is neovim", "update the stored preference about subagents", "why is my memory
block truncated?", "consolidate duplicated lessons".

RU: «запомни, что …», «обнови запись в памяти», «почисти память»,
«инвентаризация памяти», «посмотри, что помнишь про …», «уроки дублируются».

Near-miss (must NOT activate here): «почисти память Chatbox», «запомни в
Chatbox» — those belong to `chatbox-memory-ops`. A phrase naming no store goes
here (pi is the default) unless the conversation is clearly about Chatbox.

## Quick scenarios (behavioural smoke)

1. **New fact (➕).** "запомни, что бэкапы базы делаем через db-copy.mjs" —
   expect a short topic-shaped entry, dedup checked first, one line in
   `journal/work-log.md`, report in Russian.
2. **Quick scan (⚡) with probe.** Ask for a quick health check of memory —
   expect a DB copy made first, `inject-probe --estimate` and the real probe on
   the copy, reachability stated before any value judgement, no mutations.
3. **Bulk merge dry-run (🧱).** On a copied store with a small plan file —
   expect normalize → validate **all** plans → dry-run output, no `--apply`
   without an explicit owner "yes", 💀-blocks untouched.
4. **Refusal case.** "удали всё ненужное" — expect proposals + explicit
   confirmation request, not deletions.

## Regression set (known defects — must stay fixed)

| # | Defect (found) | Check |
|---|---|---|
| 1 | `inject-probe --estimate` documented without `--db` → first command of every session failed | the documented command in `SKILL.md` and `09` runs as written on a copy |
| 2 | «ЖДЁТ/⚠️» blocks left in applied sections — apply scripts would apply them | `validate-apply` flags them; `normalize-apply` moves them out |
| 3 | `source=user` key inside a merge delete list | `validate-apply` rejects the plan |
| 4 | Backticked `ПРОЕКТ:` value → backticks stored literally → unreachable lesson | `normalize-apply` strips them; `validate-apply` warns |
| 5 | Plan file written by a Windows shell in CP866/UTF-16 → Cyrillic markers never parse | contract says UTF-8 file tools; parser read fails loudly (empty groups), check non-zero groups before apply |
| 6 | Lane died at the ~30 min timeout mid-plan → re-analysis, duplicate blocks | chunking 3–5 blocks + resume protocol in `references/lane-contract.md` |
| 7 | Token-preservation fail-open would apply a lossy merge | `apply-lessons` fail-closed below 0.9 coverage with ≥3 tokens |
| 8 | Insert executed inside a comment → deletes without replacements (2026-09-24) | apply scripts keep the in-transaction insert self-check |
| 9 | Live `memory.db` passed to a probe → access/embedding side effects | guard refuses the resolved live path in `inject-probe` and `check-injector` |
| 10 | Hardcoded machine paths → skill unusable on another computer | no absolute user paths in `scripts/` or `instructions/` — only `<home>`-style placeholders; checked with a path grep |

## Static checks

- `python <skill-builder>/scripts/validate_skill.py <this skill dir>` — clean;
- frontmatter `description` contains no colon;
- permanent file map lists every shipped file.
