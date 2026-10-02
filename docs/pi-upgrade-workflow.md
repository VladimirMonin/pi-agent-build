# Повторяемое обновление переносимой сборки Pi

Вход: [AGENTS](../AGENTS.md), [BUILD.LabUpgrade](../instructions/BUILD.lab_upgrade.instructions.md), [паспорт стенда](lab-stand.md). Текущий status/target — [readiness board](plans/lab-readiness-board.md). Этот runbook не обновляет рабочий Pi и не является разрешением на commands с mutation/actors.

## 1. Baseline и exact target

- Зафиксировать working ref/runtime, source candidate ref и tracking state; не стирать чужие изменения или unrelated untracked files.
- Проверить latest **stable** через официальный release/npm HTTP metadata. npm CLI metadata использовать только с private environment/cache/config, даже без install.
- Перед первым runtime manifest change закрепить exact target. Следующий релиз не меняет его автоматически внутри цикла.
- Создать отдельную candidate branch/worktree и начальный doc commit до runtime edits. Исторический source/approval/version не переносится на target по номеру.
- Составить delta matrix: CLI/SDK/extensions/peers, profiles/filters, patches, lifecycle, TUI, codemode/MCP, model catalog/auth/response и support scope.

Working baseline и исследовательский кандидат — разные сущности. Candidate acceptance не переключает личные profiles и не закрывает автоматически историческую цель.

## 2. Подготовка и permission ladder

| Шаг | Вход / результат | Не следует автоматически |
|---|---|---|
| Source/docs | Inventory, static checks и doc commit | Prepare/install/actor permission |
| PLAN | Paths/config/capabilities, declared probe list | Mutation или kernel sandbox proof |
| PREPARE | Новый owned root, synthetic state и private env | Global prerequisites install |
| Private provisioning | После preliminary gate; exact private packages/tools | Pi runtime/models |
| Bounded dummy | Frozen source/command, actual root+descendant proof/raw review | SDK/provider compatibility |
| Pi deterministic mock | Actual candidate SDK/env/state/lifecycle/acceptance | Real model/auth/quota |
| Optional live routes | Отдельное разрешение и credentials safe routing | Все модели/платформы/transports |
| Publication | Final accepted ref и разрешённые main/tag/Release | Working Code/Task switch |

Применяется scope текущей задачи; документация не требует повторного вопроса там, где владелец уже явно разрешил работу. Но широкое разрешение не делает failed gate successful и не включает неоговорённый paid расход.

### Filesystem-only PLAN/PREPARE

Создать **новый private machine config** по [sample](../config/lab-stand.example.json), не копируя рабочий config. Заменить placeholders на distinct source/lab roots, выбрать existing safe parent и взять `expectedPiVersion` из текущего runtime manifest. Config/receipts вне Git. Из source checkout:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/lab-stand.ps1 -Config '<PRIVATE_MACHINE_CONFIG>'
# Только после принятого PLAN и permission:
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/lab-stand.ps1 -Config '<PRIVATE_MACHINE_CONFIG>' -Prepare
# Повтор PREPARE только для неизменного prepared state: VERIFIED_PREPARED_NO_OP.
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/scripts/lab-stand-tests.ps1 -FixtureRoot '<PRIVATE_FIXTURE_PARENT>'
```

PLAN не создаёт lab и не скрывает executable probes. PREPARE создаёт owner-only root/synthetic configs, вызывает existing read-only preflight **в том же PS process**, но ничего не устанавливает и не запускает Pi/native actors. Failed/unknown/nonempty roots не repair/clear. Это preparation approval, не kernel/global proof; последующие provisioning/probes/actor state проходят свои gates. Tests сохраняют owned fixture/raw cases; private parent и TEMP/TMP задаются заранее. Same-machine relocated source/Unicode root проверяют parameterization, не заменяют machine-B replay.

### Существующая static preflight команда

Из candidate checkout после подготовки проверяемых directories/configs:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/lab-preflight.ps1 -LabRoot '<LAB_ROOT>' -RepoRoot '<LAB_WORKTREE>'
```

Она ничего не создаёт и не устанавливает; PASS относится к входным paths/configs. Negative cases:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/scripts/lab-preflight-tests.ps1 -FixtureRoot '<PRIVATE_FIXTURE_PARENT>'
```

Tests получают explicit private parent, не используют checkout sibling; redirect TEMP/TMP и output в private evidence до запуска. Installer fake regressions: `tests/scripts/lab-installer-tests.ps1 -FixtureRoot '<PRIVATE_FIXTURE_PARENT>'`. Это fake driver/source tests, не actual Pi install/runtime. Не вводить credentials в synthetic configs.

## 3. Exact provisioning и installed-state gate

После preliminary gate и installation permission использовать **lab mode**, не обычную global процедуру из setup:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/install.ps1 -LabRoot '<LAB_ROOT>' -Profile Both
# Apply — только после принятия Plan и допуска этого этапа:
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/install.ps1 -LabRoot '<LAB_ROOT>' -Profile Both -Apply
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File scripts/verify.ps1 -LabRoot '<LAB_ROOT>' -Profile Both
```

PLAN installed gate может запускать private executable/MCP probes и писать допустимый cache/log state; read-only source/config inspection и probe execution разделяются в packet. Эти existing commands пока привязаны к **текущему manifest**, не означают уже установленный новый target. Недостающие runtime/source adaptation выполняются в candidate, guards не отключаются.

Ожидаемый повторный Apply: `VERIFIED INSTALLED-STATE NO-OP`, без package/launcher/config repair. Wrong identity, unknown/mixed state, escaping link, patch drift — отказ. Private external initialize/tools/list не доказывают все tools/call, LSP/indexing или remote providers.

## 4. Patches и package compatibility

Для каждого patch: поддержанная installed version → stock/check → reproduction → apply → check/runtime → byte-exact restore или согласованный private backup. Сначала установить, сохранился ли upstream defect; не расширять hash/version guard по предположению.

Сохраняются filters, exact sources, Code/Task distinctions и required ordering. Installed package bytes — runtime, источник истины — repository patch. Unchanged evidence применять только по [evidence contract](lab-evidence.md), changed seams проходят fresh composed checks.

Прочитать tagged Pi docs, related API docs/examples до SDK/extension implementation; локальная README старой версии не является спецификацией target. Не менять Polza implementation без воспроизведённой несовместимости.

## 5. Два профиля и Trace opt-in

**Целевая политика нового выпуска:** ровно Code и Task. `pi-trace-extension` сохраняется установленным, но default extension inactive в обоих. Это не третий «trace» режим и не отключение обязательных диагностических receipts стенда.

**Текущее implementation status:** candidate Code/Task templates содержат pinned Trace в object form с `extensions: []`; пакет и patch не удалены. Manifest и оба verifier согласованы с default-off; synthetic installer merge сохраняет filter. Это source configuration, а не actual startup proof. Runtime off→on→off и user recipe ещё требуют accepted native boundary; не применять непроверенный recipe к working profiles. Final docs обязаны заменить этот pending note проверенными командами после соответствующего task.

Required tests на synthetic profiles:

1. Code default и Task default: Trace extension не загружен, plugin-owned tracing/commands/output не активируются автоматически; ordinary Pi functions работают.
2. Явное включение: installed Trace загружается документированным способом, actual fixture tracing создаёт ожидаемый private artifact.
3. Возврат off: последующий default запуск не включает Trace.
4. Installer/sync/no-op сохраняют canonical disabled filter; persistent opt-in, если поддержан, описывает verifier/update semantics.
5. Existing background-disabled package и Trace-disabled package не путаются с другими tool surfaces, например bg_wait.

Предпочтителен проверенный opt-in на один запуск без изменения canonical profile. Не указывать CLI/config command до проверки current Pi/package discovery semantics. AGENTS и component/setup docs должны объяснять обе операции человеку и агенту; final release не допускает pending recipes.

## 6. Native и target runtime acceptance

До target Pi runtime — usable accepted stand runner/root+descendant boundary. На target измерить actual private executable/SDK/peer/env/PID linkage, callback/output/terminal и default acceptance по честному synthetic criterion. Natural root/descendant exit и owned resource cleanup обязательны.

Оба профиля используют synthetic memory/session/trace/Goal/intercom/cache; outgoing mock context/scope checks не требуют working DB. Model/auth/live requests не включаются по факту загрузки CLI. Native/global coverage проверяется отдельным механизмом; JS guards/metadata sampling не переименовываются в OS sandbox.

При FAIL сохранить raw error/reached stages, остановить dependent actor, устранить конкретный дефект и продолжить разрешённые independent steps. Следующая risky попытка bounded/frozen, не автоматический flags sweep. Не обещать успех от компиляции helper.

## 7. Общие проверки и WVM LAST

- Unit/contract/seam checks, оба verifier, schemas/syntax, byte-exact patch guards, applied state/no-op.
- Platform claims: Windows native; Git Bash только shell syntax/fakes, Linux/macOS без native proof NOT TESTED.
- Model matrix разделяет catalog/mock/auth/live/quota; actual paid вызов не входит по умолчанию.
- Затем WVM legacy SSE и streamable HTTP — отдельные candidate configurations/handshakes/function cases. Gateway tool list/schema parent процесса не заменяют их.
- Adapter KEEP до доказанного functional parity; builtin unsupported transport фиксируется честно. Не запускать два /mcp owners и не переписывать working configs/auth.
- После WVM разрешены final doc/link/safety/manual publication gates. Новый технический runtime/code срез требует новой last assessment, но изменение статуса/плана не требует дергать WVM само по себе.

## 8. Final docs, release и handoff

Обновить README/setup/profiles/component/patch/platform docs, instructions/catalog и evidence matrices по фактам. Final assertions, command recipes и checks принадлежат одному accepted ref; historical tests не описываются как fresh execution.

Release gate: mandatory cases PASS в заявляемом scope; никаких скрытых security/runtime blockers; optional NOT TESTED ограничивает notes, не приравнивается к support. Проверить full final diff/safety/links/schema и semantics, затем permitted commits/push, main/tag/GitHub Release. Tag format определяется BUILD/manifest и не перезаписывает прежние tags. Remote/main/tag/Release должны указывать на принятую версию.

Working-profile switch — отдельный scope с [private rollback](state-migration.md); нынешний release project его не выполняет. Handoff включает exact ref, source/payload identities, commands/results/coverage, remaining limitations, publication state и safe следующий шаг.

## Текущие входные ссылки

- [Readiness и inventory](plans/lab-readiness-board.md)
- [Подготовительный план D0–D6](plans/lab-repeatability-and-portability.md)
- [Историческая доска0.99.1](plans/pi-0.99.1-execution-board.md)
- [Обычная установка](setup.md) — не lab Apply по умолчанию
