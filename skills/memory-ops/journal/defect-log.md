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

## Format

```markdown
## YYYY-MM-DD — <short label>

- **Triggered as expected:** yes / no — <one clause>
- **Issue:** <one or two sentences>
- **Tried:** <what the run did instead, if anything>
- **Impact:** none / minor / significant
- **Suggested fix:** <if obvious; otherwise leave blank>
```

Keep entries to a few lines — this log is read on every improvement pass.

## Before writing "DONE"

This log records what **happened**, not what was intended. After an improvement
pass, verify every claimed change against the actual file with a `grep` for the
term you believe you added — then write the entry. An entry that claims a fix
which does not exist is worse than no entry: the next pass skips a real defect.
This rule exists because it was broken twice in one session.

---

## Entries

<!-- Open defects below. Move fixed ones to Resolved. -->

<!-- None open. Five defects found in the first live session were all fixed in
     0.1.1-pi; see Resolved. -->

---

## Resolved

<!-- Fixed defects — brief, with the fixing version. Do not erase history. -->

### Fixed in 0.1.2-pi (2026-10-05 — after the portable-v2 bundle replacement)

- `scripts/inject-probe.mjs` defaulted to the live `memory.db` and then let the
  injector update `last_accessed`/embeddings — a diagnostic that mutates the
  owner's store. It now requires an explicit `--db` and refuses the live path.
- the same probe (and `scripts/check-injector.mjs`) called `buildContextBlock`
  with `{lessonInjection}` only, omitting the profile `memory` config. With the
  portable-v2 scope filter that silently dropped `project.*` facts, so probes
  and the checker measured a different selection than production — the checker's
  `WVM: missing wvm.parallel_worker_limit` was a false failure. Both now read
  `settings.json` (`--settings=` overrides) and pass the whole config; the
  checker passes 7/7 cases + project-tag coverage 15/15.
- `scripts/README.md` presented `patch-injector.py` (historical v1) as the update
  procedure although the portable v2 patch (`pi-agent-build/patches/
  memory-windows-runtime`, `apply.py --check`) supersedes it. The README now
  points at v2, documents the reapply-after-`pi update` step, and marks v1 as
  historical; the typebox shim note now names the real vendored source.
- the full audit's budget headline leaned on the `--estimate` figure as a
  "lower bound" and on a probe that omitted the profile config; both are now
  stated as potential-cost/per-profile, not as a lower bound on the real block. 

### Fixed in 0.1.1-pi (2026-09-22 — after the first live audit)

- the secrets sweep reproduced a key fragment in its own report → hard rule 9
  ("a secret is never reproduced in an artifact") + an explicit redaction
  verification step in the full audit;
- hard rule 9 itself first used a real key fragment as its own example, and the
  fragment was copied into this journal → the rule now names only the public
  provider marker; both files redacted;
- the improvement pass twice wrote "DONE" for a change that had not been made
  (prefix co-expansion; the dist/ guidance) → "Before writing DONE" added to
  this journal's format section, requiring a `grep` verification of each claim
  before the entry is written;
- no mode tested whether the store overflows `MAX_CONTEXT_CHARS` → the audit
  now opens with the truncation/prefix-expansion finding;
- **prefix co-expansion was undiscovered** → documented in
  `00-shared-rules.md` (a hit pulls its whole 2-segment domain: limit 20 for a
  semantic hit, 5 for an FTS hit) and added to the value scale, since a short
  record in an oversized domain is the most expensive kind;
- **soft delete was undocumented** → `memory_forget` only sets
  `is_deleted = 1`, so audits must filter it out; documented in the runtime
  section and added to the inventory step and gate;
- **the `source` enum was incomplete** → `session:unknown` is written by
  session-end consolidation and must be treated like `consolidation`;
- a subagent tasked with the audit wandered into `node_modules/dist` → brief
  guidance added (never read a package's implementation during an audit).

### Fixed in 0.1.0-pi (2026-09-22 — port to pi-memory)

- replaced `save_memory`/`delete_memory` with `memory_remember`/`memory_forget`
  throughout;
- replaced `list_files`/`search_files`/`read_file` with `ls`/`grep`/`read`;
- corrected the injection model: per-turn, not a frozen session snapshot;
- replaced the "slot limit" with the real `MAX_CONTEXT_CHARS = 8000` budget;
- documented that facts are selected by relevance while **all** lessons are
  injected — lessons are the expensive class;
- documented that `memory_remember` for a fact is an in-place upsert and forces
  `source: user / confidence: 0.95`; lesson adds deduplicate (Jaccard ≥ 0.7);
- added the 🧬 Consolidation drift mode (`instructions/08-drift.md`) — on pi,
  memory is also written by a background model without a human filter;
- added the "never prune `source: user`" rule and the `confidence`/`source`/
  `last_accessed` metadata to the audit;
- added the durable-vs-volatile split (snapshots are rewritten, not deleted);
- added cross-store duplicate handling (fact ↔ lesson);
- added a secrets sweep to the full audit;
- renamed the skill's own artifacts to English; user-facing output follows the
  user's language.

### Carried over from Chatbox 0.0.3 (2026-09-20 — verification + restructuring)

- defect logs and versioning were absent → added;
- a sample in cleanup mentioned another skill's path → false validator failure
  → rephrased without a path;
- runtime behaviour was undocumented → described;
- the 500/1000 character conflict would cut a coherent cluster → clarified:
  500 is an appending target, 500–1000 is cut only for different storylines;
- checklists duplicated instructions and drifted → merged into the modes'
  "Gates", the `checklists/` folder removed.2026-10-05 · 07-new-entry · quick-start estimate required --db despite wording; own temporary SQLite probe copy initially remained open at cleanup, removed after process exit; estimate completed on copy
2026-10-27: Step 2/3 of 09-bulk-apply say lanes must emit the contract format but give no
lane brief template and no timeout guidance; a parallel-subagent lane run (5 lanes) burned
one full 30-min wave before the plan format and write-chunking were corrected. Suggested:
add a copy-paste lane brief + "3-5 blocks per call" rule to 09-bulk-apply.md.

## 2026-11-11 — полки пишут в разных диалектах, применители молча пропускают
Найдено в прогоне cleanup-20261111: 22 полки дали ~6 диалектов формата плана
(`НОВОЕ:` vs `НОВОЕ ЗНАЧЕНИЕ:`, `УРОК:` vs `ГОТОВЫЙ ТЕКСТ УРОКА:`, метаданные
в заголовке, `УДАЛИТЬ: = ВОШЛО`, концевая backtick-ловушка). apply-facts/apply-lessons
и validate-apply такие блоки пропускают БЕЗ предупреждения — из ~300 блоков молча
выпало ~290. Статус: в прогоне спасено конвертером; для навыка нужны (1) счётчик
нераспознанных ###-блоков с предупреждением в validate-apply, (2) эталон-пример
формата в lane-contract.

## 2026-11-11 — validate-apply: окно поиска ключей тянулось до конца блока (исправлено)
Имена файлов/путей в ЧТО СОХРАНЕНО ловились regex-ом как ключи (ложные нарушения).
Исправлено в прогоне: окно ограничено метками ВОШЛО→ЧТО СОХРАНЕНО и УДАЛИТЬ→конец.

## 2026-11-11 — inject-probe --estimate: slug() отличается от projectSlug плагина
Для cwd вида C:/Users/User модель даёт слаг "users" (пропускает имя пользователя ОС),
плагин — "user". Модель уроков в --estimate поэтому считает не тот набор; замер
врёт на home-cwd. Верить пробнику (как и написано в выводе), но дефект стоит починить.
