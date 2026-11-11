# Evals — pi-retrospective

Run these by hand when changing the skill. Report honestly which level was
reached: static validation, same-session exercise, or independent run.

## Trigger gate — must fire

| Prompt | Expected |
|---|---|
| Сделай ретроспективу за неделю | skill opens the workflow |
| Сделай обзор работы за период 3–10 ноября | skill opens, binds the period |
| Разбери, достигли ли мы целей за месяц | skill opens, builds requirement checklist |
| Do a retrospective of this project | skill opens |
| Review what we accomplished this week and whether goals were met | skill opens |

## Trigger gate — must NOT fire (answer in chat directly)

| Prompt | Expected |
|---|---|
| Расскажи, что ты сделал сейчас | no skill; short status answer |
| Какая работа была проделана? | no skill; short status answer |
| Отчитайся | no skill; short status answer |
| What did you just do? | no skill; short status answer |

## Ambiguity — must ask first

| Prompt | Expected |
|---|---|
| Ну и как там наше дело? | no silent launch; one short clarifying question |
| Maybe we should look back at the week? | asks before unfolding the process |

## Quality checks on a produced retrospective

1. Trigger fired only on explicit request, or asked first when unsure.
2. Requirement checklist rows each carry a user-message source.
3. Every verdict has primary evidence or says "no evidence".
4. Volume numbers come from diffs/logs, not from memory.
5. Day file placed by the location rules; `Last updated` present; README row
   added; nothing rewritten in place.
6. Subagent briefs carry inputs, read limit, deliverable, forbidden actions,
   return path; models follow the user's request with no silent substitution.
7. Independent check present, or the report says "author-led check".
8. No secrets, home paths or account names in the output.
9. Chat summary given to the user in their language with the file link.
10. Chat report follows the human-summary style — plain user language, details
    kept, no developer jargon or class names, technology names only in general
    words, no anglicisms in a Russian report (references/human-summary.md).
11. Every report diagram passes the mermaid CLI check when the validator is
    installed (or the user was offered an install and asked first); diagrams are
    conservative for older chat renderers.
12. New mermaid defects met during the run were appended to
    journal/mermaid-defects.md; rule changes wait for an improvement pass.
13. The chat report and its diagrams were authored by a subagent and relayed
    verbatim by the orchestrator; diagram validation ran in that subagent (or
    its absence was disclosed).
