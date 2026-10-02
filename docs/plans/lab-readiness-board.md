# Readiness — переносимый стенд и выпуск следующей сборки Pi

**Current project:** повторяемость/переносимость, затем exact stable Pi target и release репозитория. Working Code/Task не переключаются. Основной [план D0–D6](lab-repeatability-and-portability.md); [runbook](../pi-upgrade-workflow.md); [паспорт](../lab-stand.md); [evidence](../lab-evidence.md).

## Current state

- Новая source branch: `lab/pi-1.0.0`, от docs candidate `53112c7`; runtime source исследовательского0.99.1 — `b31ca02`.
- Working main/runtime baseline: `030adfa` / Pi0.87.0; его profiles/data не изменяются. Разрешён будущий перенос **repository source** в main/tag/GitHub Release, не live-profile switch.
- Перед первым runtime manifest edit официальный GitHub stable и npm dist-tags повторно сверены: **1.0.0**, draft/prerelease false. Exact target закреплён на цикл; candidate manifest и оба `lastChangelogVersion` теперь **1.0.0**. Private target installation/runtime acceptance ещё NOT TESTED.
- Fresh exact npm source payloads прошли guarded patch lifecycle: Code5/Task3 contexts, 96 CLI actions — stock/check/apply/check, apply NO-OP, unknown drift и wrong-version refusals, byte-exact restore. Trace `--restore` раньше перезаписывал unknown current files; исправлен отказ и проверка полного backup до первой записи, 8 focused synthetic regressions PASS. Independent source review OK; supplied tests reviewer не повторял. Это не installed Pi 1.0.0/runtime acceptance.
- Trace остаётся pinned installed package; оба canonical templates теперь используют `extensions: []`, manifest отражает installed-disabled. Windows/POSIX verifier проверяют filters, installer merge regression сохраняет off. Actual loading/off→on→off recipe ещё NOT TESTED, не support claim.
- Исходные AGENTS/instructions/passport/runbook/evidence docs приняты в initial commit `833d2fe` до runtime edits. Filesystem-only preparation/schema/synthetic config fixtures реализованы; public native dummy/managed fixtures подготовлены в `tests/lab/native/`; mock/SDK и actor gate ещё не приняты.
- Second-machine/VM replay и usable controlled native runner/actual SDK/env/default acceptance — TODO/BLOCKED по evidence. Native public source исправил номера Win32 enum и 1-byte BOOLEAN encoding class21. Последние bounded actual helpers остановились до actors; последняя причина — non-NULL opaque class22 `SecurityAttributes`, cleanup/preservation PASS в failed packet. Scalar `Flags` теперь сохраняется и сравнивается без ошибочного требования zero; подтверждённого TOKEN/CLAIM ABI для opaque payload пока нет. Native boundary остаётся непринятой.
- Альтернативная [Windows Sandbox capsule](../../tests/lab/windows-sandbox/README.md) теперь имеет filesystem-only PLAN/PREPARE, guest-only dummy sources и 18 source/preparation checks. Network/clipboard/audio/video/printers/vGPU выключены в XML, mappings только readonly input и новый private output. Source review OK с ограничениями; actual VM/host cleanup/SDK acceptance NOT TESTED, feature enable permission ещё требуется. Это не обход/новый PASS прежнего restricted-token runner.
- Historical0.99.1 incidents/partial approvals остаются в [исторической доске](pi-0.99.1-execution-board.md); новая goal/release не переименовывает их в PASS.

## Progress D0–D6

| Этап | Статус | Проверяемый результат / следующий шаг |
|---|---|---|
| D0 inventory | PASS (source inventory only) | `docs-initial-v1`: source ref + selected private source bytes/hashes, disposition и gaps; personal runtime data не читались, actors0 |
| D1 инструкции/AGENTS | PASS (initial docs) | AGENTS каталог6, BUILD.LabUpgrade и related rules; `docs-initial-v1`:15Markdown/121targets/1anchor/errors0, frontmatter/catalog0 errors, safetyBoth/no findings; начальный doc changeset |
| D2 паспорт/runbook/evidence | PASS (initial docs) | Документы/current/proposed APIs разделены; repository-only verifier0failures/0warnings, diffcheck0/manual doc review; runtime actors0. Initial commit не означает stand/runtime acceptance |
| D3 executable preparation/fixtures | PARTIAL (preparation PASS) | `lab-stand.ps1`/schema/sample; `stand-tests-v1`:44 focused checks, source relocation/root Unicode, exact prepared NO-OP, metadata-before-DB refusal, owner/ACL/ancestor/reparse/source drift. Composed Windows23/23, installer fake15/15, preflight15/15; public native source/managed fixtures подготовлены; actual native/SDK acceptance не получена |
| D4 машина B | NOT TESTED | Найти независимое Windows окружение/VM, replay по repo/docs; alternate root на этой машине недостаточен |
| D5 controlled native/runtime | BLOCKED (gate, не lifecycle цели) | Новый bounded frozen attempt/raw review и actual baseline SDK/env/default acceptance в разрешённом scope |
| D6 final readiness/handoff | TODO | Final composed/doc checks, truthful readiness и старт target migration |

## Release milestones

| Веха | Статус |
|---|---|
| Исходная документация до runtime changes | PASS (initial doc changeset; stand execution pending) |
| Portable stand/actual native boundary | TODO |
| Exact target manifest/installer/verifier/patches | PARTIAL — exact1.0.0 source pinned; guarded source-payload patch lifecycle PASS; required private target installation/runtime compatibility pending |
| Trace default-off и explicit on/off оба profiles | PARTIAL — source defaults/filters implemented; actual off→on→off pending |
| Final target sandbox Code/Task tests/no-op | TODO |
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

## Контракт разрешений и неподтверждённое

Нынешний project scope допускает необходимую private подготовку/provisioning, bounded native/mock work и repository publication. Не требовать повторного согласования уже разрешённой операции, но проверять входной gate и сохранять bounded packet перед risky launch. Shared/working mutations, real data/auth reads и automatic paid calls не входят.

- Машина B ещё не выбрана/проверена. `stand-capabilities-v1`: Windows x64, hypervisor present, vmcompute/hns running; Windows Sandbox feature **Disabled**. WSL и PATH discovery не Windows-VM/replay proof; host feature не включался автоматически.
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
