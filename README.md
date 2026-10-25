# Pi Agent Build

**[Установить сборку — короткий вход для агента и человека](INSTALL_FOR_AGENTS.md).** Проверка источника → PLAN/Apply для своей ОС → Code/Task → credentials → короткая приёмка. [Настройка и специальные случаи](docs/setup.md).

Переносимое, version-pinned описание Pi Agent для Windows x64 и POSIX (macOS/Linux): два профиля, 15 верхнеуровневых Pi-пакетов, провайдер Polza AI, внешние инструменты Code-профиля, локальные исправления и проверки.

> **Текущая сборка: [Pi 1.4.0 build.3](docs/releases/pi-1.4.0-build.3.md).** Exact pins Pi 1.4.0 / Polza 0.2.2 сохранены. Session Search получает model-specific document/query prefixes и смысловое ранжирование по умолчанию; явный RRF остаётся доступным. Прежний контрольный запрос через установленный `session_search` нашёл нужную сессию **на rank1 из1293**. Memory Qwen query-only fix проверен настоящими product tools и automatic context-hook; документы/RRF памяти не меняются. Code/Task уже обновлены и прошли обычный SDK startup/verifier. Это контрольные примеры, не гарантия качества всех запросов; новые migration/reindex не добавлены. [Проверки и ограничения](docs/releases/pi-1.4.0-build.3.md), [GitHub Release и source ZIP](https://github.com/VladimirMonin/pi-agent-build/releases/tag/pi-v1.4.0-build.3). Публикация сама по себе не обновляет чужую установку; исторические результаты [build.2](docs/releases/pi-1.4.0-build.2.md) и [build.1](docs/releases/pi-1.4.0-build.1.md) сохранены.

Это не копия `~/.pi` и не курс. Репозиторий хранит декларативную конфигурацию, безопасные шаблоны, patchers, manifests, проверки и документацию. API-ключи, память, сессии, traces и другие личные данные сюда не входят.

> Предыдущий минирелиз: **[Pi 1.0.4 build.6](docs/releases/pi-1.0.4-build.6.md)** — Memory **1.6.0** Both, scoped whole-record automatic upstream vector recall и ephemeral context-hook; runtime fixes сохранены. Native SDK Both и installed real Polza русский canary PASS (2 successful requests, synthetic data). Memory Qwen1024d, DeepSeek-консолидация неизменна; SQLite backup вне Git, нужен полный restart. Предыдущий **[build.5](docs/releases/pi-1.0.4-build.5.md)** — MCP Adapter **5.1.0** Both, single owner; actual WVM/Context7/Fetch/Brave native checks PASS, WVM после проверки закрыт. Предыдущий [build.4](docs/releases/pi-1.0.4-build.4.md): Session Search **1.6.0** в Code/Task: native worker/profile paths/Windows reader checks PASS; короткий hybrid smoke с существующим Polza embedder PASS (2 requests, без personal reindex). Предыдущий [build.3](docs/releases/pi-1.0.4-build.3.md): Context Inspector **1.3.0** в Code/Task, Serena wrapper **0.9.20** в Code (Agent **1.7.0**). Native Serena/Pyright symbol smoke и synthetic Inspector resize/navigation PASS; настоящий visual TUI/editor/clipboard не проверены. Предыдущий [build.2](docs/releases/pi-1.0.4-build.2.md) закрепил Subagents **0.76.1**, Goal X **0.32.3**, Intercom **0.16.1**. В том историческом цикле Pi оставался **1.0.4**, картинки и terminal preview были включены в Code/Task. Candidate loading и короткий local-mock/Windows broker smoke — PASS. Core SDK local-mock и repository verifier PASS; полная plugin/live-provider приёмка на 1.0.4 не выполнялась. Настройки Goal X и Trace default-off не менялись. Release tag: `pi-v1.0.4-build.6`. Предыдущий core-only минирелиз: [build.1](docs/releases/pi-1.0.4.md). Предыдущий состав и его evidence: **[Pi 1.0.2 build.3](docs/releases/pi-1.0.2-build.3.md)**. Текущее состояние — в [readiness board](docs/plans/lab-readiness-board.md); правила — в [AGENTS.md](AGENTS.md).

## Граница повторяемости

Сборка закрепляет **верхнеуровневые** версии из [runtime lock](manifests/runtime.lock.json), [packages lock](manifests/pi-packages.lock.json) и [external-tools lock](manifests/external-tools.lock.json), включая immutable Git source. Installer вызывает штатный `pi install` для каждого profile package, а patchers принимают только поддержанные версии/структуры; правила сохранения существующего `settings.json` описаны в [setup](docs/setup.md).

Это даёт повторяемую установку заявленных top-level versions, но **не bit-for-bit reproducibility**. Репозиторий пока не содержит переносимых transitive lockfiles/полного dependency graph, integrity hashes всех скачиваемых artifacts, lock Python dependencies или идентичного образа ОС. Повторная установка может получить иной transitive dependency tree даже при тех же верхнеуровневых версиях. Для самодостаточного runtime artifact нужно отдельно зафиксировать transitive locks/hashes и затем проверить итоговый bundle. Source ZIP этого выпуска содержит описание сборки, а не установленный `node_modules`/offline runtime.

## Что описывает сборка

- профили `pi-code` и `pi-task` с 15 и 12 Pi-пакетами соответственно;
- нативный провайдер [pi-polza](https://github.com/VladimirMonin/pi-polza);
- Trace, Context Inspector, Todo, subagents/intercom, MCP, session search, SQLite memory и Goal-X (`/goal`);
- Code-профиль с ast-grep, Serena и Codebase Memory;
- русификацию Trace и Windows/profile-aware исправления;
- Polza embeddings для поиска истории и служебную модель консолидации memory;
- навык обслуживания памяти Pi.

Точный перечень 15 пакетов и версии: [`manifests/pi-packages.lock.json`](manifests/pi-packages.lock.json) и [`docs/components/README.md`](docs/components/README.md).

## Связанные проекты

- [pi-polza](https://github.com/VladimirMonin/pi-polza) — нативный динамический provider Polza AI с отдельным учётом RUB; сборка устанавливает ревизию из своего manifest.
- [Project Foundation Kit](https://github.com/VladimirMonin/Project-Foundation-Kit) — переносимые инженерные методы, инструкции и шаблоны. Подключается отдельно **полным pack** по инструкции PFK, с ресурсами и notices; ссылка не устанавливает навыки и не меняет Code/Task автоматически.

## Автономный Goal X

Code/Task сразу получают [пресет](docs/goal-autonomy.md): unlimited без `maxAutonomousRuns`, implicit continuation, tasks depth 2, независимый Auditor и read-only Oracle с `openai-codex/gpt-6.1-sol`/`high`. Существующие персональные настройки сохраняются. Для модели нужен собственный Codex login; auth в сборку не входит.

## Известное ограничение: порядок `pi-goal-x` и `pi-intercom`

`pi-goal-x` должен загружаться **раньше** `pi-intercom` — так закреплено в манифесте и обоих шаблонах профилей. При обратном порядке headless-прогоны (`pi -p`, `--mode json`, `--mode rpc`) печатают в stderr ошибку `turn_end` boundary и ошибку stale `ctx` при создании цели.

Ошибка **не фатальна** (цель создаётся, exit code 0) и **не проявляется** в интерактивном TUI, но засоряет вывод и вводит в заблуждение при автоматизированных прогонах. Полная матрица проверок, подтверждённые условия и механизм — в [`docs/notes/goal-x-intercom-order.md`](docs/notes/goal-x-intercom-order.md).

## Безопасность

Репозиторий принципиально не содержит:

```text
auth.json           API-ключи и OAuth-токены
memory.db           личную долговременную память
sessions/ traces/   историю работы и tool payload
node_modules/       установленные зависимости
личные пути         имена пользователей и рабочие каталоги
```

Публичные шаблоны используют placeholders. Секреты вводятся локально после установки. Перед публикацией запускайте `scripts/safety-check.ps1` (Windows) или `scripts/safety-check.sh` (POSIX), но не считайте автоматический scan заменой ручному просмотру diff.

## Структура

```text
manifests/          закреплённые top-level версии Pi, пакетов и внешних CLI
profiles/           шаблоны профилей Code и Task
config/             безопасные примеры MCP/provider/memory config
patches/            version-guarded исправления, tests и upstream notices
skills/             собственные переносимые Pi-навыки
docs/components/    документация 15 установленных Pi-пакетов
docs/notes/         заметки о поведении upstream-компонентов и его причинах
scripts/            install, launcher install, patch orchestration, verify, safety scan
instructions/       постоянные правила сопровождения репозитория
```

Скрипты существуют в двух вариантах: `.ps1` для Windows x64 и `.sh` для POSIX (macOS/Linux). Оба набора читают одни и те же manifests и применяют одни и те же patchers.

`update.ps1`/`update.sh` отсутствуют. Переход к выбранному **опубликованному** составу — preserving installer и короткая приёмка из [установочного входа](INSTALL_FOR_AGENTS.md); разработка новых pins — [отдельный upgrade workflow](docs/pi-upgrade-workflow.md). Конкретный дефект: существующий owner → воспроизведение → минимальная правка → адресная проверка → конец. Не используйте `latest` и не заставляйте обычного установщика заново разрабатывать выпуск.

## Исторический кандидат Pi 0.99.1

- [Лабораторный план](docs/plans/pi-0.99.1-lab.md), [доска доказательств](docs/plans/pi-0.99.1-execution-board.md) и [модельная матрица](docs/plans/pi-0.99.1-model-matrix.md) разделяют проверенные функции, metadata и NOT TESTED; Sol 6.1 уже доступна владельцу на старом Pi, это не update-specific gain.
- [Изоляция лаборатории](docs/lab-isolation.md): отдельный owner-only root **и безопасный parent**, чистые synthetic HOME/config/auth/cache/session/trace/MCP, явные private executables; никаких изменений shared ACL. JavaScript guard не является OS sandbox.
- Проверены private Windows установка 15/12 пакетов, оба mock headless runtime и verified Apply no-op; дополнительно — two-peer intercom, native async child callback/artifact/terminal и CLI-only background shell output обоих профилей. Paired canonical bytes не менялись. Это narrow lifecycle PASS: native mock без attestation получил default acceptance REJECTED; все команды/провайдеры этим не подтверждены. WVM повторно оценён последним после source-only query corrections/review и gates: parent gateway connect33/public schema version1 PASS; прежние failures сохранены. Это не candidate protocol proof. Private query fixes имеют только managed/source approval, controlled native runner остаётся BLOCKED. Legacy SSE / streamable HTTP кандидата NOT TESTED. Adapter без доказанного live-паритета не заменяется.
- Полная zero-write изоляция не доказана: native observation сохранил raw host events и изменение timestamp рабочего memory WAL без PID-attribution; personal contents не читались. Исторический npm diagnostic log раскрыт, не удалён. `main`, рабочие профили и пользовательские данные не переключались. Будущий перенос/откат требует отдельного решения и согласованных private backups [runtime, обоих профилей и данных](docs/state-migration.md#откат).

## Начало работы

- Установка принятой ревизии: **[INSTALL_FOR_AGENTS.md](INSTALL_FOR_AGENTS.md)**. Исторические [команды Pi 0.87](docs/history/pi-0.87-install.md) не являются текущим рецептом.
- Для **разработки нового состава**, не обычной установки: [upgrade workflow](docs/pi-upgrade-workflow.md), [паспорт стенда](docs/lab-stand.md), [контракт доказательств](docs/lab-evidence.md). [План D0–D6](docs/plans/lab-repeatability-and-portability.md) и [readiness board](docs/plans/lab-readiness-board.md) хранят ход разработки. Исторический [Pi 1.3.0 release scope](docs/releases/pi-1.3.0-build.1.md) отделяет independent fresh checks от reused evidence; его Trace SDK Both и прежние CLI результаты сохраняются на исходной версии. Текущие pins берите из manifests, [команды Trace](docs/trace.md) — из справки.
- Установка и точные prerequisites: [`docs/setup.md`](docs/setup.md)
- Границы профилей: [`docs/profiles.md`](docs/profiles.md)
- Перенос приватного state: [`docs/state-migration.md`](docs/state-migration.md)
- Компоненты: [`docs/components/README.md`](docs/components/README.md)
- Заметки о поведении компонентов: [`docs/notes/README.md`](docs/notes/README.md)
- POSIX (macOS/Linux): [`docs/platforms.md`](docs/platforms.md); общие принципы установки — [`docs/setup.md`](docs/setup.md).

## Документация для агентов

[`AGENTS.md`](AGENTS.md) — короткий вход и полный каталог инструкций. При upgrade читайте [`BUILD.LabUpgrade`](instructions/BUILD.lab_upgrade.instructions.md), паспорт/runbook/evidence docs и текущий readiness board. Не переносите временные machine paths, модели reviewer или run history в постоянные правила; документы не выдают permission сами по себе. [Команды Trace opt-in/off](docs/trace.md) проверены реальными Code/Task SDK и CLI runs; browser UI остаётся вне этого smoke scope.

## Лицензирование

Оригинальные материалы проекта распространяются по [`LICENSE`](LICENSE) (MIT). Сторонние зависимости перечислены в [`THIRD_PARTY.md`](THIRD_PARTY.md). Точные notices для vendored/modified upstream source в `patches/` находятся в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) и соответствующих patch directories. Корневая MIT license не перелицензирует сторонний код, сервисы или модели.
