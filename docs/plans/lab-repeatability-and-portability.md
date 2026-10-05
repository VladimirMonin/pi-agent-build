# План повторяемого и переносимого стенда перед работой над Pi 1.0

## Статус и назначение

**Статус: IN PROGRESS.** D0 inventory выполнен; исходные D1/D2 документы созданы и проверены в начальном doc changeset. D3–D6 ещё не выполнены; фактический прогресс — [readiness board](lab-readiness-board.md). Этот проект принят отдельной целью и не продолжает автоматически старую строго0.99.1 миграцию. Scope исполнения определяет подтверждённый запрос владельца, не одно наличие документа.

**Цель:** после выполнения плана новый человек или агент на другой Windows-машине способен по одному репозиторию подготовить лабораторию, выполнить разрешённые проверки, получить объяснимый PASS/FAIL/BLOCKED и передать результат без доступа к этой беседе, персональной памяти агента и прежнему private evidence. Затем можно начинать отдельную миграцию на **точную Pi 1.0.0**, не повторяя инфраструктурное исследование.

Работа включает документацию **и минимальные исполняемые средства**, подтверждающие её повторяемость. Одних Markdown-инструкций недостаточно. План не требует нового универсального framework, переписывания installer или автоматического updater.

Два разных результата:

- **READY_FOR_1.0_SOURCE:** документация и безопасные проверки подготовки воспроизводимы; разрешено отдельно начинать анализ исходников/совместимости 1.0, но не запускать кандидат.
- **READY_FOR_1.0_RUNTIME:** дополнительно принят исполняемый stand gate на baseline и получено отдельное решение владельца о следующей лабораторной миграции. Это готовность выполнять её этапы с проверками, **не** совместимость 1.0 и не release GO.

Полное завершение D0–D6 нацелено на второй результат. Если native gate останется BLOCKED, документы можно принять, но весь план и runtime readiness нельзя объявлять завершёнными.

## Исходная точка

Источники фактов: [доска 0.99.1](pi-0.99.1-execution-board.md), [матрица совместимости](pi-0.99.1-compat-matrix.md), [модельная матрица](pi-0.99.1-model-matrix.md), [границы повторяемости README](../../README.md), [изоляция лаборатории](../lab-isolation.md).

| Область | Что уже есть | Что не доказано / нужно подготовить |
|---|---|---|
| Рабочая установка | Pi 0.87.0; рабочие профили не переключены | Обновление рабочего runtime не входит в этот план |
| Кандидат 0.99.1 | Lab installer/preflight/verifier; verified Apply NO-OP; bounded functional/mock проверки | Это исследовательский baseline с ограниченными approvals, не полностью принятый release |
| Постоянные правила | BUILD, PATCH, SEC и DOCS instructions | Корневого AGENTS.md нет; новое окружение не имеет единого каталога входа |
| Описание стенда | docs/lab-isolation.md в кандидатной ветке | Документ смешивает устойчивый контракт и детали конкретной миграции |
| Испытательные средства | Repository tests и private mock/RPC/native harness | Часть исходников и проверок доступна только вне Git на исходной машине |
| Windows native runner | Частичные реальные receipts; исправленные source-only class20/21 queries | Исправленный runner не испытан; root+descendant usable proof и актуальное raw approval отсутствуют |
| SDK / acceptance | Static private SDK resolution и прежние bounded callbacks | Actual controlled descendant SDK/env и исправленный default acceptance не подтверждены |
| MCP | Адаптер сохранён; parent gateway/public schema доступны в последнем assessment | Отдельные candidate WVM legacy SSE/streamable HTTP не проверены |
| Платформы / зависимости | Windows top-level pins; Git Bash syntax/fakes | Native Linux/macOS и bit-identical dependency tree не подтверждены |

Исторические npm write incident, WAL timestamp с UNKNOWN attribution, native failures, fixture failures и reviewer timeout сохраняются. Никакая новая инструкция не превращает их в PASS и не ослабляет исходную цель 0.99.1.

## Границы и решения до исполнения

### В объёме

1. Постоянные инструкции и каталог входа для агентов.
2. Универсальный паспорт стенда, runbook обновлений и контракт доказательств.
3. Параметризованная подготовка нового lab root и проверки окружения.
4. Перенос безопасных исходников/fixtures/oracles из private экспериментов в сопровождаемый test surface.
5. Проверка на другой Windows-машине либо отдельной свежей Windows VM.
6. Отдельный bounded native/runtime gate на исследовательском baseline 0.99.1.
7. Итоговый handoff и стартовый контракт следующей миграции.

### Не входит без отдельного разрешения

- Изменение working Pi, Code/Task, личных DB/WAL/SHM/auth, shared ACL или глобального окружения.
- Установка/запуск Pi 1.0, изменение runtime manifest на 1.0, обновление пакетов по latest.
- Реальные backups, перенос пользовательского состояния и profile switch.
- Paid models, embeddings/consolidation, OAuth sign-in, доступ к содержимому рабочей памяти.
- Замена pi-mcp-adapter, выпуск tag, изменение main.
- Новый неограниченный аудит, flags sweep или цикл native launches до получения PASS.

### Что должен определить владелец при старте исполнения

| Решение | Что фиксируется |
|---|---|
| Машина B | Реальная вторая Windows x64 машина либо независимая свежая VM; кто предоставляет доступ |
| Модель изоляции | Механизм, защищаемые пути/ресурсы, разрешённые записи, остающиеся ограничения |
| Подготовка | Разрешение создавать только новый owned lab subtree; host prerequisites не устанавливаются автоматически |
| Downloads/install | Отдельное разрешение на private dependency provisioning и baseline install после preflight |
| Native validation | Точные команда, frozen source, scope, число попыток, deadline и стоп-условия |
| Baseline Pi mock | Отдельный допуск после usable dummy + независимого raw review; без реальных providers |
| Publication | Ветка/допустимые commits/push; это не main/tag/release permission |

При первоначальном написании был разрешён только документ; затем владелец подтвердил отдельный project scope исполнения до repository release, без live-profile switch. Разрешённые private preparation/provisioning и bounded tests не требуют повторного согласования каждого поля, но failed gate не обходится. Actual capabilities VM проверяются; изменение неоговорённых host settings и границ старой цели не подразумевается.

## Целевая структура документации

**Новые имена ниже — проектируемые артефакты, пока не существующие команды или документы.** На ещё не созданные файлы нельзя делать рабочие Markdown-ссылки.

| Файл / область | Роль после выполнения плана |
|---|---|
| `AGENTS.md` — новый | Краткий вход: источники истины, каталог всех instructions, условия их чтения; без копирования manuals |
| [BUILD.master.instructions.md](../../instructions/BUILD.master.instructions.md) | Общая политика состава, изменения manifests и release; ссылка на lab workflow |
| `instructions/BUILD.lab_upgrade.instructions.md` — новый | Только устойчивый контракт лабораторного обновления: границы, permissions, gates, evidence scope |
| [PATCH.maintenance.instructions.md](../../instructions/PATCH.maintenance.instructions.md) | Patch lifecycle, неизвестный bundle, upstream-fixed defect, check/apply/restore |
| [SEC.public_repository.instructions.md](../../instructions/SEC.public_repository.instructions.md) | Публичные/приватные данные, санитизация source/fixtures, безопасный handoff |
| `docs/lab-stand.md` — новый | Паспорт машины и стенда: requirements, layout, parameter contract, isolation coverage |
| `docs/pi-upgrade-workflow.md` — новый | Последовательность обновления любой exact version и команды разрешённых этапов |
| `docs/lab-evidence.md` — новый | Receipts, provenance, reusable evidence, actual coverage, ошибки и итоговые статусы |
| [docs/lab-isolation.md](../lab-isolation.md) | Вход/compatibility note для текущего кандидата; общие правила отсылают к новому паспорту, история не стирается |
| [docs/setup.md](../setup.md), [docs/platforms.md](../platforms.md) | Разделение рабочей установки и лаборатории; реальные prerequisite/platform claims |
| [docs/state-migration.md](../state-migration.md) | Отдельный канал пользовательского состояния и отката; не часть bootstrap стенда |
| [README.md](../../README.md) | Маршрут «подготовить стенд → обновить кандидат → решение о рабочем переносе» и фактический статус AGENTS |
| `docs/plans/lab-readiness-board.md` — новый | Только текущий прогресс D0–D6, evidence IDs, blockers и handoff следующего этапа |

Инструкции оформляются по [DOCS.InstructionsStyle](../../instructions/DOCS.instructions_style.instructions.md): YAML с первой строки, узкий applyTo, name/description с триггером чтения, атомарное обновление каталога AGENTS. Существующие инструкции не дублировать. Номера Pi, выбранные модели review, лимиты сабов, machine paths и run IDs не становятся постоянными правилами.

## Паспорт и размещение стенда

Три независимых корня:

- `<WORKING_ROOT>` — рабочий checkout/профили/данные, вне write allowlist лаборатории.
- `<LAB_WORKTREE>` — исходники кандидата и tests, отдельная ветка; runtime state здесь не создаётся.
- `<LAB_ROOT>` — новый private owned root на подходящем filesystem с проверенным безопасным parent.

Проектируемый layout сохраняет существующие lab маршруты, чтобы не переписывать installer без необходимости:

```text
<LAB_ROOT>/
  pi-root/agent/            synthetic Code profile
  pi-root/task/             synthetic Task profile
  npm-prefix/               exact private Pi и Node tools
  home/ appdata/ localappdata/
  temp/                     private temporary artifacts
  npm-cache/ uv-cache/       фактические имена фиксирует configuration schema
  uv-tools/ uv-bin/          private Python tools и launchers
  sessions/                 agent/ и task/
  sessions-archive/          agent/ и task/
  memory/                   только созданные тестом synthetic DB
  cbm-cache/                synthetic indexes
  test-cwd/                 synthetic project-local .pi и fixtures
  evidence/<RUN_ID>/         immutable packet текущего bounded шага
```

### Обязательные поля машинного контракта

- OS/architecture/build и проверенные capabilities; Windows x64 — первичная native платформа.
- Node/npm/Git/Python/uv и compiler/managed runtime, требуемые конкретным test surface.
- Exact supported tool versions из manifests; раздельно installer requirements, patcher requirements и lab junction/native requirements. Не считать Python 3.8 достаточным для всех проверок.
- Явные пути к проверенным binaries и их identity; поиск Pi из PATH не является fallback.
- Repo ref, manifests/template/patch fingerprints, baseline runtime identity.
- Root paths, ownership, ACL ancestors, filesystem/reparse policy, permitted writes.
- Profile/session/trace/memory/MCP/Goal/intercom/cache routes; уникальный scope каждого run.
- Зависимости и способ provisioning: private download или проверенный offline bundle; отсутствие инструмента — объяснимый отказ, не host install.

Публичный sample содержит placeholders и synthetic значения. Заполненная конфигурация и inventory остаются вне Git. Machine B не получает working auth/configs/DB, старые sessions, raw receipts или stale locks. Python tool launchers с абсолютными путями пересоздаются на новой машине, а не копируются как переносимые executables.

### Уровень повторяемости зависимостей

Различать два заявления:

1. **Contract reproducibility:** exact top-level pins, известные patch states, согласованный functional test surface. Transitive graph и hashes измеряются, отличия явно проверяются.
2. **Exact payload replay:** одинаковый dependency graph/artifact bytes из проверенного lock/bundle. Заявлять только там, где такой lock/bundle реально подготовлен и воспроизведён.

Для lab replay сохранить безопасный dependency inventory, source/integrity и fingerprint тестируемого payload; reusable lock/bundle не должен содержать credentials, персональные registry URLs или runtime state. Не заменять штатную package installation семантику Pi произвольным npm layout. Полная bit-identical сборка всей ОС не является скрытой задачей этого плана.

## Этап D0 — собрать переносимый исходный пакет и классифицировать пробелы

**Работы**

1. Зафиксировать candidate source/docs refs и реальные manifests; отдельно working baseline, исследовательский baseline 0.99.1 и будущую цель 1.0.0.
2. Создать readiness board и список «компонент → источник → будущий owner/file → статус → проверка». Не подменять этим историческую доску 0.99.1.
3. Инвентаризировать только известные private harness sources, mock drivers и validators. Не читать личные DB/auth и не загружать все DEV/raw files ради инвентаризации.
4. Отнести каждый элемент к одной из категорий: repository source; пригодный для санитизации source; synthetic fixture; private receipt; невоспроизводимая ручная операция.
5. Для каждого сохраняемого helper записать dependencies, запуск, write scope, результат и ограничения. Source20/21 packet маркировать compile/managed/source-only; старый Win32 failure и raw-review timeout — отдельно.
6. Выбрать минимальный набор переносимых проверок и определить разрешения/машину B до actor work.

**Выход:** readiness board, source inventory и перечень необходимых разрешений. Raw receipts/installed payload не коммитятся.

**Приёмка:** каждый обязательный этап будущего workflow имеет источник и owner; зависимости от нынешних machine paths/личной памяти найдены; неизвестный native cause не назван исправленным.

## Этап D1 — закрепить постоянные правила и единый вход

**Работы**

1. Создать AGENTS.md с каталогом существующих и новой BUILD.LabUpgrade instruction; убрать заявление «AGENTS pending» только после появления файла и проверки ссылок.
2. В BUILD master разделить изменение состава, подготовку кандидата, применение к lab и release/profile switch. Manifest не является автоматическим разрешением на Apply.
3. Описать permission ladder: metadata/source → owned preparation → private install → dummy → baseline Pi mock → optional live routes → release/switch.
4. Закрепить fail-closed/no global fallback, пустой synthetic auth, отдельный state, scoped intercom и owned-only cleanup.
5. В PATCH/SEC добавить только действительно новые устойчивые правила; не копировать весь Windows эксперимент в инструкции.
6. Закрепить полезный размер среза: один функциональный результат, checks на затронутой границе, независимая проверка там, где она нужна; не создавать review/receipt цикл на каждое поле.
7. Закрепить handling infrastructure failure: сохранить source/partial diff/receipts, остановить dependent launches; same-protocol recovery после решения, не CLI bypass.

**Выход:** короткие сопровождаемые инструкции и полный AGENTS navigator.

**Приёмка:** frontmatter/path/link checks; нет дублирующего owner или временной истории в правилах; новый агент находит безопасную точку старта и понимает, что пока запрещено. Регистрация правил не выдаёт execution permission.

## Этап D2 — написать паспорт, upgrade runbook и контракт доказательств

**Работы**

1. Оформить docs/lab-stand.md по layout/машинному контракту выше, включая ограничения каждого механизма изоляции.
2. В docs/pi-upgrade-workflow.md описать полный маршрут: baseline → upstream delta → stand/preflight → разрешённая exact install → stock/patch checks → runtime/functional → model matrix → WVM LAST → GO/NO-GO/handoff.
3. Каждая команда имеет prerequisites, cwd, inputs, write scope, expected result, timeout/stop и recovery. Пока script/API не существует, пример явно помечается проектом, не готовой командой.
4. Исправить противоречия документации: docs/setup.md содержит старую Pi 0.87.0 при candidate lock 0.99.1; historical manual commands отделить от текущего lab runbook. Не менять рабочий runtime ради согласования текста.
5. В docs/platforms.md разделить предусмотренный POSIX layout, Git Bash syntax/fakes и фактически проверенную native платформу. Не выдавать архитектурную переносимость за live support.
6. Создать docs/lab-evidence.md: scope, fixtures/native distinction, provenance, exact source/payload, разрешение, raw result, coverage gaps, reviewer limits и residual risks.
7. Для данных/отката сослаться на существующий state-migration, не помещать backup/auth перенос в bootstrap.

**Минимум evidence packet:** run ID; repo/source/payload fingerprints; private machine/tool inventory; approved command/scope; время; PID lineage, когда применимо; natural exit либо timeout; stdout/stderr/raw errors; actual versus not-reached stages; cleanup results; coverage/attribution limits; источник review и что reviewer действительно проверил. Parent-recorded hash не описывать как independent recomputation.

**Переиспользование evidence:** только при совпадении существенных source/fixture/dependency/platform inputs и отсутствии изменения соответствующей границы. Новая машина требует своих environment/native результатов. Изменённый source не получает старый runtime PASS. PLAN не равно zero-write: запуск executable probe способен создавать private cache/logs; такие probes явно выделяются.

**Выход:** три самостоятельных документа и согласованные входные страницы без копирования session history.

**Приёмка:** по каждому gate ясно, кто/что/где проверяет, что считается провалом и чего результат не доказывает. Все README/setup/platform claims соответствуют текущим manifests и измеренному scope.

## Этап D3 — сделать preparation и тестовые средства исполняемыми

**Работы**

1. Добавить минимальный параметризованный entry point подготовки; reuse существующие lab-preflight/lab-state/common helpers вместо второго installer.
2. Разделить read-only filesystem/config PLAN, отдельно объявленные metadata executable probes и PREPARE нового owned subtree. Default не устанавливает пакеты, не исправляет shared ACL, не запускает Pi/native actors.
3. В PREPARE отказать на непустом/неизвестном root и небезопасных ancestors/links. Не очищать старый lab и не использовать force-repair. Повтор на exact prepared state — проверенный NO-OP либо отказ.
4. Создавать environment из allowlist, а не копии process.env; credential/NODE_OPTIONS/непроверенные redirect variables не наследовать. npm/uv/tool metadata operations получают private cache/config/cwd до запуска.
5. Добавить проверяемую schema/sample машинной конфигурации и общий safe receipt format. Actual values — только private output.
6. Перенести санитизированные mock provider/RPC/lifecycle fixtures и реальные validators в public source. Удалить зависимость от прежнего absolute SDK path, владельца и session directories; сохранить exact runtime/SDK identity assertions.
7. Известные успешные/failed native harness sources и managed contracts перенести после проверки области и лицензий. Native entry point остаётся opt-in/experimental; source tests не запускают DllImport и native declarations заменены guards/stubs.
8. Добавить один bounded test entry point с перечисленными режимами. Ни один режим не включает paid providers, host Pi fallback, forced-exit PASS или автоматический retry loop.

**Проектируемые артефакты:** `scripts/lab-stand.ps1`; schema/sample под `config/`; `tests/lab/` для mock/managed/native source; repository test runner и validator receipts. Окончательные имена/API закрепить после инвентаризации D0. Production native launcher не делать, пока experimental реализация не принята.

**Обязательные негативные проверки**

- Два разных safe roots, paths с пробелами/Unicode, иной repo location; отсутствие hardcoded username/drive.
- Непустой root, escaping/broken/cyclic link, unsafe parent ACL, неизвестный installed state — отказ до mutation/actor.
- Подставные credential env sentinels не проходят в child; никакого настоящего ключа в fixtures.
- Wrong Pi/SDK/package identity, PATH/global fallback, unknown patch bytes — отказ.
- Changed package filters/order/skill inventory; background-disabled surface не равен отсутствию bg_wait.
- Callback без actual artifact/result/terminal и terminal без default acceptance report не принимаются за accepted child.
- RPC JSONL/argv quoting/CRLF; stdin close failure всё равно reap/cleanup; losing timers закрываются без forced exit.
- Native-source managed cases: DWORD class20 exact length; full pointer class21, semantic identity, owned handle closure, documented Default absence; API/close errors fatal, buffers freed.
- Native declarations guard реально падает при попытке настоящего вызова из managed-only mode.

**Выход:** подготовка и tests, запускаемые из repo без private helper files. Нельзя использовать новый Plan/Prepare как alias установщика.

**Приёмка:** focused tests и syntax/schema gates зелёные на frozen source; known first failures сохранены отдельно; per-case scope проверяем; default не запускает native/Pi. Functional patch tests сохраняют version/hash/drift guards.

## Этап D4 — воспроизвести подготовку на машине B

**Работы**

1. Развернуть тот же source ref на независимой Windows машине/свежей VM; old lab directory и personal runtime-state не копировать.
2. Получить prerequisites/inventory по паспорту. Отсутствующие capabilities — BLOCKED с конкретным действием владельца; не silent skip или автоматическая установка на host.
3. По документации выполнить PLAN, отдельно разрешённый PREPARE и безопасные source/managed/fake tests.
4. Проверить fresh и exact repeated preparation, private env/paths, output outside Git и неизменность protected scopes в пределах заявленной проверки.
5. После отдельного разрешения и preliminary gate provision exact baseline 0.99.1/tools; зависимости сохранять/проверять по выбранному D0 replay contract. Native Pi functional actors этим ещё не разрешены.
6. Сопоставить inputs/payload fingerprints машин A/B. Новую transitive структуру или compiler/runtime difference не скрывать; определить затронутые проверки и ограничения.
7. Исправить каждый найденный undocumented manual step в script/runbook; воспроизвести исправленный шаг, а не делать всю миграцию заново.

**Выход:** новый machine-B packet и краткий воспроизводимый handoff; не копия старого evidence.

**Приёмка:** подготовка подтверждена другим окружением только по repo/docs; exact baseline artifacts идентифицированы; источник Pi/fixtures/private tools известен. Другой каталог на той же машине проверяет parameterization, но **не** заменяет portability test. Если машина B недоступна, этап NOT TESTED/BLOCKED.

**Рубеж:** после D0–D4 возможен READY_FOR_1.0_SOURCE с явным runtime BLOCK. Это не полное завершение плана.

## Этап D5 — закрыть исполняемый stand gate на baseline

Это отдельный рискованный этап. Перенос harness source в repo не разрешает его запуск; прежний ONE-attempt цикл завершён. Не обещать срок решения неизвестного initialization failure.

**Порядок**

1. Выбрать/согласовать механизм изоляции и scope. Для существующего Windows варианта не ослаблять unique restricting SID, DISABLE_MAX_PRIVILEGE/WRITE_RESTRICTED, low MIC, nonbreakaway Job, suspended assignment, private stdio, NEW noninteractive USER objects и NEW-token-only DACL correction. Caller token/shared ACL/WinSta0/existing desktop не менять.
2. Если нужна другая OS-isolation схема, получить отдельное решение и её контракт до реализации/launch; VM или отдельный user сами по себе не равны полной syscall/PID-attribution proof.
3. Frozen packet, exact dedicated `-File` invocation, allowed inputs/outputs и число launches проверить до запуска. Никаких `-Command` substitutions, implicit actor execution, flags sweep и source edits между review и тестом; pre/post hashes сохраняются.
4. После отдельного разрешения выполнить bounded dummy: root и настоящий descendant достигают JS; allowed runtime canary succeeds, harmless external lab canaries denied. Нельзя проверять denial записью в реальные memory/config/auth/cache.
5. Принять actual token/PID/Job/stdio/resource receipts, natural exit0 root/descendant и empty Job. Нулевой wrapper exit/validator exit без этих фактов недостаточен; NOT REACHED не считается successful cleanup.
6. Провести независимую read-only проверку actual raw result. Source review, compiler PASS и timeout reviewer не заменяют её. При FAIL сохранить причину и остановить dependent Pi lane; новая коррекция/попытка — новый bounded шаг с решением, а не автоматический retry.
7. Только после usable runner proof/raw approval и отдельного разрешения выполнить baseline Pi mock обоих профилей. Измерить actual descendant private SDK/version/env/PID linkage, actual returned output, natural lifecycle и default acceptance по честному synthetic критерию — не disabled gate.
8. Подтвердить state routes/capture: synthetic memory/session/trace/Goal/intercom/cache, private MCP config и protected boundary. Raw observer overflow/access/export errors, неизвестные descendants и PID-attribution gaps сохранять, не превращать в zero-writes.

**Выход:** новый actual raw packet, independent verdict и явно ограниченный исполняемый stand contract.

**Приёмка:** обязательные для принятой границы root/descendant, resource/lifecycle/identity и write-boundary доказательства есть. Если строгий native/global контракт не покрывается данным механизмом, **BLOCKED**, а не wording fix. Ограниченная API-query/managed проверка не закрывает этот gate. Network/read-secret/AppContainer guarantees не выводятся из MIC/Job.

Полный старый goal и историческое нарушение не закрываются автоматически даже успешным новым run. Изменение контракта допуска нового проекта и признание old goal complete — разные решения.

## Этап D6 — принять результат и передать старт Pi 1.0

**Работы**

1. Выполнить релевантные composed checks конечного ref; не гонять заново всё неизменённое дерево без причины. На seam «новая подготовка → existing preflight/installer/verifier → fixture runner» нужны fresh tests.
2. Проверить frontmatter/instruction catalog, schema, links, whitespace, public safety и вручную весь final diff. Tests/receipts из прежнего среза применимы только к доказанно неизменённым inputs.
3. В README/setup/passport/platform docs убрать недостоверные обещания; отметить native эксперимент как принятый лишь в измеренном scope либо сохранить BLOCKED.
4. Финализировать readiness board: DONE только с evidence, все обязательные D0–D6 resolved для runtime readiness; unresolved D5 не прятать за «документация готова».
5. Оставить воспроизводимый machine-B quick start и recovery/stop procedures. Исполнитель следующего шага не должен искать этот чат или угадывать состояние по private file timestamps.
6. Подготовить стартовый packet отдельной миграции: exact Pi1.0.0; working baseline0.87.0; source candidate0.99.1 как исследовательский baseline; точный source ref; protected paths/permissions; model/MCP matrices с NOT TESTED; remaining risks; критерии входа/выхода.
7. Получить явное решение о начале новой миграции. Не менять immutable objective старой строго0.99.1 цели и не возобновлять её скрыто как1.0.
8. Commit/push только в разрешённый candidate scope по [DOCS.CommitMessages](../../instructions/DOCS.commit_messages.instructions.md). Даже accepted stand не разрешает main/tag/profile switch.

**Минимальная стартовая delta-матрица 1.0**

- SDK/extensions/patch interfaces, peer resolution, package filters и source/hash guards — проверить, не объявлять совместимыми заранее.
- Fullscreen default и возврат regular mode; приёмы работы terminal/clipboard — отдельный TUI scope.
- Codemode token/description/errors и generateImages; экономию не переносить на каждый запрос, actual image-provider calls без разрешения NOT TESTED.
- MCP OAuth credential identity, scopes и deferred tools после resume/reload; тестировать отдельно от adapter route.
- `--provider` без `--model` должен отказать, а не выбрать другой provider.
- Radius/Anthropic login/new model routes — каталог/auth/live response разделены, credentials не копируются.
- Для builtin1.0 документированно stdio/streamable HTTP, legacy SSE не поддерживается. Сохранить adapter; возможная замена требует функционального паритета, не только номера1.0.
- WVM legacy SSE и streamable HTTP проверить отдельно **последним техническим этапом самой миграции1.0**, после остальных gates. Parent gateway/schema не candidate transport proof. До этого WVM заново не запускать ради подготовки docs.

**Выход:** accepted stand packet, truthful readiness decision и готовая точка входа для отдельно разрешённой работы1.0.

## Матрица приёмки плана

| ID | Проверяемый результат | Этап |
|---|---|---|
| R01 | Все обязательные harness/check steps имеют переносимый source и owner, private результаты отделены | D0 |
| R02 | AGENTS каталог полный; instructions краткие, без временных/machine/model деталей | D1 |
| R03 | Паспорт содержит реальные prerequisites, layout, scopes и причины отказа | D2 |
| R04 | Runbook команды существуют, write/probe semantics и permissions понятны; старые manual commands отделены | D2–D3 |
| R05 | Receipt schema различает source/mock/native, PASS/FAIL/NOT TESTED/BLOCKED и provenance | D2–D3 |
| R06 | PLAN/PREPARE fail-closed; shared/working dirs не mutation targets; no-op проверен | D3–D4 |
| R07 | Env/private executable/cwd/cache и fake descendant tests не допускают fallback/secret inheritance | D3–D4 |
| R08 | Санитизированные source/fixtures запускаются без прежних private helper paths | D3–D4 |
| R09 | Dependency replay level честно указан; actual graph/hashes/capabilities измерены | D4 |
| R10 | Другая Windows машина/VM воспроизвела подготовку по repo/docs | D4 |
| R11 | Fresh actual root+descendant native result принят с resource/identity/natural lifecycle proof | D5 |
| R12 | Actual controlled Pi mock SDK/env/default acceptance и state/boundary coverage соответствуют принятому контракту | D5 |
| R13 | Final composed/doc/safety checks и manual diff review относятся к принятому ref | D6 |
| R14 | Handoff1.0/permissions/readiness однозначны; oldgoal/main/release/profile constraints не изменены | D6 |

R01–R10 дают только SOURCE readiness. Полный READY_FOR_1.0_RUNTIME требует R01–R14 и отдельного решения о новой миграции. Ни один обязательный FAIL/BLOCKED не закрывается «принятым риском» без явного изменения соответствующего контракта владельцем. Optional paid/live/POSIX проверки остаются NOT TESTED и не включаются в заявления поддержки.

## Организация без повторения дорогих циклов

- Один интеграционный owner для AGENTS, shared docs, schema и readiness board. При делегировании — явные file allowlists, один writer на worktree, reviewers read-only; делегирование только по отдельному разрешению.
- Семь связанных этапов, не отдельный срез на каждое поле/строку. D1/D2 можно принимать общим doc contract slice; D3/D4 — executable/replay slice; D5 остаётся отдельным из-за actor permission и риска.
- Source/fixture corrections сначала воспроизводятся focused tests, затем implementation и bounded composed check. Full-suite запускать по изменённой границе, не как бесконечную диагностику.
- Независимость нужна для security/source изменения и реального D5 result; не создавать новый широкий аудит на каждом metadata receipt.
- Новые bounded шаги получают новые immutable packets. Исторические failures не перезаписываются; незатронутые checks не выдаются за freshly rerun.
- Infrastructure timeout сохраняется как failure и не создаёт implicit approval/новый launch. Actor лимит и deadline задаются в конкретном packet, не в вечной инструкции.

## CURRENT STATUS

- D0 source inventory **PASS**; initial D1/D2 docs **PASS**: каталог6,15Markdown/121targets/1anchor/errors0, verifier0/0 и safetyBoth/no findings. Начальный doc changeset создан до runtime edits; stand/public fixtures/native execution остаются впереди. D3–D6 ещё не приняты; подробности в readiness board.
- Working profiles/runtime не меняются; repository main/tag/GitHub Release разрешены после final gates. Candidate runtime manifest пока0.99.1, target1.0 не установлен.
- Старый native/runtime gate: **BLOCKED**; source20/21 approval остаётся только source/managed. Это не статус приостановки новой цели.
- Новая цель разрешает необходимую private подготовку/provisioning и bounded native/mock work; machine B/capabilities всё ещё надо получить/подтвердить, gate/raw approval не заменяются общим разрешением.
- Текущий связный срез: D0–D2 + initial doc commit, без установки/actors. Далее D3–D5 — reusable executable stand и actual replay.
- Runtime readiness не обещается до D4/D5; source/docs PASS не является live upgrade permission вне scope подтверждённой цели.
