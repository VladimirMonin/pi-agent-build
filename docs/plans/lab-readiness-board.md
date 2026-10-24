# Readiness — переносимый стенд и выпуск следующей сборки Pi

## Кандидат выпуска Pi 1.4.0 build.2

[Release notes](../releases/pi-1.4.0-build.2.md). Все version pins build.1 сохранены; новый срез — Session Search no-HOME/read/scan/FTS fixes и bounded CBM mixed-EOL admission. Независимые source verdicts: Session Search **ACCEPTED** (retained 13 tests / 36 native scenario cases и fresh partial-scan discriminator), CBM **ACCEPTED** (9/9). Это не повтор общей Pi 1.4 матрицы.

Preserving рабочее обновление Windows завершено: actual Pi и семь SDK nodes **1.4.0**, Polza **0.2.2** Both, Memory **1.6.1** сохранён, Search **1.6.0 patched**. Обычные Code/Task SDK startup, registration/tools, исходные main-model selections, шесть CLI surfaces, patch Check и verifier **0 failures / 0 warnings** приняты; сохранность исходных данных/векторов и SQLite integrity подтверждена. **Pi Code/Task можно запускать**: публикационная стадия не удерживает рабочие окна закрытыми. Новый main-model live answer в этом ремонте не выполнялся; прежние Pi/Trace/Context7/Polza checks переиспользуются только для неизменённых inputs и в исходном scope.

**Исходный semantic top25 FAIL сохранён.** Реальный provider/SDK получил query и вернул результаты, но нужная читаемая сессия не вошла в top25. Offline replay: сохранённый vector — cosine rank39, active RRF rank95 (pool125); один свежий exact-payload embedding — cosine rank33. Saved/fresh vectors различаются (cosine≈0.99578); historical provenance не сохранён, точная причина небольшого расхождения unknown. Новый implementation defect не установлен; это известное ограничение model/representation/ranking, не PASS полноты поиска и не основание для rollback/reindex. [Подробности и scope](../fixes/session-search.md#scope-и-качество-выдачи).

Финальные source/docs gates и поставка относятся к этому кандидату; commit, аннотированный `pi-v1.4.0-build.2`, source ZIP/checksum и GitHub readback выполняются отдельно после приёмки. Старые notes/receipts не переписываются.

## Исторический принятый выпуск Pi 1.4.0 build.1

[Release notes и область приёмки](../releases/pi-1.4.0-build.1.md). Exact Pi 1.4.0 / Node 25.8.1 / npm 11.11.0; Polza 0.2.2 закреплён опубликованным commit в manifest и Code/Task. Source, установленный Windows candidate и один public Context7 resolve/query chain разделены в notes; остальные неизменённые результаты R/B переиспользованы в исходной области.

Обязательный R1 sanitized-child finding закрыт адресным независимым regression; исходный aggregate 23 PASS / 1 FAIL сохранён как исторический, а не переименован. Итоговые source/Tree/package gates относятся к финальному согласованному кандидату. Рабочая установка владельца не переключалась, личные profiles/auth/settings/память/история и Goal X не менялись. Обычный установочный маршрут — [INSTALL_FOR_AGENTS](../../INSTALL_FOR_AGENTS.md).

## Исторический принятый выпуск Pi 1.3.0 build.1

[Release notes и полный состав](../releases/pi-1.3.0-build.1.md); [архитектурные решения](../notes/pi-1.3.0-upgrade-decisions.md). Evidence ID: `pi130-review03`. Publication не является рабочей установкой.

Принятый состав: core **1.3.0**, Memory **1.6.1 patched**, MCP Adapter **5.3.2**, Subagents **0.79.1**, Intercom **0.17.1**. Goal X **0.32.3** и остальные пакеты/backends сохранены. Sole MCP owner и порядок Subagents → Goal X → Intercom не менялись.

Первый fresh1.0.4 install разрешил caret dependencies в1.3.0 и падал при SDK import. По техническому решению oracle промежуточный граф не ремонтировали: сначала exact Memory1.6.1 lifecycle patch, затем **новый** PLAN/PREPARE/install согласованного1.3.0. Все внутренние Pi dependency edges и telemetry exact1.3.0, chord отсутствует; actual SDK import/core local-mock PASS. Failed root/evidence сохранены, guards/npm algorithm не менялись.

Runtime local/synthetic checks: Code/Task loading13/10 без errors/warnings/fetch; Both Memory user/tool/custom/empty/error/fresh/session-reset и прежние runtime contracts PASS; Both installed Adapter discovery/search/describe/proxy/direct-call PASS. Actual detached child → supervisor ask/reply → useful completion + Intercom message с одним wake совместного question/message exchange (поздний distinct completion учитывается отдельно), send/receipt/ask-reply, resume с новым output и сохранением прежних bytes, client restart/extension-state и live-owner refusal в другом реальном SDK/Pi process с тем же saved session UUID — PASS. Goal custom checkpoint, provider abort versus Stop, native resume и offline-audited completion PASS; Goal patch не понадобился. Production Polza + native1.3 transport synthetic SSE reasoning/tools/usage/DONE/RUB-once PASS. Full Both profiles: Session Search actual worker/search/read/escape/cleanup и Trace off→on→off с JSONL/HTML PASS. [Executable fixtures и measured scope](../../tests/sdk/README.md).

Reviewer proof-gap corrections: actual Memory profile/case/ancestor/link refusal before imports/settings I/O PASS on nine sacrificial controls, with installed Code/Task lifecycle PASS and settings byte restoration. A fresh coordination case verifies initial AND resumed child actual entrypoint/SDK path/version/hash plus active SDK class identity; wrong-class/hash controls refuse. Child completion is physically held through joint question/message injection and parent settlement: one measured joint wake; after release, one separately measured completion notice/wake carrying the run ID. Эти proof gaps не объявлялись product failures и не потребовали production rewrites.

Common gates независимо повторены: repository verifier0/0, script regressions24/24, Both canonical patch checks PASS. Independent fresh Memory Both/9 guard negatives, gated coordination/actual child identity и шесть bundled CLI cases PASS. Goal/Polza/stdio Adapter/full-profile receipts переиспользованы только для unchanged relevant inputs. Installed-state verifier:0 failures/1 явный NOT TESTED warning для WVM/optional/live/POSIX scope; known startup metadata теперь валидируется strict schema/pinned versions, не очищается/repair. Focused metadata negative tests PASS.

**Terminal output-limit discriminator PASS:** по уточнённому oracle решению исправлен только fixture stimulus: output128=maxTokens128, total129, contextWindow65536 вместо output2/max128/context8192. Actual bundled CLI bare `-p`, explicit text и resumed terminal печатают только текущий partial, настоящее truncation warning и exit1; stale `activeTools` JSON отсутствует. Native JSON показывает один terminal length response без context edits/recovery/compaction/retry; JSON exit0 соответствует его контракту. Normal/persisted-tools resume PASS отдельно. Обе production print реализации оставлены stock, core patch не обоснован этим case. Прежний пустой вывод при early-length recovery остаётся сохранённым FAIL/непринятым наблюдением; прежняя атрибуция terminal print defect отозвана, история не переписана.

**Final independent acceptance PASS в release scope.** Последним техническим шагом actual installed Adapter выполнил WVM health/initialize/tools-list и discovered read-only `settings_schema`: Code explicit legacy SSE, Task explicit streamable HTTP, по35 callable tools/325 schema fields. Это два owned SDK cases, не полная матрица profile × transport; full profiles проверены отдельно. Первый private collector FAIL/timeout сохранён; fresh bounded schema collector с явным освобождением собственных HTTP requests завершился естественно. Default output sizing/самостоятельный HTTP teardown, paid/live-provider/visual TUI/native POSIX/OS containment не заявляются. Рабочая установка/restart остаются отдельным post-exit этапом; credentials, embeddings/models/dimensions и данные не менялись.

**Исторический baseline до 1.3.0:** [Pi 1.0.4 build.6](../releases/pi-1.0.4-build.6.md): Memory1.6 установлен Both; scoped whole-record automatic upstream provider/RRF recall и ephemeral context-hook, четыре runtime fixes. Native SDK Both и installed real Polza Russian canary PASS;2 successful embedding requests на synthetic facts, без personal reindex. SQLite backup вне Git, Qwen1024d/DeepSeek roles разделены; нужен restart для новых sessions/backfill. Loading13/10 clean, regressions24/24. Предыдущий [Pi 1.0.4 build.5](../releases/pi-1.0.4-build.5.md): MCP Adapter5.1.0 установлен Both, single owner, existing config сохранён. Native WVM/Context7/Fetch/Brave checks PASS; WVM после smoke закрыт. Fresh loading13/10 errors0/warnings0/fetch0. Предыдущий [Pi 1.0.4 build.4](../releases/pi-1.0.4-build.4.md): Session Search1.6.0 установлен Both; exact profile/runtime patch, native workers1/1 на профиль, own/extra/archive read и escape rejection PASS. Real configured Polza provider synthetic hybrid canary PASS (2 requests); без personal reindex. Both fresh loading13/10 errors0/warnings0/fetch0, regressions24/24, verifier0/0. Предыдущий [Pi 1.0.4 build.3](../releases/pi-1.0.4-build.3.md): Inspector1.3.0 Both и Serena wrapper0.9.20 Code; Agent1.7.0/Pyright не меняются. Both loading13/10 errors0/warnings0/fetch0; native Serena symbol smoke и synthetic Inspector UI resize/paging/search/copy dispatch PASS. Visual TUI/editor/OS clipboard NOT TESTED. Windows regressions24/24, verifier0/0. Предыдущий [Pi 1.0.4 build.2](../releases/pi-1.0.4-build.2.md): только Subagents0.76.1, GoalX0.32.3, Intercom0.16.1. Both loading13/10 без errors/warnings/fetch, короткий synthetic wake/legacy-goal и двухпроцессный Windows broker smoke PASS; Windows regressions24/24, repository verifier0/0. Goal X preset и load order сохранены. Короткий алгоритм и следующие этапы — [plugin updates](plugin-updates.md). Предыдущий срез: минимальное core-only обновление source pin до exact stable **Pi 1.0.4**, без обновления плагинов. Владелец уже обновил рабочий Pi; image settings явно включены в templates и живых Code/Task. Core SDK local-mock и repository verifier PASS. Владелец разрешил публикацию минирелиза `pi-v1.0.4-build.1` (commit/push/tag/GitHub release), без расширения runtime support claims. [Scope и проверки 1.0.4](../releases/pi-1.0.4.md). Исторический проект ниже: обычное обновление до exact stable **Pi 1.0.2** и release репозитория. По прямому указанию владельца — без VM, Windows Sandbox, native runner и новых isolation frameworks. Первоначальный no-live boundary отменён последующим прямым запросом владельца: рабочая Windows теперь обновлена после выпуска, с backup и без миграции auth/DB/sessions. Основной [план D0–D6](lab-repeatability-and-portability.md); [runbook](../pi-upgrade-workflow.md); [паспорт](../lab-stand.md); [evidence](../lab-evidence.md).

## Historical state — Pi 1.0.2

**Build.3 source integration:** `pi-polza` **0.2.1** опубликован как [v0.2.1](https://github.com/VladimirMonin/pi-polza/releases/tag/v0.2.1); manifest/Code/Task закрепляют commit `cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139`, annotated tag object `a93589ecd0075d3f4c34eb1f13bda891c5983d8c`. Plugin evidence из принятого upstream handoff: **203/203 offline**, включая **47 native** на actual installed Pi1.0.2 с synthetic SSE; audit/pack PASS. Live acceptance **новой сессии** сообщена владельцем; не fresh Both runtime нового payload и не полный background-live. Core/profiles/patches build.2 evidence переиспользуется только для неизменённых inputs. `memory-ops` **1.0.1-public** включён из предшествующего commit, skill bytes не меняются. Source gates и ограничения — [build.3 notes](../releases/pi-1.0.2-build.3.md); новый repository tag/release публикуется отдельно, install/profile/auth/Goal X/runtime mutations здесь нет. Исторические milestones ниже не являются статусом build.3.

**Build.2 follow-up:** upstream Todo2.12.0/Subagents0.76.0/AstGrep0.2.1 исправляют host typebox peers; adapter — единственный MCP owner (`-builtin:mcp`). Владелец подтвердил чистый фактический TUI startup. Both loading13/10 с actual working Core: errors0/warnings0/fetch0; functional/local-mock и CLI/RPC EOF PASS; Windows regressions24/24. [Commands / next-update checks](../releases/pi-1.0.2-build.2.md). Исходный build.1 verifier0/0 не покрывал TUI warnings — это отдельно исправленный пробел проверки.

- Owner изменил target: официальные npm/latest и GitHub releases/latest подтвердили **1.0.2**, draft/prerelease false; release опубликован 2026-10-04. Source branch `update/pi-1.0.2`; runtime manifest, оба templates и preparation sample согласованы с exact target.
- Pi 1.0.2 реально установлен: CLI `--version`/`--help` natural exit0. Core SDK+AI peer exact1.0.2: один локальный mock response, `agent_settled`, cleanup0, natural exit0; provider/auth/live calls не проверены.
- Code/Task реально загрузили 13/10 активных extensions, без load/lifecycle errors; оба прошли локальный SDK mock и natural cleanup. Trace/background filters сохранены, Trace не загрузился. Позднейший functional срез дополнительно проверил Todo CRUD, get_goal, synthetic memory FTS и subagent management в обоих; CLI RPC get_state/prompt/get_goal и exact Pi/AI1.0.2 child identity естественно завершились. Полное subagent execution/live providers NT; [release scope](../releases/pi-1.0.2.md).
- Холодный локальный multilingual embedder попытался скачать веса Hugging Face; fetch был запрещён test fixture, память перешла в FTS-only. Blocked attempts сохранены; semantic embeddings не объявлены PASS.
- Both installed verifier: failures0/warnings1; exact 15/12 package identities, все canonical patches и external versions PASS. CBM/Serena private stdio initialize/tools/list:17/29 tools; tools/call/LSP/indexing отдельно pending.
- Python3.14 source-build `pyyaml==6.0.2` завершился Win32 error; recovery Serena1.7.0 с managed Python3.12.10 успешен, выбор закреплён в manifest/installers/schema. Кеш PowerShell modules, попавший в synthetic cwd, сохранён приватно; `PSModuleAnalysisCachePath` теперь явно направлен в private TEMP.
- Повторный Both Apply прошёл actual VERIFIED INSTALLED-STATE NO-OP без npm/package/launcher writes. Public core SDK smoke также реально выполнен. Windows regressions24/24 и installer fake15/15 PASS; эти tests не заменяют actual runtime.
- Trace Code/Task off→on→off PASS: 6 SDK + 6 CLI runs с local mock, actual JSONL/HTML artifacts, natural exit и неизменёнными filters; [recipe](../trace.md). Browser UI/live providers не проверялись.
- [Goal X preset](../goal-autonomy.md) применён в живой Windows по прямому запросу владельца и входит в оба установщика: unlimited, implicit continuation, Oracle/Auditor high; real settings loader и обе установки проверены.
- Scoped Windows SDK/CLI/RPC/functional checks и independent read-only review приняты **OK with notes**; WVM LAST отдельно оценён: candidate SSE **NT**, HTTP **NT** (optional off, no copied endpoints/auth), adapter KEEP; **main / pi-v1.0.2-build.1 / GitHub Release выпущены** на `e95cd6e`, безопасный ZIP проверен по SHA256. Владелец дополнительно получил рабочий Core **1.0.2** вместо0.87.0: actual CLI/SDK1.0.2, Both verifier **failures0/warnings0**, config/payload/patch guards PASS. Данные/auth не мигрировались, executable/settings rollback сохранён приватно; existing exact npm и15/12 packages использованы без ненужной переустановки. Прежние OS isolation failures остаются FAIL/NOT TESTED, но больше не являются обязательными gates обычного обновления.

## Historical preparation — frozen Pi 1.0.0

- Новая source branch: `lab/pi-1.0.0`, от docs candidate `53112c7`; runtime source исследовательского0.99.1 — `b31ca02`.
- Working main/runtime baseline: `030adfa` / Pi0.87.0; его profiles/data не изменяются. Разрешён будущий перенос **repository source** в main/tag/GitHub Release, не live-profile switch.
- Перед первым runtime manifest edit официальный GitHub stable и npm dist-tags повторно сверены: **1.0.0**, draft/prerelease false. Exact target закреплён на цикл; candidate manifest и оба `lastChangelogVersion` теперь **1.0.0**. Private target installation/runtime acceptance ещё NOT TESTED.
- Fresh exact npm source payloads прошли guarded patch lifecycle: Code5/Task3 contexts, 96 CLI actions — stock/check/apply/check, apply NO-OP, unknown drift и wrong-version refusals, byte-exact restore. Trace `--restore` раньше перезаписывал unknown current files; исправлен отказ и проверка полного backup до первой записи, 8 focused synthetic regressions PASS. Independent source review OK; supplied tests reviewer не повторял. Это не installed Pi 1.0.0/runtime acceptance.
- Trace остаётся pinned installed package; оба canonical templates теперь используют `extensions: []`, manifest отражает installed-disabled. Windows/POSIX verifier проверяют filters, installer merge regression сохраняет off. На этом историческом source-этапе actual loading/off→on→off ещё не проверялся; позднейший Pi 1.0.2 runtime result указан выше.
- Исходные AGENTS/instructions/passport/runbook/evidence docs приняты в initial commit `833d2fe` до runtime edits. Filesystem-only preparation/schema/synthetic config fixtures реализованы; public native dummy/managed fixtures подготовлены в `tests/lab/native/`; mock/SDK и actor gate ещё не приняты.
- Second-machine/VM replay и usable controlled native runner/actual SDK/env/default acceptance — TODO/BLOCKED по evidence. Native public source исправил номера Win32 enum и 1-byte BOOLEAN encoding class21. Последние bounded actual helpers остановились до actors; последняя причина — non-NULL opaque class22 `SecurityAttributes`, cleanup/preservation PASS в failed packet. Scalar `Flags` теперь сохраняется и сравнивается без ошибочного требования zero; подтверждённого TOKEN/CLAIM ABI для opaque payload пока нет. Native boundary остаётся непринятой.
- Альтернативная [Windows Sandbox capsule](../../tests/lab/windows-sandbox/README.md) теперь имеет filesystem-only PLAN/PREPARE, guest-only dummy sources и 18 source/preparation checks. Network/clipboard/audio/video/printers/vGPU выключены в XML, mappings только readonly input и новый private output. Source review OK с ограничениями; actual VM/host cleanup/SDK acceptance NOT TESTED. Owner разрешил feature enable без автоматической перезагрузки: feature включена с `-NoRestart`, Windows вернула `RestartNeeded=true`; до ручной перезагрузки actual VM не запускается. Это не обход/новый PASS прежнего restricted-token runner.
- Historical0.99.1 incidents/partial approvals остаются в [исторической доске](pi-0.99.1-execution-board.md); новая goal/release не переименовывает их в PASS.

## Historical progress D0–D6

Эта таблица сохраняет прежний план. Machine-B/native requirements отменены владельцем для текущего обычного обновления; непройденные проверки не переименованы в PASS.

| Этап | Статус | Проверяемый результат / следующий шаг |
|---|---|---|
| D0 inventory | PASS (source inventory only) | `docs-initial-v1`: source ref + selected private source bytes/hashes, disposition и gaps; personal runtime data не читались, actors0 |
| D1 инструкции/AGENTS | PASS (initial docs) | AGENTS каталог6, BUILD.LabUpgrade и related rules; `docs-initial-v1`:15Markdown/121targets/1anchor/errors0, frontmatter/catalog0 errors, safetyBoth/no findings; начальный doc changeset |
| D2 паспорт/runbook/evidence | PASS (initial docs) | Документы/current/proposed APIs разделены; repository-only verifier0failures/0warnings, diffcheck0/manual doc review; runtime actors0. Initial commit не означает stand/runtime acceptance |
| D3 executable preparation/fixtures | PARTIAL (preparation PASS) | `lab-stand.ps1`/schema/sample; `stand-tests-v1`:44 focused checks, source relocation/root Unicode, exact prepared NO-OP, metadata-before-DB refusal, owner/ACL/ancestor/reparse/source drift. Composed Windows23/23, installer fake15/15, preflight15/15; public native source/managed fixtures подготовлены; actual native/SDK acceptance не получена |
| D4 машина B | NOT TESTED | Найти независимое Windows окружение/VM, replay по repo/docs; alternate root на этой машине недостаточен |
| D5 controlled native/runtime | BLOCKED (gate, не lifecycle цели) | Новый bounded frozen attempt/raw review и actual baseline SDK/env/default acceptance в разрешённом scope |
| D6 final readiness/handoff | TODO | Final composed/doc checks, truthful readiness и старт target migration |

## Historical Pi 1.0.2 release milestones

| Веха | Статус |
|---|---|
| Исходная документация до runtime changes | PASS (initial doc changeset; stand execution pending) |
| Portable stand/actual native boundary | NOT IN CURRENT SCOPE — owner explicitly rejected OS isolation; historical proof NOT TESTED |
| Exact target manifest/installer/verifier/patches | Pi1.0.2 installed; Both identities/patch/verifier PASS; full functional acceptance pending |
| Trace default-off и explicit on/off оба profiles | PASS — Both SDK/CLI off→on→off, JSONL/HTML, natural exit; browser UI NT |
| Final target Code/Task tests/no-op | Loading/local mock PASS; actual VERIFIED INSTALLED-STATE NO-OP PASS; broader functions pending |
| Final user/agent update docs | TODO |
| WVM LAST и release scope acceptance | TODO |
| main/tag/GitHub Release | TODO |

## Source inventory и promotion decisions

Публичные sources уже в repo; private names ниже — безопасные идентификаторы packet/relative files, не claims shipped code. New paths — проектируемые владельцы, пока не executable API.

| Source / case | Текущее место / status | Disposition |
|---|---|---|
| `scripts/lab-preflight.ps1`, `lab-state.py`, installer/verifier/common | Repo; earlier scoped tests | Reuse contracts; fresh changed-seam tests при адаптации |
| `tests/scripts/lab-preflight-tests.ps1`, `lab-installer-tests.ps1`, `test_lab_state.py`, `lab-posix.sh` | Repo | Existing positive/negative/fake regressions, no native POSIX claim |
| `parent-observer-regression/serializer-test.ps1` | Private source; serializer/export synthetic tests | Санитизировать/перенести test logic, не raw host events |
| `parent-lifecycle-v4/{rpc-mock.ts,cases.mjs,run.ps1,validate.py}` | Private sources; bounded historical lifecycle | Перенести minimal mock/RPC/oracles с parameterization; historical callback/default-acceptance gaps не скрывать |
| `parent-lifecycle-v5/{rpc-mock.ts,runtime-contract.md,sdk-static.mjs}` | Private prepared/static source; runtime unexecuted | Actual SDK/env/default-acceptance assertions сохраняются; source promotion/test ещё впереди |
| `linked-token-source-v1/current/{NativeBoundary.cs,run.ps1,dummy.mjs}` | Private frozen source; source/managed approvals | Experimental `tests/lab/native/` source после sanitization; no automatic native approval |
| `token-query-source-v1/test-query-contract.ps1` | Private;15 managed query cases | Перенести mocks/throwing native guards, не compiler DLL/receipts |
| `linked-token-source-v1/test-linked-consumer.ps1` | Private;20 managed consumer cases | Перенести ownership/identity/default-elevation cases и сохранённые fixture error explanations |
| Raw runs, DB/sessions/traces, compiled DLLs, machine configs/auth | Private runtime/evidence, не portable source | Не коммитить и не переносить как test fixtures |

В `docs-initial-v1/source-inventory.json` parent измерил selected source bytes/SHA; reviewer recomputation этим не утверждается. Native source inventory hash: `52f589a98bb55386cf37388cdbd2f60fc2839e6c9eda96b2f00d49b2603edb65`; этот hash имеет source-only статус. Native invocation/command identity фиксируются заново в actor packet, не копируются из doc inventory как разрешение.

## Исторический контракт разрешений и неподтверждённое

Ниже сохранён прежний scope, не текущие prerequisites. Scope этого исторического контракта — обычное обновление/Pi1.0.2, synthetic checks и repository publication, без VM/native запусков. Прежний project scope допускал private подготовку/provisioning, bounded native/mock work и repository publication. Не требовать повторного согласования уже разрешённой операции, но проверять входной gate и сохранять bounded packet перед risky launch. Shared/working mutations, real data/auth reads и automatic paid calls не входят.

- Машина B ещё не выбрана/проверена. Первоначальный `stand-capabilities-v1` фиксировал Windows x64, hypervisor present, vmcompute/hns running и Sandbox **Disabled**. После явного разрешения owner feature переведена в **Enabled** командой с `-All -NoRestart`; `RestartNeeded=true`. Перезагрузка/VM/Pi/SDK не запускались. Новый boot и пригодность CLI ещё должны быть подтверждены; WSL/PATH discovery и feature enable не являются Windows-VM/replay proof.
- Параметризованный [core SDK fixture](../../tests/lab/sdk/README.md) подготовлен по exact published 1.0.0 API (`ModelRuntime`); синтаксис/host refusal — source-only, actual SDK/root+descendant/lifecycle proof ещё отсутствует.
- Restricted token/MIC/Job не гарантируют network/read-secret/full-global isolation. Scope каждого accepted mechanism явный.
- Последний actual0.99.1 helper остановился перед actor launch; новые public-helper попытки после query fixes также не дошли до root/descendant actors. Old raw-review timeout и новые prelaunch source approvals не заменяют actual native acceptance.
- Controlled default acceptance prepared, не испытан. Old lifecycle/mock receipts не закрывают новый SDK/native requirement.
- Parent WVM gateway/public schema PASS — historical availability; candidate legacy SSE и streamable HTTP каждый NOT TESTED. Новый WVM LAST относится к финальному technical slice migration, не к этому doc commit.
- Native Linux/macOS и paid providers NOT TESTED; прежние24/35/Windows-count receipts не становятся freshly rerun здесь.

## Initial doc check incidents

First local link check обнаружил pre-existing `setup.md#posix-macoslinux` в platforms: такого heading нет. Исправлена ссылка/claim, first receipt сохранён. First repository verifier invocation использовал неподдержанный `-Root`; сохранили NamedParameterNotFound и повторили documented `-RepositoryOnly` из candidate cwd. Guards/проверки не отключали. Accepted run относится к current source, без runtime/package/Trace edits.

## Preparation check incidents

`stand-tests-v1` first/second runs: fresh PLAN PASS, PREPARE FAIL — source check ошибочно читал unset `LASTEXITCODE` после успешного PowerShell preflight без native command. First redacted receipt сохранён; diagnostic type/line уточнил seam. Исправлено на actual PowerShell invocation status + required PASS marker, не на forced-success/error whitelist. Subsequent source tests PASS; partial roots сохранены и не repair/reuse. Позднее расширены negative/source relocation cases; current metadata/ACL/env coverage не является native/global proof.

## Ведение board

PASS требует source/command/result/scope и packet. Planned scripts/recipes не получают executable статус. Runtime/trace/release facts обновляются после actual checks. Gate BLOCKED не требует автоматически ставить goal на паузу: конкретный дефект локализуется, разрешённые independent steps продолжаются. Mandatory blocker не скрывается при release.
