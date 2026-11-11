# pi-retrospective

A deliberate written retrospective of agent work in a Pi project over a period
you name. For agents of a Pi build; the report is written for agents first, and
the chat summary is in your language.

## When it runs

Only when you explicitly ask for the retrospective process, for example:

- «Сделай ретроспективу за неделю»
- «Сделай обзор работы за период»
- «Разбери, достигли ли мы целей за месяц»
- "Do a retrospective of this project"

It does not run on quick status questions («что ты сделал сейчас», «какая работа
была проделана», «отчитайся») — those get a cheap chat answer. When the ask is
ambiguous, the agent asks you one short question first, because the process is
expensive in tokens and time.

## What you get

- `retrospectives/<YYYY-MM-DD>.md` — one file per day, updated in place, with the
  wanted/got/evidence/remaining table, volume counts, emphasis points, and small
  deferred defects.
- `retrospectives/README.md` — one line per day so you can find "what was done
  when" in seconds.
- A short chat summary in your language pointing at the file — plain words,
  details kept, no developer jargon or class names, technology names only in
  general words, no anglicisms in a Russian report; mermaid diagrams welcome
  when they explain a relation.

The work is judged by files, commits and real check runs first. Earlier
retrospectives are baseline only. Agent words are claims until confirmed.

## Language

Retrospectives default to English (agents are the main readers). Ask for Russian
and the report is written in Russian. Chat always follows your language.

## Subagents

Big periods are split into read-only lanes (main conversation, subagent groups,
artifacts) with strict briefs; the orchestrator is the only writer. Lanes take the
session model by default; ask for specific models and exactly those are used —
never silently substituted. An independent verifier can re-check the verdicts; if
none is available the report says "author-led check" instead of pretending.
