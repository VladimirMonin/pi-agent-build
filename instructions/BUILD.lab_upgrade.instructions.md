---
applyTo: "scripts/lab-*,scripts/install.*,scripts/verify.*,tests/lab/**,tests/scripts/lab-*,config/lab-*,config/schemas/lab-*,manifests/**,profiles/**,docs/lab-*.md,docs/pi-upgrade-workflow.md,docs/plans/**"
name: "BUILD.LabUpgrade"
description: "Читай при обновлении Pi/пакетов, подготовке переносимого стенда, изменении lab environment/fixtures/gates, проверке кандидата или передаче к release: scope, permissions, fail-closed и evidence."
---

# BUILD — Лабораторное обновление и переносимый стенд

## Ответственность и источники

Эта инструкция владеет устойчивым **upgrade/lab workflow**, не составом сборки или историей запусков. Состав/release регулирует [BUILD.Master](BUILD.master.instructions.md), patches — [PATCH.Maintenance](PATCH.maintenance.instructions.md), публикацию — [SEC.PublicRepository](SEC.public_repository.instructions.md).

Подробности: [паспорт](../docs/lab-stand.md), [runbook](../docs/pi-upgrade-workflow.md), [evidence](../docs/lab-evidence.md). Статусы и временные решения принадлежат board/плану, не этой инструкции. Не закрепляй здесь номер текущего Pi, absolute machine paths, модели reviewer, tool budgets или run IDs.

Применяй этот workflow к **разработке нового состава**, не к установке принятой опубликованной версии: у неё [короткий вход](../INSTALL_FOR_AGENTS.md). Конкретный дефект проходит воспроизведение → минимальную правку → affected check → завершение. Отдельный live-эксперимент нужен при существенной неопределённости внешнего контракта; доступность модели/ключа не повод повторять прежнюю квалификацию. Уже применимое evidence сохраняет исходные версию/ОС/scope.

## До изменения runtime

1. Зафиксируй исходное рабочее состояние, ref кандидата, private test root и уже выданный scope. До первой записи сверь **фактически установленные pins Code и Task**, metadata dirty/untracked/ignored изменений пакетов, links и ожидаемые lifecycle side effects. Для этого не требуется читать private payload/diff. Статус PREPARED не подтверждает готовность к исполнению: фактические предусловия должны быть проверены перед передачей на установку.
2. Сверь официальный stable release/npm metadata безопасным read-only способом и закрепи exact target. Не двигай его автоматически вслед за latest; новый прямой запрос владельца на последнюю версию разрешает новый exact target.
3. Зафиксируй «delta → риск → достаточная проверка» в существующей задаче/owner-документе; отдельная матрица и предварительный doc commit нужны лишь при реальной необходимости большого изменения, не для каждого fix.
4. При необходимости отдели candidate branch/worktree, сохранив ownership и чужую работу; для малого непересекающегося ремонта worktree не обязательный ритуал. Runtime-state не пишется в Git checkout. Старый lab не очищается и не становится fresh root по force.
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

## Документация выпуска: где живут версии

При каждом обновлении состава/ядера версии живут в точном наборе мест; обновляй их одним срезом и сверяй с manifests, а не с памятью — это предотвращает дрейф «вроде обновили, а в доках старое». Механическую сверку даёт `scripts/check-doc-versions.mjs` (входит в verify).

1. `manifests/runtime.lock.json` — `runtime.pi.version` и `compatibility.minimumNode` с честным `reason`; `manifests/pi-packages.lock.json` — версии пакетов.
2. `profiles/*/settings.template.json` — `lastChangelogVersion` = версия Pi.
3. `README.md` — блок «**Текущая сборка: [Pi …](docs/releases/…)**» и цепочка предыдущих релизов (новый вперёд, прежний — в «Предыдущие минирелизы»).
4. `CHANGELOG.md` — новая запись `## [pi-v<версия>-build.<N>] — <дата>` первой сверху.
5. `docs/releases/pi-<версия>-build.<N>.md` (имя файла — имя тега без `v`) — новая заметка выпуска; прошлые immutable.
6. `docs/plans/lab-readiness-board.md` — новая секция «## Текущая сборка …» первой сверху, прежняя переименовывается в «Исторический принятый выпуск …».
7. `docs/setup.md` — строка текущей ревизии и таблица prerequisites (рабочий диапазон против lab-пинов).
8. `INSTALL_FOR_AGENTS.md` — таблица версий/диапазонов, если менялся состав или prerequisites.

Правила: полные теги (`pi-1.4.0-build.3`) вместо коротких ярлыков «build.N» — номера повторяются между циклами; «Текущий/Свежий» — только для текущего выпуска; исторические файлы (`docs/history/**`, прошлые `docs/releases/*`, старые записи CHANGELOG) не переписываются — исправление ложного исторического заявления идёт новой записью текущего выпуска.

## Разведка обновлений

Проверка новых версий upstream — read-only: только метаданные, без установки и скачивания кода. Находка не равна обновлению; обновление состава выполняется отдельным срезом по этому файлу.

**Исполнитель и инструменты.** Шаги 2–4 выполняет сессия с shell (npm/git) и web-fetch. Разрешены только read-only запросы метаданных и чтение веб-страниц: `npm view <пакет> version versions time dist-tags`, `git ls-remote --tags`, страницы репозиториев (commits, compare, releases, issues); запрещены clone, fetch, pull, checkout и любое скачивание payload. Метаданные npm/git пишут логи — запускай их с private env/cache (см. «Размещение и окружение»). Если нужных инструментов у исполнителя нет — разведка останавливается без вердиктов, фиксирует блокировку и запрашивает внешние метаданные у руководителя, помечая их чужим сбором. Имена пакетов бери из manifests, не из памяти (ядро — `@earendil-works/pi-coding-agent`, не `pi`); для внешних CLI уточняй реестр по типу инструмента (npm — `@ast-grep/cli`; PyPI — `serena-agent`); prerelease не считай кандидатом без явной пометки (сверяй `dist-tags`).

**Репозиторий обязателен.** Если поле repository в manifests или реестре пустое — ищи источник по порядку: `package.json` установленной копии пакета (`<PROFILE_DIR>/npm/node_modules/<пакет>/package.json`), её `CHANGELOG.md`, страница пакета на npmjs (ссылки Links), поиск по имени пакета. Заявление «репозитория/нот нет» допустимо только после всех этих шагов — с перечнем проверенного.

1. Baseline — `manifests/runtime.lock.json` и `manifests/pi-packages.lock.json`; для пакетов с нашими локальными патчами дополнительно — их `patches/<имя>/README.md`.
2. Сбор версий по метаданным (инструменты — выше) для всех пакетов, ядра и внешних CLI.
3. Черновая таблица diff «у нас / новее» (даты, количество шагов) — служебная, для триажа.
4. Триаж changelog/release notes **и диффов коммитов** только выросших пакетов: безопасность и багфиксы → новые возможности → ломающие изменения. Ноты автора не заменяют список изменений и не являются фактом: обязательный минимум по каждому выросшему пакету — commit log/compare закреплённой и новой версии (страницы commits/compare репозитория); тонкие ноты («Includes #NNN») добивай страницами issues/PR. Результат триажа — конкретный список «что изменилось»: примерный допустим, но список обязателен. «Неизвестно, что вышло» — не результат разведки, и вердикт без такого списка не ставится. Где сверить заявление с кодом не удалось — помечай точечно `NOT VERIFIED (только слова автора)` и снижай вес довода; сплошное NOT VERIFIED допустимо только с указанием причины, отчёт из-за этого не прерывается.
5. **Сверка с нашими фиксами обязательна** для пакетов, у которых есть локальные патчи или правки: что именно патч чинил (по его README), влит ли фикс апстримом (тогда патч подлежит снятию), трогает ли новая версия зону патча (тогда патч требует переноса и проверки на новой версии). Критерий «влит апстримом»: сопоставь зону патча (файлы его patcher'а, наши byte-anchors) с изменениями новой версии; фикс считать влитым, когда наше поведение присутствует в новой версии (описано в нотах или видно в коде) и наши anchors больше не находятся.
6. Итог одной таблицей отчёта (в отличие от черновика п.3 — с оценками и ссылками; допустима ссылка на строку выдержки релиз-ноута с пометкой «ноты, с коммитами не сверено», ссылка на коммит — когда compare доступен): что выросло, что важно (включая судьбу наших патчей), **оценка трудоёмкости** (перенос патчей, правки настроек, объём приёмки — включая обязательные повторные проверки по [BUILD.Master](BUILD.master.instructions.md) → «Правило сторонних пакетов», пп. 5–6) и **оценка целесообразности** (безопасность/багфиксы на наших путях — весомо; чужие фичи и косметика — слабый довод; ломающие изменения — считать стоимость). Вердикт по каждому пакету: взять / подождать / не нужно / обсудить. Вердикт «обсудить» требует приложенного краткого списка изменений из диффов и сформулированных вариантов решения — обсуждать нечего без фактов.

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
