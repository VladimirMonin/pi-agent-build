# Mermaid Defects Log — pi-retrospective

Append-only log of mermaid rendering defects met while drawing diagrams for
retrospective reports. Read before drawing, append after a run. This log is how
the diagram rules get better over time: entries are folded into
`references/mermaid-diagrams.md` on an improvement pass, never silently during a
run.

## What belongs here

- Diagrams that broke the validator, and what in them broke it.
- Diagrams the validator accepted but the chat refused to draw.
- Workarounds that survived a real render.

## What does not belong here

- Feature wishes and style tastes — those are conversation.
- Anything about a specific user's private context.

## Format

```markdown
## YYYY-MM-DD — short label

- **Symptom:** what broke (validator error or silent chat failure)
- **Cause:** what in the diagram triggered it
- **Workaround:** what drawing survived
- **Status:** open / folded into rules
```

Keep entries to a few lines. When a defect is folded into the rules, move a
one-line summary under Resolved rather than deleting it.

---

## Entries

<!-- Append new entries below this line, newest last. -->

## 2026-11-11 — straight double quotes inside labels

- **Symptom:** validator parse error, the diagram was not drawn at all.
- **Cause:** a straight double-quote pair inside a double-quoted label closes
  the label early and breaks parsing.
- **Workaround:** guillemets or single quotes inside labels.
- **Status:** folded into rules.

## 2026-11-11 — chat renderer stricter than the validator

- **Symptom:** a diagram accepted by the validator did not render in chat.
- **Cause:** exact trigger not proven — labels with slashes and colons suspected;
  the chat renderer is older than the validator.
- **Workaround:** short labels, no slashes or colons inside node labels, one
  relation per line.
- **Status:** open (trigger not proven).

---

## Resolved

- 2026-11-11: straight double quotes inside labels — guillemets or single quotes.
