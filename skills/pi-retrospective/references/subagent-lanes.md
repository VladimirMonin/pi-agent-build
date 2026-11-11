# Subagent lanes — splitting the analysis

> Read before workflow step 5 when the material is big. The orchestrator stays the
> only writer of project files; lanes only read and report facts. A report-author
> subagent additionally returns the ready chat report with validated diagrams (see
> the human-summary reference); the orchestrator relays it verbatim.

## When to split, when not to

- Split when the period covers more than one long session family, or several
  subagent groups whose own files need reading.
- Do not split a small retrospective. Analyze inline with bounded reads and state
  "single-agent analysis" in the report — a disclosed solo run beats fake
  delegation.

## Lane assignment by source slice

Give each lane one disjoint slice so nothing is read twice or missed:

| Lane | Slice | Typical sources |
|---|---|---|
| A | main conversation | the user's messages and main session turns |
| B | subagent group 1..n | nested subagent sessions and their artifacts |
| C | artifacts and receipts | traces, diffs, commits, check results |

State the slice boundary in the brief. Slices never overlap.

## Brief contract (mandatory)

Every lane brief contains:

1. **Inputs** — exact session ids, file paths, and the period bounds with the
   cutoff. No topic-only hand waving.
2. **Read limit** — how much to read (bounded windows or a budget), so a lane
   cannot sink into hundreds of pages.
3. **Deliverable** — a compact facts list, each fact with a source pointer
   (session id + timestamp, or file + line). Tables over essays.
4. **Forbidden** — no edits, no commits, no test runs, no fixing anything, no
   writing outside its own report.
5. **Return path** — the orchestrator's expected return shape (the facts list),
   or an absolute output file path when the lane must save an artifact.

## Model policy

- Lanes inherit the session model by default.
- When the user requests specific models for subagents, use exactly those.
- If a requested model is not available in this process, say so and ask the user.
  Never substitute a model silently.

## Independent check (optional mode)

A fresh-context verifier re-checks the wanted/got/evidence table against primary
evidence and returns agree/disagree per row plus counter-evidence. It does not
rewrite the report. When no independent verifier is available, disclose
"author-led check" in the report — never dress up self-review as independent.

## Concurrency and stopping

At most 3 lanes at once. Stop when every requirement-list row has evidence or an
explicit gap. If the scope explodes beyond what was asked, stop and ask the user
before widening — the trigger gate applies to scope too.
