# Контракт доказательств лабораторных обновлений

Назначение — сделать PASS проверяемым и не перепутать source/mock/native/live claims. [Паспорт](lab-stand.md) определяет размещение и coverage, [workflow](pi-upgrade-workflow.md) — последовательность, [readiness board](plans/lab-readiness-board.md) — текущий результат.

## Статусы

| Статус | Значение |
|---|---|
| TODO / DOING | Работа запланирована / выполняется, evidence ещё не принят |
| PASS | Конкретный case удовлетворил контракт на указанном source/inputs |
| FAIL | Проверка выполнена и условие не выполнено; raw error сохраняется |
| NOT TESTED | Не выполнялось, нет доступа/разрешения/подходящей платформы |
| BLOCKED | Gate для конкретной операции не открыт; это не approval по отсутствию результата |

Статус evidence/gate не является командой приостановить цель. Lifecycle работы определяется действующим запросом владельца. Нельзя менять FAIL на NOT TESTED, если тест реально выполнялся, или выдавать NOT REACHED за PASS.

## Уровни evidence

| Уровень | Допустимый вывод | Недопустимый перенос |
|---|---|---|
| Source review | Проверены перечисленные code/contracts | Runtime/native функциональность |
| Compile / managed stub | Syntax/layout/ветви/ownership в test-copy | Реальный Win32 query/setter/process launch |
| Static installed state | Paths/versions/bytes/filters/probe metadata | Все plugin/SDK/provider функции |
| Deterministic mock | Actual selected lifecycle/tool/provider fixture поведение | Real auth/model/quota и полный OS sandbox |
| Native actor | Actual root/descendant/token/Job/resource/canary result | Read-secret/network/AppContainer/full-global гарантии без coverage |
| Live provider/MCP | Actual route/response/transport в конкретном case | Другие providers/transports/features |

Missing-key failure до transport подтверждает только routing/error path. Callback/terminal/artifact и default acceptance — разные условия. Exit0 внешнего wrapper/validator подтверждает только его проверку, не автоматически natural child exit0.

## Frozen packet

Raw outputs сохраняются в `<EVIDENCE_ROOT>/<RUN_ID>` вне Git. Каждый bounded шаг получает новый packet; исторические failures/partial source не перезаписываются.

Обязательные поля:

- scope: какой gate/case, baseline/target, что явно не проверялось;
- source ref, changed files, hash всех существенных source/fixtures/commands;
- actual executable/SDK/package/dependency identities и platform/compiler capabilities;
- origin: parent-measured/reviewer-opened/reviewer-recomputed; не смешивать происхождение;
- разрешённые writes/resources/actor command, env key/path map без secret values;
- команда/arguments/cwd, start/end, deadline, status/exit/timeout и raw stdout/stderr;
- actor PID/PPID/Job/token/resource lineage, когда это native/runtime test;
- reached versus NOT REACHED stages, actual allowed/denied canaries, natural exit и cleanup results;
- observer overflow/access/export errors, неизвестные descendants и attribution gaps;
- verdict/coverage независимого review, residual risks и допустимый следующий шаг.

Технические identifiers actual user/SID/paths принадлежат private packet. Public board хранит только безопасный evidence ID, command с placeholders, результат и ограничения. Работа со штатным auth-store для GitHub не разрешает печатать/копировать credential contents.

Machine config и env dump не публикуются. Не dump-ить все environment variables ради диагностики: сохраняются только approved keys и несекретные paths/identities. Personal DB/WAL/auth не hash/read по содержимому; approved config hashes и metadata-only snapshots имеют отдельный allowlist и scope.

## Native/runtime acceptance

До Pi mock: root и настоящий descendant достигают ожидаемого fixture кода; same intended token/MIC/Job и отсутствие breakaway измерены; canaries соответствуют contract; natural lifecycle/resource cleanup подтверждены. JobEmpty при не созданном Job или AllocationsFreed без подтверждения прочих handles не являются полным cleanup proof.

До SDK/default acceptance claim: actual descendant resolved private SDK/version/peer identities, env/argv/cwd/PID linkage; returned output прочитан; process terminal/natural exit проверен; default acceptance report соответствует честному synthetic criterion. Не отключать acceptance ради PASS и не приписывать mock реальные paid tools/commands.

Raw review независим и read-only. Reviewer явно перечисляет, какие receipts открыл и пересчитал; recorded comparison не называется independent rehash. Reviewer timeout/tooling failure — отдельный infrastructure failure, dependent stage не запускается по отсутствующему approval.

## Unchanged evidence

Переиспользование допустимо лишь после подтверждения unchanged relevant inputs: source/fixture/command, payload dependencies, version/API/platform и проверяемая boundary. Новые inputs → fresh затронутые checks. Особенно:

- новый native source не получает old actor PASS;
- новая машина не наследует machine-A native/platform proof;
- unchanged source review не равен review нового raw run;
- old unit/Windows count не описывается как freshly rerun без execution receipt;
- текущая установка identity/no-op проверяется отдельно от historical inventory.

Не требуется повторять неизменённые несвязанные checks или проводить полный audit для каждой строки. Изменённые seams и связанные contracts проверяются composed run конечного ref.

## Failure и recovery

1. Сохранить actual error, command, frozen/partial inputs и reached stages.
2. Остановить опасную/dependent operation; продолжать разрешённые независимые работы.
3. Локализовать конкретную причину focused reproduction; correction не переименовывает старый FAIL.
4. Новая risky attempt — новый bounded packet с source/command freeze, не flags sweep.
5. При infrastructure failure не переключать protocol/CLI молча; preserve partial diff и same-protocol recovery в разрешённом scope.

Concurrent host event/WAL timestamp change без PID attribution имеет статус UNKNOWN attribution, не автоматически «виноват кандидат» и не «записей не было». Исторический shared npm diagnostic write не удаляется из доказательств и не отменяется последующим clean window.

## Evidence и публикация

Release получает final accepted ref, обязательные checks и ограниченный statement of support. Optional NOT TESTED остаётся в release notes. Raw receipts, DB/sessions/trace dumps, credentials и node_modules не являются public source assets.

При source promotion сначала проверить происхождение/лицензии, очистить machine binding **в безопасных исходниках**, сохранить реальную тестовую логику и guards. Реальные working configs нельзя «скопировать и подчистить»: templates создаются заново по allowlist. Compiled DLL/log files из private packet не становятся fixtures.

Handoff содержит files/ref, tests/results/coverage, remaining risk/work, commit/push/main/tag/Release state и следующий разрешённый шаг. Подробная история — в versioned board, постоянная инструкция остаётся короткой.
