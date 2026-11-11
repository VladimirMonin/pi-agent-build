# Work Log — memory-ops

Mutation journal: the only trace of memory operations across sessions. The
`<memory>` block is rebuilt every turn, but it is a relevance slice, not an
operation history; a chat report dies with the chat.

## What to write

One line per mutation (create, delete, compress, update):

```
YYYY-MM-DD · mode · old-id → new-id · counters · facts preserved N/N
```

- Ids, modes, counters only. Entry content is NOT logged — the journal must
  not become garbage itself.
- Cleanup without recreation:
  `YYYY-MM-DD · 💀 · deleted: key1, key2 · no facts lost`.
- A series of operations in one session may be one summary line: id pairs
  separated by semicolons.
- Facts are addressed by dotted `key`; lessons by uuid.
- **Skill maintenance counts too.** A pass that fixes defects found in
  `defect-log.md` gets one line with mode 🛠 and the defect labels it closed —
  no memory ids, since nothing in the store changed. This keeps the two
  journals linked: every defect moved to Resolved has a matching work-log line.

```
YYYY-MM-DD · 🛠 · closed defects: <short labels> · memory untouched
```

---

## Entries

<!-- Add new entries below, newest last. -->

2026-09-22 · ✏️ · UPSERT 7 фактов, заменена формулировка: teaching_hub.root,
teaching_hub.schedule_status, teaching_hub.homework_bundle (+впитан homework_publish),
project.pi-polza.repo, project.pi.session-search, project.python621.sql_practice_db,
project.pi-course.provider, pref.async_subagents, pref.memory_brevity · факты сохранены 9/9

2026-09-22 · ✏️ · LESSONS: security 0f2da8de → 03d79d3a (ключ убран из формулировки);
workflow: 04f85853 + edc6fb92 → 5685bec2 (merge) · факты сохранены 1/1

2026-09-22 · 💀 · удалено: lesson 78343c90 (дубль инструкции CATALOG),
lesson bcfd2d8d (дубль факта pi-course.package_manager),
lesson acdd7691 → мягкая замена 17973ced (планирование допустимо без лекции) · факты не терялись

2026-09-22 · 🛠 · закрыты дефекты: утечка ключа в отчёт аудита; правило 9 писало
пример реальным фрагментом ключа; «DONE» без правки (дважды — prefix co-expansion
и указание про dist/); подпроцесс погиб на чтении node_modules/dist; отсутствовала
проверка переполнения блока. Навык 0.1.0-pi → 0.1.1-pi · память не менялась

<!-- Итог 2026-09-22: фактов 22 (было 23), активных уроков 11 (было 14). -->

2026-09-22 · ➕ · workflow.pi_subagent_models · создано 1 · факты сохранены 1/1
2026-09-23 · update · teaching_hub.homework_bundle → teaching_hub.homework_bundle · updated 1, deleted 0 · prior facts preserved
2026-09-24 · 📦 L1 · pref.* 125→23 (+2 user не тронуты) · удалено 108 ключей · 18575→8450 симв. · факты preserved 108/108 · план sha256 2d719bf6
2026-09-24 · 📦 L2 · project.wvm.* 98→46 · удалено 52 ключа · 16678→13453 симв. · preserved 52/52 · 💀-группы G4/G7/G29 НЕ применялись · план sha256 5c657dae
2026-09-24 · 📦 L5 · tool.* 26→9 · удалено 18 ключей · 4019→? симв. · preserved 18/18 · source=user (21 запись) не тронута · план sha256 c3e39450
2026-09-24 · ⚡ L3/L4 · планы готовы, НЕ применялись: уроки вне инжекта (project = полный путь ≠ слаг), выигрыша в блоке нет
2026-09-24 · backup · memory-backup-before-apply.db (@ .pi/memory-audit/2026-09-24) · semantic 270→100 записей, 49297→34945 симв.
2026-09-24 · 🗜️ finish · 18 ключей pref.wvm.* → wvm.* (листовые 2-сегментные, соседей не тянут) · 5 фактов −263 симв., 7 уроков −442 симв. · итог: факты 100/34682, pref.* 6/1339, wvm.* 18/6848, уроки user 11/3330 · backup memory-backup-before-finish.db
2026-09-24 · 📦 L3/L4 · уроки 268→111 записей, 53900→31609 симв.; слито 52 группы, поглощено 225 id; проверка токенов заблокировала 4 группы (не применялись, их записи целы) · backup memory-backup-before-lessons.db
2026-09-24 · ⚠ ИНЦИДЕНТ · apply-lessons.mjs: при правке вызов вставки оказался внутри комментария → удаление 210 уроков БЕЗ замен. Поймано сверкой created_at. Восстановлено из memory-backup-before-lessons.db (210), применение повторено корректно; в скрипт добавлена самопроверка вставок внутри транзакции
2026-09-24 · ✏️ навык · исправлен порог сегментов в описании co-expansion, добавлены достижимость/слои стоимости/apply mechanics, добавлены scripts/*.mjs
2026-09-25 · ➕ · added: wvm.project, wvm.program, wvm.discipline, wvm.env, wvm.s3_acceptance, wvm.open_items (листовые 2-сегментные, соседей не тянут) · 6 фактов, ~2.8k симв.
2026-09-24 · 📤 upstream · опубликованы 2 отчёта по pi-memory 1.5.0: issues #32 (projectSlug/разделители) и #33 (MAX_CONTEXT_CHARS/молчаливая обрезка); черновики и репро в .pi/memory-audit/2026-09-24/upstream/; добавлен факт tool.pi-memory.upstream_reports
2026-09-28 · ➕ · saved: aimedia.orchestration · facts preserved 1/1
2026-09-28 · ✏️ · aimedia.orchestration → aimedia.orchestration · removed transient provider/session routing · facts preserved 1/1
2026-09-28 · ✏️ · subagents.escalation_ladder, orchestration.periodic_codex_audit · external CLI → native Pi SOL6 · facts preserved 2/2

2026-09-29 · 🧱 memory-ops lane suite (12 лейнов, oracle) · группировка+консолидация · факты 240→131 (−109), уроки 229→112 (−117), 44301 симв.; применено 126 групп, 12 групп ПРОПУЩЕНО (задевают source=user, вариант A) · факты user 44/44 и уроки user 12/12 сохранены дословно · probe: блок по-прежнему truncated (8006) · backup memory-before-apply.db · план sha256 plans/*.md
2026-09-29 · 🏷️ tags+budget · retagged 5 NULL-lessons → e:\syncthing\teaching_hub (текст не тронут) · сжаты 10 машинных NULL-уроков в 6 (6321→4965 симв., max 995) · NULL 22/9858 → 13/7167 симв. · facts 240→131, lessons 229→108 · source=user целы: facts 44/44, lessons 12/12 · settings.json: memory.lessonInjection=selective (бэкап settings-before.json) · probe на реальных cwd: WVM/User всё ещё truncated (RM 14k > 8k) · фирменные остатки: teaching_hub 6/6, WVM root работает
2026-09-29 · 🏷️ injector runtime repair · @samfp/pi-memory 1.5.0 dist/index.js original SHA256 8941da2789d4a77d526559f130a701865b9cacb3cfdf5957cdf547239860c4fd → patched 704fc56d932612fd1fa37c9db8db9a5efc308923dcd7cc2e67636f9c42dd6b65 · backed up index.js.pre-memory-ops; no DB content edits · WVM-root 8006/truncated → 7778/full; worktree 8006 → 7911/full; project-local lessons generic prompt 0→2-3; user records raw text hash unchanged 56/56 · patch-injector.py + check-injector.mjs
2026-09-29 · 🏷️ injector v3 follow-up · selective generic worktree prompt originally 0 local lessons, v2 2–3 but admission prompt still failed local-first check; v3 prioritizes local over global lessons and guarantees observed 3/8 local in media-vision/pipeline; original bundle backup unchanged, v3 SHA256 15ca149cb8968f32735fe4ed1647c2bc81c19b3b7993507ec7bb31c6da4236bb · checker full-line + scope + fallback passes · DB owner records not edited

2026-09-30 · new entry · pref.work_slices · +1 fact · facts preserved1/1
2026-09-30 · explicit-owner update · pref.work_slices → pref.work_slices · updated 1, deleted 0 · facts preserved 1/1

2026-10-05 · 💀 dedupe (owner-instructed) · deleted facts: pref.env.shared_venv, tool.pi.codex_sol6_subagent, tool.pi.codex_astra6_subagent · deleted lessons (soft): 006b4078, 194e5194, 49c1b6c6, 953cd93d, 50ef9aed, ff8457e9, 23992ab4 · facts 163→160, lessons 135→128 · source=user untouched (45 facts / 12 lessons) · backup: C:/Users/User/.pi/memory/backups/memory-before-cleanup-20261005-1330.db
2026-10-05 · 🔧 skill 0.1.2-pi · inject-probe: require --db + refuse live DB + pass profile config · check-injector: pass profile config (7/7 OK) · scripts/README → portable v2 · defect-log updated · no DB content changed by this line
2026-10-05 · ✏️ owner-instructed refresh · rewrote (source kept): wvm.next.integration→2026-10-05 git heads; wvm.plan39.pending_fixes→both fixes implemented; project.python621.sql_practice_db→Hub/db path; pi_subagent_models + workflow.pi_subagent_models→no pinned route; tool.pi.provider (consolidation, via UPDATE+embedding=NULL) · facts 160 / lessons 128 unchanged · backup: memory/backups/memory-before-refresh-20261005-1345.db
2026-10-05 · 🗜️+🌀 pass (owner-instructed) · lesson 027b204f compressed 1038→998 (in place, id/project/source kept) · fact tool.pi-memory.injection_rules split → tool.pi_memory_injection + tool.pi_memory_upstream_issues (2-seg leaves, source=consolidation), old key deleted · facts 160→161, lessons 128 unchanged · SKIPPED: 22 project-lesson drops (they ARE injected on backslash cwd — in-project value) and the 34→14 project.wvm merge (−2.3% only, token preservation dominates) · backups: memory/backups/memory-before-split-20261005-1405.db
2026-10-05 · ✏️ owner-requested update · wvm.dev_copy_path, wvm.project, project.wvm.dev_launcher · 3 upserts / 0 deletes · still-valid facts retained; stale DEV-development routes superseded

2026-10-06 · ➕ new entries · saved: pc.autostart_map, pc.llm_servers, pc.lmstudio_autostart, pc.bonsai_cold_start, pc.powershell_quirks, pc.cua_driver · 6 facts, все 2-сегментные листовые (соседей не тянут) · уроков не добавлено (нужные уже есть: security-lesson про Defender/WU + pc.owner_hard_taboos) · дедуп-проверка пройдена (memory_search по autostart/LM Studio/Bonsai/cua/PowerShell/OneDrive — совпадений нет) · facts preserved 6/6
2026-10-27 · 🧱 bulk-apply (lanes S1-S5 + writer) · facts 1342→764 (115 G-групп, absorbed 645), lessons 1076→706 (LR применено 72, заблокировано проверкой токенов 5: LR8/15/21/48/54) · held 14 (source=user и чистые удаления — ждут владельца) · facts preserved 1342/1342 · backup memory-before-apply-20261027-0940.db · probe-after-20261027.db

2026-11-11 · 🧱 cleanup-20261111 волна 1 (канонические планы, 22 полки → 22 плана) · facts 800→706 (−94 поглощено), lessons 732→650 (−82) · facts preserved 800/800 · backup memory-before-apply.db · токен-проверка fail-closed: 3 группы не применены
2026-11-11 · 🧱 cleanup-20261111 волна 2 (конвертация диалектов планов → 201 блок + manual-fix 3) · facts 706→546, lessons 650→508 · facts preserved 706/706 · применение строго последовательно
2026-11-11 · ✏️ pass-B переписи (явное «да» владельца 2026-11-11) · REWRITE source=user сохранён, тексты дословно: project.pi.session-search (+1), archive.rules (+3), screenmemory.architecture.core (+1), pref.explain_style (+1), orchestration.periodic_codex_audit (+1), project.pi-course (NEW-KEEP, +3), lesson 119587ab (+1), lesson b6679208 (+1) · backup memory-before-passB.db
2026-11-11 · 💀 deleted: pref.breakfast_smoothie, pref.altyn_arashan · явное «да» владельца · no facts lost
2026-11-11 · ИТОГ cleanup-20261111: facts 800→535 (−33%), lessons 732→506 (−31%), блок 6007–6443 симв. без усечения · user-записи: facts 77→68, lessons 28→27 (только утверждённые переписи/удаления) · 5 «ЖДЁТ»-предложений «оставить как есть» закрыты без действий; пины сессий (Ж-1/Ж-4), tool.pi.model_catalog/provider, wvm.next.integration, target_platform_current ждут фактов владельца
