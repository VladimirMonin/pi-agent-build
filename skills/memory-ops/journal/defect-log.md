# Defect Log — memory-ops

Append-only record of what this skill got wrong, unclear, or awkward during
real runs. Primary evidence for improvement passes — without it, the next
improvement pass has to guess.

## How to read this journal

- **Entries** — open defects: found in a run, not yet fixed.
- **Resolved** — history of what was fixed: short lines with the version that
  fixed it. Do not erase — the history of breakage shows where the skill will
  break again.
- Fixed a defect → move it to Resolved in one to three lines; never erase it.
  A healthy log has few open entries.

## What belongs here

- Instructions that misled the run or did not apply to the case.
- Steps that were missing and had to be improvised.
- References that did not resolve, or pointed somewhere unhelpful.
- Outputs weaker than the instructions promised.
- Cases where the skill fired when it should not have, or stayed silent.

## What does not belong here

- Feature requests and preferences — those are conversation.
- Anything about the user's private context.
- Speculation about causes. Record what happened; leave diagnosis to the
  improvement pass.

## Entries

<!-- Add new entries below, newest last. -->

<!-- В публичном издании сборки журналы поставляются пустыми: записи реальных
     прогонов — приватные данные владельца и живут только в локальной копии навыка.
     Открытые дефекты локальной копии на момент выпуска вынесены в release notes. -->
