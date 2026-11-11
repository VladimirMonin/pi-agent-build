---
name: pi-retrospective
description: Write a deliberate written retrospective of agent work in a Pi project over a period the user names. Use ONLY when the user explicitly asks for the retrospective process, for example "сделай ретроспективу", "сделай обзор работы за неделю", "разбери, достигли ли мы целей за месяц", "do a retrospective", "review what we accomplished this week". Do NOT use for quick status questions like "что ты сделал сейчас", "какая работа была проделана", "отчитайся", "what did you just do" — answer those directly and cheaply instead. When it is unclear whether the user wants the full retrospective process, ask the user one short question first, because this process is expensive in tokens and time.
license: MIT
compatibility: Built for a Pi coding agent build with session search (semantic or plain). Subagents are optional; the skill degrades to disclosed single-agent analysis.
metadata:
  version: "1.3.0"
  language: "Skill body and produced retrospectives are in English by default. When the user asks for a Russian retrospective, write it in Russian. Chat replies follow the user's language."
  based-on: "Method adapted from agent-session-forensics by Hermes Agent (MIT). That original is left untouched."
  cost: "Token-heavy multi-session analysis. Never start it without an explicit user request."
---

# Pi Retrospective

Produce one honest written retrospective of agent work in a Pi project over a
requested period — what the user asked for, what was actually done, how, in what
volume, and whether the user's goals were really achieved.

## Trigger gate (read this first)

This skill is expensive by design: it reads whole sessions plus their subagent
sessions and writes a durable report. Run it ONLY when the user explicitly asks
for the retrospective process.

**Runs on** — explicit retrospective asks:

- "Сделай ретроспективу за неделю" / "Сделай обзор работы за период"
- "Разбери, что мы сделали за месяц и достигли ли целей"
- "Напиши ретроспективу проекта" / "Do a retrospective of this project"
- "Review the work over the last week and whether the goals were met"
- Any ask that names a retrospective, a work review for a period, or an audit of
  what was done and whether goals were achieved.

**Does NOT run on** — cheap status questions, answer those in chat directly:

- "Расскажи, что ты сделал сейчас" / "Что ты сделал?"
- "Какая работа была проделана?"
- "Отчитайся" / "How are things going" / "What did you just do?"
- Any short report request that clearly wants a chat answer, not a written
  retrospective over a period.

**If you are not sure** whether the user wants the full retrospective process,
ask one short question before unfolding anything, for example "Развернуть полную
ретроспективу? Это долго и дорого по токенам". Never launch it on your own
initiative, at random, or because a session feels long. The user decides.

## What the retrospective must answer

For the requested period:

1. What the user asked for — goals, concrete tasks, and points they told you to
   emphasize (важно, смотри сюда, не забудь про X).
2. What was actually done — and how it was done.
3. In what volume — files touched, commits, checks really run.
4. Whether each ask was achieved — fully, partially, or not at all, with evidence.

## Evidence hierarchy

1. **Primary:** files, diffs, commits, and check/test runs that really happened in
   the project. The verdict is judged by these.
2. **Secondary:** earlier retrospectives. They set the baseline of "already
   covered" and never prove new work.
3. **Claims:** what agents and subagents wrote in sessions. Verify against primary
   evidence before believing.

User requests, wishes and emphasis points are the requirement list. Extract them
from user messages and grade the work against them.

## Workflow

1. **Bind the scope** — project, period (from the previous retrospective or the
   task start, up to now), and the exact user asks within it. Fix one cutoff so
   later activity does not leak in.
2. **Find the previous retrospective** — search the project for the newest
   retrospective file or folder and read it as baseline only.
3. **Collect the requirement list** — goals, tasks, emphasis points from user
   messages in scope (references/evidence-and-goals.md).
4. **Collect evidence** — primary (files, commits, checks) first, then session
   stores: the main session and every linked subagent session
   (references/pi-session-stores.md covers locations and safe reading).
5. **Analyze** — split reading across subagent lanes when the material is big, or
   analyze inline and disclose it (references/subagent-lanes.md).
6. **Write** — one file per day with interval sections, updated in place, plus the
   project README index (references/retrospective-files.md, templates/day-file.md).
7. **Verify and hand over** — re-read what you wrote, check every claim has a
   source, then give the user a short chat summary in their language with the
   file link.

## Where Pi sessions live

Three-tier discovery, cheapest first:

1. Semantic search over sessions (`session_search`) when it is configured — query
   by artifact name, topic, or distinctive term.
2. Plain session search when semantics are missing or silent — `session_list`
   filtered by project and dates, then `session_read`.
3. Raw session files under `~/.pi/agent/` when exact quotes or timestamps are
   needed.

File layout, subagent linking, and the traps (compaction summaries, harness noise,
self-matches) are in references/pi-session-stores.md.

## Language

The skill body and produced retrospectives are in English by default, because
agents are the main readers. When the user asks for the retrospective in Russian,
write it in Russian. Chat replies always follow the user's language.

### Human summary in chat

The chat report is authored by a subagent — the one that ran the analysis, or a
dedicated report subagent — to spare the expensive main session; the orchestrator
saves the files and relays the chat text verbatim with at most a light fact
check. The report goes to chat in the user's language: detailed, plain and
honest — without developer jargon, class names, technology names (or only in
general words), and without anglicisms when the report is Russian. Important
small things are kept; nothing is hidden behind oversimplification. The full
style body, copied from the caveman plain-speech skill, is in
references/human-summary.md — the report author reads it before step 7 and
follows its volume rules (shorter / usual / detailed).

Diagrams: mermaid code blocks render in chat and belong there whenever a diagram
explains a real relation — a flow chart for the route of the work, a sequence
chart for who talked to whom, a class chart for how ideas connect, a mind map for
the whole picture. Plain-text box schemes stay the fallback when mermaid is not
rendered.

Validate report diagrams before delivery: every mermaid diagram that goes into a
report — the day file or the final chat report — may be checked with the mermaid
CLI (`mmdc`) inside the report-author subagent, not in the main session. The
check is optional; when the validator is not installed, offer to install it and
wait for the user's approval — never install or download anything silently.
Label rules learned from real defects (quotes, slashes, colons) live in
`references/mermaid-diagrams.md` — the report author reads it before drawing.
New mermaid defects go to `journal/mermaid-defects.md` during the run, so the
next report draws better.

## Division of work (subagents)

Use subagent lanes for big material. The orchestrator (you) stays the only writer
of project files; lanes are read-only and return compact facts with sources,
never essays. The chat report, its diagrams and their validation are authored by
a subagent (report author below), so the expensive main session only relays.

- **When to split:** more than one long session family, or several subagent groups
  in scope. Small retrospectives run inline and say "single-agent analysis".
- **Models:** lanes inherit the session model by default. When the user requests
  specific models for subagents, use exactly those. If a requested model is not
  available in this process, say so and ask — never substitute silently.
- **Independent check (optional):** a fresh-context verifier may re-check the
  wanted/got verdicts against primary evidence. When no independent verifier is
  available, disclose that the check is author-led instead of dressing up
  self-review as independent.
- **Report author (default):** the chat report, its mermaid diagrams and their
  validation with the mermaid CLI are produced by a subagent — the analysis
  subagent or a dedicated report subagent — not by the main session. The
  orchestrator saves files and relays the chat text verbatim with at most a light
  fact check; this keeps the expensive main-session context small.
- **Boundaries:** at most 3 lanes at once, explicit briefs with read limits and a
  return format, one writer, stop when evidence is covered. The full lane contract
  is in references/subagent-lanes.md.

## What good output looks like

- `retrospectives/<YYYY-MM-DD>.md` — one file per day, updated in place, built from
  templates/day-file.md. Its heart is the wanted/got/evidence/remaining table, plus
  volume and deferred defects.
- `retrospectives/README.md` — one line per period entry so a human finds "what was
  done when" in seconds (templates/readme-index.md).
- A short chat summary in the user's language that points at the file.

## Permanent file map

| File | Purpose and when to use it |
|---|---|
| `SKILL.md` | Entry point and trigger gate; read when the skill loads. |
| `README.md` | Human-facing overview; read before handing the skill to a person. |
| `LICENSE` | MIT license of this skill; read when reusing or redistributing. |
| `references/pi-session-stores.md` | Where Pi session data lives and how to read it safely; read before workflow step 4. |
| `references/evidence-and-goals.md` | Evidence hierarchy, requirement extraction, verdict vocabulary; read before steps 3 and 5. |
| `references/retrospective-files.md` | File naming, interval sections, in-place updates, README index; read before step 6. |
| `references/subagent-lanes.md` | Lane split, briefs, model rules, stop conditions; read before step 5 when splitting. |
| `references/human-summary.md` | Plain-language chat report rules (caveman style body); read before step 7. |
| `references/mermaid-diagrams.md` | Diagram rules and the optional validator flow; read before drawing report diagrams. |
| `journal/mermaid-defects.md` | Append-only mermaid defect log; read before drawing, append after a run. |
| `templates/day-file.md` | Day-file skeleton; copy when creating a new day file. |
| `templates/readme-index.md` | Project index skeleton; copy when creating a new index. |
| `evals/evals.md` | Trigger and quality test cases; read when improving the skill. |
| `journal/defect-log.md` | Self-improvement log; read before a revision. |

## Environment and execution

Subagents are optional. Without them, analyze inline with bounded reads and state
plainly that the analysis was single-agent. No scripts are required — the work is
reading sessions and project files and writing Markdown. The skill needs write
access only to the project's retrospectives area and read access to the project
and `~/.pi/agent/`.

## Record defects before you finish

At the end of a run, record meaningful issues in `journal/defect-log.md` if it is
writable — steps that misled the run, gaps that had to be improvised, output that
missed the mark. Mermaid rendering defects have their own log,
`journal/mermaid-defects.md` — append to it freely during a run. When repeats appear, offer the user an improvement pass;
independent agents may help review the evidence if available. Do not silently
change this skill. If the log is not writable, give the user a short entry to keep
elsewhere. See `journal/defect-log.md` for the entry format.
