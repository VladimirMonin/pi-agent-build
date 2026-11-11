# Mermaid diagrams in retrospective reports

> Read before delivering a report that contains diagrams. This file collects the
> drawing rules learned from real defects. The running defect log is
> `journal/mermaid-defects.md` — read it before drawing.

## Validation is optional and consent-based

- Report diagrams (the day file and the final chat report) may be checked with
  the mermaid CLI validator, command `mmdc`, when it is installed.
- Ordinary mid-chat sketches never need the CLI check.
- If the validator is not installed, offer the user to install it and wait for
  explicit approval. Never install or download anything silently.
- If the validator itself refuses to start (for example its browser engine is
  missing), report that plainly and offer the same choice: install the engine
  with the user's approval, or point the validator at an already installed
  browser with a small launch config. Still never download silently.
- How to check: write the diagram block to a scratch `.mmd` file, run the
  validator on it, read the error if any, and remove the scratch files after.

## Label rules from real defects

1. Cyrillic text and guillemets inside labels are fine.
2. NEVER put straight double quotes inside a double-quoted label — the pair
   closes the label early and parsing dies. Use guillemets or single quotes.
3. Slashes and colons inside node labels are formally accepted by the validator
   but have frozen a chat renderer. Keep them out of node labels.
4. Keep labels short and one relation per line. Chat renderers are stricter than
   the official validator: a diagram the validator accepts can still fail there.
5. When a diagram fails in chat, simplify the label wording first, re-check with
   the validator, and append the defect to `journal/mermaid-defects.md`.

## The defect log makes the drawing better over time

Before drawing a report diagram, read `journal/mermaid-defects.md` — it lists the
traps already hit. After a run, append any new mermaid defect you met (symptom,
cause, workaround). Appending is allowed during runs; changing these rules
happens only on an improvement pass with the user, never silently.
