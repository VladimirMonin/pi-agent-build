# Паспорт переносимого лабораторного стенда

Назначение — подготовить и проверить version-pinned кандидата **без переключения рабочей установки**. Этот паспорт описывает контракт, не выдаёт execution permission. Workflow — [отдельный runbook](pi-upgrade-workflow.md); доказательства — [evidence contract](lab-evidence.md); актуальная реализация и результаты — [readiness board](plans/lab-readiness-board.md).

## Реализовано и запланировано

Уже существуют `scripts/lab-preflight.ps1`, lab-mode installer/verifier и `scripts/lab-state.py` в кандидатном source. Они не являются полноценным portable native runner. Общий preparation entry point, machine config schema и public mock/native fixtures ещё готовятся; не использовать `scripts/lab-stand.ps1` как существующую команду до её появления и проверок. Ранее private sources не являются shipped files.

## Корни и write scopes

| Корень | Назначение | Разрешённые записи |
|---|---|---|
| `<WORKING_ROOT>` и рабочие профили | Текущий baseline | Ни package/config/state изменений; содержание личных DB/auth не читается |
| `<LAB_WORKTREE>` | Candidate source/branch и repository tests | Только разрешённые source/docs edits; никаких runtime sessions/cache/DB/backups |
| `<LAB_ROOT>` | Новый private owned subtree | Synthetic profiles, private package/tools, state и evidence в scope этапа |
| `<EVIDENCE_ROOT>` | Обычно `<LAB_ROOT>/evidence/<RUN_ID>` | Frozen inputs, raw failures, inventories, receipts и validators |

Корни разные, lab вне Git. Проверяется не только ACL самого root, но и безопасность ancestors. Отказ на unsafe parent не разрешает чинить shared ACL. Непустой/неизвестный root не очищается; fresh preparation и verified installed NO-OP различаются. Current main checkout с несвязанными untracked служебными файлами не чистится ради PASS.

### Layout

```text
<LAB_ROOT>/
  pi-root/agent/                Code: synthetic config/package state
  pi-root/task/                 Task: synthetic config/package state
  npm-prefix/                   exact Pi и private Node tools
  home/ appdata/ localappdata/   synthetic user directories
  temp/                         private temporary outputs
  npm-cache/ uv-cache/           private dependency cache
  uv-tools/ uv-bin/              Python tools и regenerated launchers
  sessions/{agent,task}/
  sessions-archive/{agent,task}/
  memory/                       только synthetic DB и sidecars
  cbm-cache/                    только synthetic indexes
  test-cwd/                     synthetic project/.pi и fixtures
  evidence/<RUN_ID>/             immutable packet одного шага
```

Это логическая схема. Concrete names проверяются configuration schema/preflight; Python launcher absolute paths пересоздаются на новой машине. Старые pid/lock/socket files, actual working profiles и raw evidence другой машины не копируются как preparation.

## Prerequisites и проверяемые capabilities

Exact runtime pins берутся из [runtime lock](../manifests/runtime.lock.json), tools — из [external lock](../manifests/external-tools.lock.json). Количество/версии Code/Task — из [packages lock](../manifests/pi-packages.lock.json), не из вечной инструкции.

| Requirement | Как трактовать |
|---|---|
| Windows x64 и подходящий local filesystem | Первичный native target; проверить OS build, NTFS/ACL/reparse capabilities |
| Windows PowerShell и managed compiler/runtime | Для PS/native-source harness; записать реальные paths/versions и capabilities до запуска |
| Node/npm/Git | Exact installer pins, а не только minimumNode; фиксируются actual executable identities |
| Python и jsonschema | Patcher minimum отдельно от lab-junction requirement; Windows installed gate требует Python >=3.12 |
| uv/Serena/Python interpreter | Private tool install и launcher regeneration; tool interpreter может отличаться от patcher Python |
| ast-grep/CBM | Explicit private binaries, version/identity/ancestor ACL; никаких uvx/global fallback |
| Sandbox isolation resources | Доступный механизм и scope должны быть измерены; отсутствующий capability — объяснимый отказ |

Статическая проверка файла не запускает executable. `--version`, MCP initialize/tools/list и compiler относятся к отдельным probes, которые способны писать private temporary/cache state. PLAN обязан назвать такие действия, не обещать zero-write execution.

Host tools/virtualization features не устанавливаются и не включаются автоматически. Разрешение на private provisioning не равно разрешению менять системные настройки host. Windows/macOS/Linux requirements не смешиваются: Git Bash подтверждает shell syntax/fakes, не native POSIX compatibility.

## Параметры машины

Переносимый entry point обязан получать/проверять:

- repo root/ref, lab root и evidence root;
- baseline/runtime/package/template/patch identities;
- разрешённые explicit binary paths, версии и capability report;
- environment/path map, profile/session/archive/memory/trace/Goal/intercom/cache/MCP routes;
- режим PLAN/PREPARE/probes/tests, timeout, разрешённый provisioning способ;
- frozen actor command, source fingerprints и bounded launch scope, если этап запускается.

Публичный sample — placeholders/synthetic values. Заполненный machine config/inventory — private. Не хранить credentials/USERPROFILE/hostname/actual user SID в публичном sample. Wrong version, escaping link, unsafe ACL и mixed installed state не становятся WARN только ради новой машины.

## Environment contract

Environment создаётся из allowlist, а не `{...process.env}`. До первого npm/uv/Pi child задаются private home/appdata/temp/cache/config/prefix/tool directories. Provider keys, NODE_OPTIONS и неизвестные absolute redirects не наследуются.

| Область | Обязательное направление |
|---|---|
| npm/uv | private prefix/cache/userconfig/globalconfig/tool/bin; host metadata probes также isolated |
| Pi | private `PI_CODING_AGENT_DIR`, явный candidate executable и session root |
| Session search | private sources **и** index/archive roots |
| Memory | explicit synthetic `pi-memory.localPath`; DB/WAL/SHM внутри lab |
| Goal/Trace/Polza/CBM | test cwd/private state; overrides отсутствуют либо проверены на lab membership |
| Intercom | уникальный lab scope, никаких сообщений рабочим peers |
| MCP | exclusive synthetic config; empty imports/servers до соответствующего case; no inherited OAuth/keyring |
| Child SDK | actual inherited env, argv/cwd/PID lineage и private SDK root проверяются в descendant |

Одно `PI_CODING_AGENT_DIR` не изолирует stock global memory. Narrow PATH не заменяет explicit binary identity. Даже read-only npm metadata команда может создать host debug-log, если environment установлен поздно.

## Isolation coverage

| Механизм | Что покрывает | Чего не доказывает |
|---|---|---|
| Worktree | Source separation | OS sandbox, write boundary |
| Allowlisted env/private config | Routing и отсутствие inherited secrets в проверенных children | Kernel file/IPC permissions и global zero-write |
| JS/mock guards | Конкретные наблюдаемые calls/paths | Full syscall/PID coverage |
| Hash/metadata comparisons | Выбранные bytes/metadata за заданное окно | Причину concurrent writes, все внешние files |
| Restricted token + low MIC + nonbreakaway Job | Измеренные access restrictions/process membership | AppContainer, network/read-secret containment, full-global proof |
| Private USER objects/token DACL | Owned object creation/access в конкретном runner | Устранение неизвестного initialization cause без actual run |
| VM/отдельный OS user | Граница при конкретной конфигурации | Автоматически все host/guest/network/shared paths; это требует своего контракта |

### Windows experimental native contract

Для существующего runner сохраняются `DISABLE_MAX_PRIVILEGE|WRITE_RESTRICTED`, один fresh restricting SID, low integrity, suspended CreateProcessAsUser → nonbreakaway Job assignment → resume и explicit private stdio handles. ACE/low-label mutations — только на новом owned runtime subtree/NEW noninteractive WindowStation/Desktop; caller station восстанавливается, owned handles закрываются. Default-DACL correction — только NEW restricted token, exact own SID ACE и сохранение original ACE bytes/order.

Не менять caller token, WinSta0/Default, существующий desktop/process/thread/shared ACL. Genuine API/cleanup errors fatal. Canary denials проверяются на harmless lab-created paths, не на working memory/auth/config/cache.

Этот source сейчас имеет только historical partial run и subsequent managed/source query approvals. **Usable root+descendant proof ещё BLOCKED**; перенос source в repo не означает prelaunch approval. Raw PID/token/Job/resource/natural-exit receipt и независимая actual result приёмка обязательны перед Pi runtime. Причина старого descendant DLL_INIT_FAILED/conhost ACCESS_DENIED остаётся UNKNOWN.

## Воспроизведение на другой машине

1. Получить принятый source ref, public docs/fixtures и prerequisites; не копировать personal/private state.
2. Выбрать новый безопасный root, проверить capabilities/PLAN.
3. Выполнить разрешённый PREPARE и source/managed/fake checks.
4. Provision baseline только после preliminary gate и в private roots.
5. Зафиксировать actual payload graph/hashes; exact top-level pins не гарантируют byte-identical transitives.
6. Выполнить отдельно разрешённые native/mock cases; source tests не заменяют их.
7. Передать новый scoped packet, не старые machine-A receipts.

Другой путь на той же машине — тест parameterization. Portability требует независимой Windows машины/свежей VM и её собственного evidence. Пока такого replay нет, claim NOT TESTED. Cleanup ограничен owned run/resources; blanket kill Node/Pi и рекурсивное удаление неизвестного root запрещены.
