# Windows native boundary fixture

Сопровождаемые sources для bounded **Node dummy** proof: root и один descendant. Это не Pi/SDK smoke, не AppContainer и не network/read-secret/full-global syscall sandbox. Source/managed PASS не является разрешением runtime/release.

## Source-only checks

Из repository root, с существующим owned private parent вне Git/home:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/lab/native/test-query-contract.ps1 -FixtureRoot '<PRIVATE_FIXTURE_PARENT>'
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/lab/native/test-linked-consumer.ps1 -FixtureRoot '<PRIVATE_FIXTURE_PARENT>'
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/lab/native/test-access-fields.ps1 -FixtureRoot '<PRIVATE_FIXTURE_PARENT>'
```

Каждый запуск создаёт новый retained child fixture; compiler temp/env и DLLs остаются там. Query suite компилирует полный source без вызова boundary. Unit copies заменяют Win32 declarations throwing guards/stubs; это actual managed consumer tests, **native token queries/actors — 0**. Проверяются DWORD20, ownership/semantic identity19/default18, full TOKEN_SOURCE7, x64 access-information22 members, DWORD scalar Type8/Virtualization23,24 и HasRestrictions21 (observed BOOLEAN1 или documented DWORD4, только0/1), nested buffer ranges, unknown/reserved/length refusals и cleanup errors. Исторический null-sizing algorithm реконструирован только для regression, не поставляется второй устаревший runner.

## Actual native attempt — отдельный допуск

`run.ps1` исполняемый actor entrypoint, не PLAN и не автоматически запускаемый test. Перед ним обязательны source review и принятый **один bounded frozen packet**: command/binary identities, source/config fingerprints, owned outputs/resources, timeout, preservation и cleanup oracle. Не запускать по одному этому README.

Packet получает fresh root через [lab-stand](../../../docs/lab-stand.md). `run.ps1` повторяет read-only verified prepared PLAN до создания run subtree; использованный root с дополнительным runtime-state не repair/reuse как fresh. Machine config, SHA manifest и receipts не включаются в Git.

Форма команды после допуска:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File '<FROZEN_SOURCE_DIR>/run.ps1' -RepoRoot '<REPOSITORY_ROOT>' -Config '<PRIVATE_STAND_CONFIG>' -NodeExecutable '<EXACT_NODE_EXE>' -NodeSha256 '<64_HEX_SHA256>' -SourceManifest '<PRIVATE_SOURCE_MANIFEST>' -TimeoutMs 45000 -ConsoleMode Detached
```

Source manifest — JSON object ровно с `run.ps1`, `NativeBoundary.cs`, `dummy.mjs`, каждый value — SHA256 actual frozen bytes. Node path/hash явные; PATH fallback/SDK/parent-owned arbitrary entrypoint отсутствуют. Отдельная Windows machine/VM должна измерить собственные dependencies, не заимствовать host approval.

## Обязательный механизм и oracle

- Unique restricting SID; `DISABLE_MAX_PRIVILEGE | WRITE_RESTRICTED` (9); low MIC.
- Только NEW restricted token default DACL: одна noninheriting unique SID GA ACE; original ACE bytes/order/padding и остальные token semantics сохраняются. Не менять caller token.
- Dedicated `-File` helper; NEW noninteractive WindowStation/Desktop; exact DACL/low-label readback. Не менять shared/existing USER ACL. Original station восстанавливается до launch и в finally.
- Suspended `CreateProcessAsUser`, explicit private stdin/stdout/stderr HANDLE_LIST; nonbreakaway Job до resume. Real root/descendant token+Job metadata до synthetic verification markers.
- Root и descendant естественно exit0; Job naturally empty; genuine EACCES/EPERM для harmless canaries снаружи runtime и successful writes внутри. Forced cleanup — failure, не natural PASS.
- Owned API/handle/SID/USER cleanup errors fatal. Raw `report.json`, streams и dummy receipts остаются в private run directory; source/root-ACL/canary preservation проверяются отдельно.

Даже `PASS_DUMMY_BOUNDARY_NOT_SDK` требует независимой **actual raw** приёмки на согласованных inputs перед зависимым Pi/SDK/mock work. Lossy Job notifications, sampled hashes и env allowlist не доказывают full-global/PID-attributed zero-write. Windows x64 layout является явной границей; unknown structure отказывается.

## API references

- [GetTokenInformation](https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-gettokeninformation)
- [TOKEN_INFORMATION_CLASS](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ne-winnt-token_information_class) — named enum numbers are part of the ABI, not mock-defined values.
- [TOKEN_SOURCE](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-token_source)
- [TOKEN_ACCESS_INFORMATION](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-token_access_information)
- [SID_AND_ATTRIBUTES_HASH](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-sid_and_attributes_hash)
- [TOKEN_LINKED_TOKEN](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-token_linked_token)
- [TOKEN_STATISTICS](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-token_statistics)

Sources authored for this repository; не являются скопированным сторонним package payload. Raw historical failures и private compiled artifacts не являются частью sources.
