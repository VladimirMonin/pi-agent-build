# Changelog — pi-memory-ops

History of corrections and measured behaviour. Several entries are
**version-bound**: they describe the installed `@samfp/pi-memory` build of the
day and may not hold for yours. When this file and your observation disagree,
observation wins — and update this file.

## 2026-11-11 — 1.0.0, выпуск по итогам полевого прогона (cleanup-20261111)

Полный прогон по живому складу (800 фактов / 732 урока) вскрыл дефекты — все
закрыты в первопричине (см. journal/defect-log.md):

- **формат плана — единый диалект с образцом** (`references/lane-contract.md`);
  запрещены `НОВОЕ:`, `УРОК:`, `= ВОШЛО`, метаданные в заголовках, листовые ключи;
- **молчание запрещено**: валидатор и оба применителя теперь помечают каждый
  нераспознанный ###-блок как нарушение/проблему (раньше 290 блоков из 400
  молча выпадали и потребовался конвертер диалектов);
- **микропротокол полки** в договоре: запись ≤700 символов, чанки 3–5 блоков,
  читать кусками 100–150 строк (полки, писавшие всё одним ответом, гибли по
  лимиту длины);
- **волны ≤3 полок** (большая параллельность дала 429 «too many concurrent»);
- **`inject-probe --estimate`**: слаг больше не пропускает имя пользователя ОС
  (сверено с плагином: путь вида …/Users/Anna → "anna");
- приёмка планов: сверка «сколько блоков рапортовала полка ↔ сколько применилось»
  (Gate в 09-bulk-apply).

Полевой прогон: факты 800→535 (−33%), уроки 732→506 (−31%), блок без усечения;
факты не терялись (дословные склейки, fail-closed токен-проверка, бэкапы).

## 2026-11-11 — 0.2.0, portable edition (Windows + macOS, student-ready)

Restructured for portability and honest documentation after an independent
three-way review (skill audit, build reality check, parallel-mode design):

- all machine-specific absolute paths removed from scripts and docs; every
  script resolves `--db`/`--settings`/`--bundle` from arguments, then
  `PI_MEMORY_DB`/`PI_CODING_AGENT_DIR`/`PI_MEMORY_BUNDLE`, then the platform
  home directory;
- `scripts/db-copy.mjs` added (consistent `VACUUM INTO` copy) so backups do not
  depend on a `sqlite3` CLI being installed (often absent on Windows);
- `scripts/export-lanes.mjs` added — read-only export of disjoint lane slices,
  so lane helpers work on files instead of the live database;
- `scripts/validate-apply.mjs` now takes `--db`, `--dir` and plan files as
  arguments (was hardcoded to one past run) and validates **all** plans of a
  run in one call, including cross-plan disjointness;
- the historical Python patcher (v1) removed (dead anchors, second scripting
  language); the `check-injector.mjs` regression is now generic
  (`--cases=<json>` or cases synthesised from the store);
- runtime claims corrected against the installed code — injection is
  `context-hook` (ephemeral message before the latest user message) by default,
  `system-prompt` is legacy; stock builds truncate with `... (truncated)`,
  scoped-injection builds select whole records by section quotas and emit no
  marker; a patched build filters sibling expansion by project scope (the
  2026-09-29 leak note below applies to stock only);
- the broken first command fixed (`inject-probe --estimate` requires
  `--db=<copy>` like every probe);
- load-bearing rules moved out of this changelog into `09-bulk-apply.md`
  (mandatory `validate-apply`, serial apply) and `references/lane-contract.md`
  (chunking 3–5 blocks, resume protocol) — a changelog is history, not procedure;
- description got portable triggers (EN + RU) and an explicit near-miss split
  from `chatbox-memory-ops`; permanent file map, environment declaration and
  `evals/` added.

## 2026-10-27 — parallel lane run on a 2355-record store (1342 facts / 1076 lessons) + bulk apply

(`~/.pi/memory/ops/audit-20261025/`). Corrections that changed how lanes are
run (now folded into `09-bulk-apply.md` and `references/lane-contract.md`):

1. parallel read-only lane subagents work well, but the 30-minute default
   timeout kills them mid-plan — brief lanes to write their plan in chunks of
   3–5 blocks per call, and revive a timed-out lane with `resume` + "finalise
   now" (context is kept, no re-analysis);
2. lane briefs must demand the plan contract format **verbatim** — free-form
   plans need a full conversion pass before apply, and lesson plates need their
   merged texts written at that point;
3. a pre-apply validator is mandatory at this scale: it caught "held" blocks
   sitting inside the applied sections (apply scripts do not read warnings —
   only `💀` in the title skips a block, and only in apply-facts), a
   `source=user` key inside a merge's delete list, and backticked `ПРОЕКТ:`
   values (apply-lessons stores the backticks literally → unreachable lessons);
4. apply-lessons deletes **all** covered ids and inserts a fresh uuid — the
   canonical id is not kept;
5. the token check failed closed as designed: 5 of 69 lesson plates were
   correctly not applied;
6. merges shrink the store (facts −43 %, lessons −34 %) but the injected block
   moves little while unaddressed records keep the expanding form — budget
   wins come from finishing VERIFY-NEEDED leftovers, not from merging alone.

## 2026-10-05 — runtime-state repair after the portable-v2 bundle swap; full audit of the live store (163 facts / 135 lessons)

Corrections that changed measurement discipline (machine-local patch workflow —
see `scripts/README.md` for the generic form):

1. `inject-probe.mjs` requires an explicit `--db` and refuses the live
   `memory.db`, and passes the profile `memory` config (`factProjectAliases`,
   `lessonInjection`) into the collector — without it the scope filter silently
   drops `project.*` facts and the measurement is wrong;
2. `check-injector.mjs` loads the same config and now passes 7/7 + project-tag
   coverage;
3. the local runtime patch must be **reapplied after every `pi update`**.

Measured blocks with the real config stayed under the 8000 cap but sat near it
(6991–7990 for the probed cases); `--estimate` is a potential-cost model, not a
lower bound.

## 2026-09-29 (follow-up) — embedding hits and sibling expansion bypass the project filter on STOCK builds

Prior claim that `project.wvm.*` was categorically dead was too strong: FTS
hits are excluded on Windows, but embedding hits can leak across projects on
stock `1.5.0`/`1.6.1`. The scoped-injection patch filters siblings by scope;
treat this note as a stock-build fact only. Measured with the patch: local
lessons rose from 0 to 2–3 on a generic worktree prompt (8 on a topic-specific
one); probes fit 8000 without cutting a record.

## 2026-09-29 — mode 🏷️ Tags & budget added (WVM run, 240→131 facts, 229→108 lessons)

Two measured corrections that invalidate earlier reasoning:

1. the injector's `formatSemantic` **drops the first key segment**, so
   `project.wvm.x` displays as `wvm.x` — counting `project.*` lines in the
   block reports 0 even when the facts are present; reachability must be
   checked against raw keys (match by full record value);
2. `lessonInjection: "selective"` in the profile settings is a real budget
   lever (measured 9436 → 217–4608 chars on the same store).

Also recorded: the true-cost method (patch a throwaway copy of the bundle for
`MAX_CONTEXT_CHARS`, then delete it), the "one project, N worktrees" tag
trade-off, and the leaf-depth lever.

## 2026-09-24 — co-expansion rule corrected; mode 🧱 Bulk apply added (270 facts / 262 lessons)

Corrected the co-expansion rule (the 2-segment threshold was missing and the
`teaching_hub.task_map` example was wrong); added **Reachability** (tiers, the
`project = slug` lesson filter, the backslash-path trap), **key shape as a
lever**, the rewrite rule for `source=user` records, language notes; added
mode 🧱 with the lane contract, machine-actionable plan format, apply
mechanics and merge verification; added `scripts/` (`db-copy`, `inject-probe`,
`apply-facts`, `apply-lessons`, `patch-entries`). Two earlier conclusions of
that run — "lessons with a full-path project never inject" and "the fact
domain drags all siblings" — turned out to depend on the cwd path form and on
the key depth respectively, and were only settled by running the real
injector instead of reading the DB.
