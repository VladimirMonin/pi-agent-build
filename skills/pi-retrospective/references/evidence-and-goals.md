# Evidence hierarchy, requirement extraction, verdicts

> Read before workflow steps 3 and 5. This is the honesty core of the skill.

## Evidence hierarchy

1. **Primary** — files, diffs, commits, and check/test runs that really happened.
   The verdict is judged by these alone.
2. **Secondary** — earlier retrospectives. They define "already covered" so work is
   not counted twice, and never prove new work.
3. **Claims** — agent and subagent prose in sessions. Useful as leads, believed
   only after primary confirmation.

When a claim and a file disagree, report both observations and the mechanism, do
not invent a clean story.

## Requirement extraction (the checklist)

From user messages inside the period, extract every ask as one checklist row:

| Kind | Signal words | Record |
|---|---|---|
| Goal | цель, нужно чтобы, we should end up with | the outcome wanted |
| Task | сделай, добавь, почини, implement, fix | the concrete deliverable |
| Emphasis | важно, смотри сюда, не забудь, акцент | what must not be missed |
| Constraint | не делай, не трогай, without, must not | a boundary on the work |

Each row carries its source (message timestamp or id) so the verdict table stays
checkable. Deduplicate repeated asks; preserve their order.

## Verdict vocabulary

Exactly four verdicts, each with an evidence pointer or the words "no evidence":

- **Achieved** — the outcome exists in primary evidence.
- **Partially achieved** — some of it exists; name what is missing.
- **Not achieved** — no primary evidence of the outcome.
- **Deferred** — explicitly postponed by the user or by a recorded decision.

Never turn "checks not run" into "failed", and never turn "author said done" into
"achieved".

## Volume — count honestly

| Metric | How to count |
|---|---|
| Files touched | from the diff or working tree, not from memory |
| Commits | from the log inside the period |
| Checks run | only checks with a real receipt in scope |
| Checks not run | listed explicitly as not run |

Do not invent time, cost, or counterfactual successes. A verified useful result is
not cancelled by messy organization, and a legitimate stop is not an error.

## Report shape

The retrospective core is one table — wanted / got / evidence / remaining — plus:

- how it was done (approach, rework, failed attempts that taught something);
- volume (the four counts above);
- emphasis points honored or missed;
- small defects noticed but deferred (place, effect, why left, next check);
- next steps.

Small deferred defects are recorded, never silently fixed during the
retrospective.
