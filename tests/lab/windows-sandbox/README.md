# Windows Sandbox: экспериментальная VM dummy capsule

**Source/filesystem preparation only. Actual VM launch, host cleanup и runtime acceptance ещё NOT TESTED.** Это альтернативная схема изоляции, не исправление/ослабление `tests/lab/native` и не перенос его approvals.

## Coverage и границы

- Fresh Windows Sandbox — отдельная guest ОС. Только capsule input (read-only) и один новый private output subtree (read/write) отображаются с host.
- XML явно выключает network, clipboard, audio/video, printers и vGPU; запрашивает ProtectedClient. Подтверждённый XML не доказывает actual enforcement/VM identity.
- Guest запускает только approved Node и harmless root+один actual descendant; frozen sources, allowlisted private env, PID/executable/parent observations, natural exits и genuine mapped-canary denials. Нет Pi/SDK/provider imports.
- Guest работает под обычным Sandbox administrator: **нет** promises restricted SID/low MIC/Job/guest sibling containment. Existing native token/USER/DACL contract не изменяется и остаётся непринятым. Guest metadata не является lossless syscall/process audit.
- Host image/source preservation, bounded VM launch, actual VM identity/lifecycle и проверенная owned VM cleanup — отдельные обязательные gates. Guest status `VM_DUMMY_OBSERVED_NOT_HOST_CLEANUP_OR_SDK_ACCEPTANCE` **не разрешает Pi runtime**. Нужен independent actual raw review всей границы.
- Snapshot/Node/config/raw report/state вне Git. Никаких рабочих profiles/auth/DB, shared folders с home/working installation или personal data.

Формат XML/настройки: [Microsoft Windows Sandbox configuration](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-configure-using-wsb-file). Fixed `C:\PiLabInput`/`C:\PiLabOutput` — guest interfaces; actual host paths передаются configuration, не baked machine paths.

## Подготовка без запуска VM

Нужен новый stand после `scripts/lab-stand.ps1 -Prepare`, approved explicit Node executable/SHA и разрешённый private scope. Default PLAN не пишет capsule и не запускает executable/feature probes:

```powershell
.\tests\lab\windows-sandbox\prepare.ps1 -Config '<PRIVATE_STAND_CONFIG>' `
  -NodeExecutable '<APPROVED_NODE_EXE>' -NodeSha256 '<APPROVED_NODE_SHA256>'
```

Добавление `-Prepare` создаёт новый packet под `<LAB_ROOT>/evidence`, копирует только Node/две public sources, synthetic canary и config, генерирует `.wsb`/`inputs.json`. Никаких feature enable, reboot, WindowsSandbox.exe или actor launch. Source-prepared inventory после packet writes не считается canonical initial preparation: не force-repair/reuse root, используйте новый prepared stand для нового packet.

`finish.cmd` сохраняет raw helper streams/exit и запрашивает shutdown **guest** после helper. Не выдавайте этот запрос за подтверждённую host VM cleanup. Marker `invocation-started.json` запрещает повтор consumed attempt; failure/resources сохраняются. Launch entry point/host watchdog ещё не принят; **не double-click `.wsb` как замену отсутствующему gate**.

Windows Sandbox feature enable требует отдельного owner permission; скрипты её автоматически не включают, не меняют ACL/settings и не перезагружают host. Если capability отсутствует, actual этап не запускается.

## Offline core material для следующего этапа

[Source/cache recipe](OFFLINE-CORE.md): published exact lock, official archive identities, private cache и npm bootstrap без установки/запуска Pi. Текущий bundle подготовлен, но offline guest installation и provisioning entry point ещё не приняты; dummy capsule не расширяется до actual boundary/raw review.

## Source/filesystem regression

```powershell
.\tests\scripts\lab-windows-sandbox-tests.ps1 -FixtureRoot '<OWNED_PRIVATE_PARENT>' `
  -NodeExecutable '<APPROVED_NODE_EXE>' -NodeSha256 '<APPROVED_NODE_SHA256>'
```

PS/Node syntax, host-execution refusal, PLAN no writes, explicit capsule preparation, identity refusal, XML escaping/scoped mappings/policies, generated input inventory. Эти тесты **не запускают VM/guest dummy/Pi/SDK** и не заменяют независимый Windows replay.
