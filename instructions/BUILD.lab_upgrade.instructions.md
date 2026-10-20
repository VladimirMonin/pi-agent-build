---
applyTo: "scripts/lab-*,scripts/install.*,scripts/verify.*,tests/lab/**,tests/scripts/lab-*,config/lab-*,config/schemas/lab-*,manifests/**,profiles/**,docs/lab-*.md,docs/pi-upgrade-workflow.md,docs/plans/**"
name: "BUILD.LabUpgrade"
description: "Читай при обновлении Pi/пакетов, подготовке переносимого стенда, изменении lab environment/fixtures/gates, проверке кандидата или передаче к release: scope, permissions, fail-closed и evidence."
---

# BUILD — Лабораторное обновление и переносимый стенд

## Ответственность и источники

Эта инструкция владеет устойчивым **upgrade/lab workflow**, не составом сборки или историей запусков. Состав/release регулирует [BUILD.Master](BUILD.master.instructions.md), patches — [PATCH.Maintenance](PATCH.maintenance.instructions.md), публикацию — [SEC.PublicRepository](SEC.public_repository.instructions.md).

Подробности: [паспорт](../docs/lab-stand.md), [runbook](../docs/pi-upgrade-workflow.md), [evidence](../docs/lab-evidence.md). Статусы и временные решения принадлежат board/плану, не этой инструкции. Не закрепляй здесь номер текущего Pi, absolute machine paths, модели reviewer, tool budgets или run IDs.

## До изменения runtime

1. Зафиксируй исходное рабочее состояние, ref кандидата, private test root и уже выданный scope. До первой записи сверь **фактически установленные pins Code и Task**, metadata dirty/untracked/ignored изменений пакетов, links и ожидаемые lifecycle side effects. Для этого не требуется читать private payload/diff. Статус PREPARED не подтверждает готовность к исполнению: фактические предусловия должны быть проверены перед передачей на установку.
2. Сверь официальный stable release/npm metadata безопасным read-only способом и закрепи exact target. Не двигай его автоматически вслед за latest; новый прямой запрос владельца на последнюю версию разрешает новый exact target.
3. Подготовь связанные документы/матрицу «delta → риск → проверка» и закоммить проверенную исходную документацию до переноса runtime.
4. Работай в отдельной ветке/worktree. Runtime-state не пишется в Git checkout. Старый lab не очищается и не становится fresh root по force.
5. По умолчанию используй обычный установочный каталог и существующие scripts. Не создавай VM, Windows Sandbox, native runner или новую систему изоляции без отдельного запроса владельца. Host prerequisites/shared ACL не исправляются автоматически.

## Размещение и окружение

- Working checkout/profiles, lab worktree и private lab root разделены. Проверяется root **и ancestors**, ownership, filesystem и link policy.
- Env создаётся из allowlist для конкретного child. В synthetic/lab задавай private HOME/USERPROFILE, config/cache/temp, npm/uv и остальные state routes; в рабочем запуске сохраняй подтверждённые HOME/profile/CWD/data routes. Не копируй process.env целиком и не наследуй неизвестные preloads/redirects.
- В synthetic/lab children provider credentials, NODE_OPTIONS и неизвестные redirects не наследуются. Для разрешённого обычного запуска сохраняй существующий provider/config route, не копируя его в fixtures. Даже npm metadata операции могут писать logs: private env/cache/config задаются **до** их запуска.
- Dependency paths задавай только нужному interpreter/child. В частности, helper `PYTHONPATH` может подменить зависимости другого Python native tool даже у `--version`. При таком import failure сначала сравни точные executable/arguments с чужим path и без него; исправление process-local env не требует переустановки shared tool. Это диагностика конкретного отказа, не обязательная пара проб при каждом обновлении.
- Pi/SDK/external tools имеют явные проверенные paths/identities. Проверяется настоящий SDK import и actual внутренние dependency edges, не только top-level CLI version: caret graph может смешать несовместимые поколения. Failed install сохраняется; изменение согласованного target требует fresh root, не manual peer/exports repair. PATH/global fallback не является recovery.
- Config/auth/DB в lab только synthetic. Допустимость пустого автоматически созданного auth-store не разрешает копировать настоящий auth.
- Fresh root, installed-state no-op и explicit opt-in runtime states — разные состояния. Runtime-generated metadata допускается только по узкому проверенному контракту pinned package (strict types/keys/size/version), не свободным directory allowlist. Unknown/mixed/drift state отказывается, не удаляется ради PASS и не repair/reinstall.

## Исполнение и gates

1. Read-only filesystem/config PLAN не включает скрытые executable probes. `lab-stand` preparation config не является actor/provisioning packet; prepared canonical NO-OP и installed-state gate различаются. Tests получают explicit owned private FixtureRoot, не создают runtime-state рядом с checkout. Пробы выделяются: у них есть write scope, timeout и actual coverage.
2. PREPARE создаёт только новый owned subtree по явному scope. Private provisioning выполняется после preliminary gate и допуска установки.
3. Source/managed tests сначала; native actors — отдельный bounded frozen packet с разрешённой командой и pre/post fingerprints.
4. Обычная установка не требует native boundary или второй машины. Не заявляй OS containment/full-global zero-write по отдельному каталогу, env или mock. Native boundary и её actual raw review нужны только когда владелец отдельно заказал такую защитную границу; прежние непринятые эксперименты остаются историей, не prerequisite обычного обновления.
5. Target Code/Task подтверждают actual executable/SDK/env/PID linkage, private state routes, natural lifecycle и configured acceptance. Env host echo не доказывает загруженный SDK; связывай actual runner/module identity с обслуживающим child context. Joint exchange и поздний completion проверяй раздельными фазами, не предполагаемым свободным wake slot. Дочерний callback сам по себе не означает наличие принятого результата.
6. Model catalog, mock request, auth и paid response проверяются отдельно. Не заявляй live support по metadata. В пределах уже выданного scope обычный bounded lifecycle существующего paid provider, включая согласованную startup/embedding работу памяти, не требует повторного согласия. Выбор provider сам по себе не разрешает произвольные расходы: новая provider/model/dimensions migration, несвязанный paid probe и ручной массовый backfill/reindex остаются отдельным scope. До старта учитывай естественные side effects pinned package; регистрация не заменяет functional retrieval.
7. Required WVM transport checks выполняются последним техническим этапом после основных gates. Legacy SSE и streamable HTTP — отдельные cases; parent gateway не candidate proof. Adapter не заменяется без функционального паритета; dual /mcp owners запрещены.
8. Final docs/manifest/tests относятся к одному принятому ref. Release/main/tag/profile switch требуют scope владельца, а не следуют автоматически из lab PASS.

Fixture с отдельным installedProfile проверяет именно этот путь и ancestors до imports/settings I/O; проверка одного output root не разрешает доступ к рабочему профилю. Terminal output-limit discriminator должен отличаться от early-length recovery и подтверждать current answer без omission; неверный stimulus не является основанием для production patch.

Не отключай checksum/version/identity guards, SkipPatchChecks/SkipExternalChecks ради приёмки. Не выдавай forced-exit/validator exit0 за natural process PASS. Конкретный native механизм и его неизменяемые security параметры описываются паспортом/packet; новая схема не получает прежний approval автоматически.

## Профили и Trace

Сохраняй два режима: Code (полный) и Task (облегчённый). Политика нового выпуска: Trace package присутствует, extension выключен по умолчанию в **обоих** canonical profiles. Проверяется поведение, не только JSON marker.

Явное включение и возврат off документируются и тестируются на synthetic profiles. Способ «один запуск» предпочтителен для диагностики без изменения canonical state; persistent opt-in, если поддержан, описывает влияние installer/sync и verifier. Не придумывай CLI/config recipe по памяти, сначала проверь текущую Pi/package семантику. Не делай третий профиль/launcher вместо opt-in. Диагностические receipts испытаний не являются запуском Trace plugin.

## Recovery, review и handoff

- Один writer на cwd/worktree. Делегирование только по запросу/применимым разрешениям; независимые reviewers read-only, parent принимает результат.
- Failure сохраняется вместе с frozen/partial source, command и достигнутыми стадиями. Продолжай **только незавершённый остаток из actual checkpoint**, не весь installer поверх изменённого baseline или существующего backup. Original preservation witnesses не заменяются post-failure hashes. Останавливается dependent operation; достаточные unchanged PASS переиспользуются, failed gate не обходится.
- До замены нужны verified private recovery copy и release всех runtime/data writers. Данные, dirty trees, SQLite integrity и retained identity/HEAD защищаются по [правилам переноса и восстановления](../docs/state-migration.md#локальное-обновление-и-новая-машина). Неизвестное состояние означает отказ, не copy/delete/restore fallback.
- Независимые явно собственные временные артефакты очищай после natural exit их владельцев и свежей проверки ownership/consumers, даже если другой gate ещё ждёт. Direct-holder0 не заменяет release всех writers; список ready не означает фактическое удаление. Сохраняй необходимые evidence, original histories, чужую работу, retained trees, recovery snapshot и состояние активных исполнителей; результат уборки фиксируется в [handoff](../docs/pi-upgrade-workflow.md#рабочая-установка-короткое-продолжение-не-повтор-installer).
- Infrastructure timeout не approval. Не переключайся молча на внешний CLI/protocol; same-protocol recovery и сохранение partial diff обязательны.
- Исправляй воспроизведённый дефект focused tests → correction → seam check. Не порождай полные audit/launch циклы на каждое поле.
- Unchanged evidence переиспользуется только после проверки relevant inputs. Новая машина и изменённый native source требуют fresh соответствующего доказательства.
- Handoff содержит changed files/ref, tests/commands/results, boundaries/risks, remaining work, commit/push/release state и следующий допустимый шаг. История не стирается; current status отделён от неё.
