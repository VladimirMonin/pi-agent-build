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

1. Зафиксируй working baseline, source candidate ref, private test root и permissions текущей задачи. Не путай допуск исследования с release/profile switch.
2. Сверь официальный stable release/npm metadata безопасным read-only способом. До первого manifest change зафиксируй exact target; не двигай цель вслед за latest во время одного цикла.
3. Подготовь связанные документы/матрицу «delta → риск → проверка» и закоммить проверенную исходную документацию до переноса runtime.
4. Работай в отдельной ветке/worktree. Runtime-state не пишется в Git checkout. Старый lab не очищается и не становится fresh root по force.
5. Подготовка и capabilities проверяются до provisioning; host prerequisites/shared ACL не исправляются автоматически.

## Размещение и окружение

- Working checkout/profiles, lab worktree и private lab root разделены. Проверяется root **и ancestors**, ownership, filesystem и link policy.
- Env создаётся из allowlist для конкретного child: private HOME/USERPROFILE, config/cache/temp, npm/uv roots, profile/session/archive/cwd/trace/Goal/intercom/MCP routes. Не копируй process.env целиком.
- Provider credentials, NODE_OPTIONS и неизвестные redirects не наследуются. Даже npm metadata операции могут писать logs: private env/cache/config задаются **до** их запуска.
- Pi/SDK/external tools имеют явные проверенные paths/identities. PATH/global fallback не является recovery.
- Config/auth/DB в lab только synthetic. Допустимость пустого автоматически созданного auth-store не разрешает копировать настоящий auth.
- Fresh root, installed-state no-op и explicit opt-in runtime states — разные состояния. Unknown/mixed/drift state отказывается, не repair/reinstall.

## Исполнение и gates

1. Read-only filesystem/config PLAN не включает скрытые executable probes. `lab-stand` preparation config не является actor/provisioning packet; prepared canonical NO-OP и installed-state gate различаются. Tests получают explicit owned private FixtureRoot, не создают runtime-state рядом с checkout. Пробы выделяются: у них есть write scope, timeout и actual coverage.
2. PREPARE создаёт только новый owned subtree по явному scope. Private provisioning выполняется после preliminary gate и допуска установки.
3. Source/managed tests сначала; native actors — отдельный bounded frozen packet с разрешённой командой и pre/post fingerprints.
4. До Pi runtime требуется usable root+descendant runner proof и независимая actual raw приёмка принятой native boundary. Source review/compiler/mock не заменяют этот gate.
5. Target Code/Task подтверждают actual executable/SDK/env/PID linkage, private state routes, natural lifecycle и configured acceptance. Дочерний callback сам по себе не означает наличие принятого результата.
6. Model catalog, mock request, auth и paid response проверяются отдельно. Не заявляй live support по metadata; платные вызовы не включаются автоматически.
7. Required WVM transport checks выполняются последним техническим этапом после основных gates. Legacy SSE и streamable HTTP — отдельные cases; parent gateway не candidate proof. Adapter не заменяется без функционального паритета; dual /mcp owners запрещены.
8. Final docs/manifest/tests относятся к одному принятому ref. Release/main/tag/profile switch требуют scope владельца, а не следуют автоматически из lab PASS.

Не отключай checksum/version/identity guards, SkipPatchChecks/SkipExternalChecks ради приёмки. Не выдавай forced-exit/validator exit0 за natural process PASS. Конкретный native механизм и его неизменяемые security параметры описываются паспортом/packet; новая схема не получает прежний approval автоматически.

## Профили и Trace

Сохраняй два режима: Code (полный) и Task (облегчённый). Политика нового выпуска: Trace package присутствует, extension выключен по умолчанию в **обоих** canonical profiles. Проверяется поведение, не только JSON marker.

Явное включение и возврат off документируются и тестируются на synthetic profiles. Способ «один запуск» предпочтителен для диагностики без изменения canonical state; persistent opt-in, если поддержан, описывает влияние installer/sync и verifier. Не придумывай CLI/config recipe по памяти, сначала проверь текущую Pi/package семантику. Не делай третий профиль/launcher вместо opt-in. Диагностические receipts испытаний не являются запуском Trace plugin.

## Recovery, review и handoff

- Один writer на cwd/worktree. Делегирование только по запросу/применимым разрешениям; независимые reviewers read-only, parent принимает результат.
- Failure сохраняется вместе с frozen/partial source, command и coverage. Останавливается опасная/dependent operation; дальнейшие действия соответствуют scope текущей задачи, а не обходят failed gate.
- Infrastructure timeout не approval. Не переключайся молча на внешний CLI/protocol; same-protocol recovery и сохранение partial diff обязательны.
- Исправляй воспроизведённый дефект focused tests → correction → seam check. Не порождай полные audit/launch циклы на каждое поле.
- Unchanged evidence переиспользуется только после проверки relevant inputs. Новая машина и изменённый native source требуют fresh соответствующего доказательства.
- Handoff содержит changed files/ref, tests/commands/results, boundaries/risks, remaining work, commit/push/release state и следующий допустимый шаг. История не стирается; current status отделён от неё.
