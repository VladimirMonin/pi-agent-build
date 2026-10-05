# Pi Agent Build

Переносимое, version-pinned описание Pi Agent для Windows x64 и POSIX (macOS/Linux): два профиля, 15 верхнеуровневых Pi-пакетов, провайдер Polza AI, внешние инструменты Code-профиля, локальные исправления и проверки.

Это не копия `~/.pi` и не курс. Репозиторий хранит декларативную конфигурацию, безопасные шаблоны, patchers, manifests, проверки и документацию. API-ключи, память, сессии, traces и другие личные данные сюда не входят.

> Статус: **Pi 1.0.2 candidate**. Последняя стабильная версия сверена по официальным npm и GitHub; exact version закреплена в manifests. Реальная Windows-установка, CLI, локальный SDK mock обоих профилей, загрузка расширений с Trace off, guarded patches и Both installed verifier проверены. Холодный локальный эмбеддер в offline mock использует FTS-fallback; semantic embedding, платные провайдеры, candidate WVM SSE/HTTP и native Linux/macOS этим не подтверждены. Полный release ещё не принят, живые Code/Task не переключены; `pi-mcp-adapter` сохранён. Текущие результаты — в [readiness board](docs/plans/lab-readiness-board.md), правила — в [AGENTS.md](AGENTS.md). Обновление выполняется обычными установочными scripts, без VM и native isolation runners.

## Граница повторяемости

Сборка закрепляет и проверяет **верхнеуровневые** версии: Pi `1.0.2` (candidate), Node.js/npm, 15 Pi-пакетов, внешние CLI и immutable Git object для Git-источника. Installer вызывает штатный `pi install` для каждого profile package, а patchers принимают только поддержанные версии/структуры; правила сохранения существующего `settings.json` описаны в [setup](docs/setup.md).

Это даёт повторяемую установку заявленных top-level versions, но **не bit-for-bit reproducibility**. Репозиторий пока не содержит переносимых transitive lockfiles/полного dependency graph, integrity hashes всех скачиваемых artifacts, lock Python dependencies или идентичного образа ОС. Повторная установка может получить иной transitive dependency tree даже при тех же верхнеуровневых версиях. Для release artifact нужно отдельно зафиксировать transitive locks/hashes и затем проверить итоговый bundle.

## Что описывает сборка

- профили `pi-code` и `pi-task` с 15 и 12 Pi-пакетами соответственно;
- нативный провайдер [pi-polza](https://github.com/VladimirMonin/pi-polza);
- Trace, Context Inspector, Todo, subagents/intercom, MCP, session search, SQLite memory и Goal-X (`/goal`);
- Code-профиль с ast-grep, Serena и Codebase Memory;
- русификацию Trace и Windows/profile-aware исправления;
- Polza embeddings для поиска истории и служебную модель консолидации memory;
- навык обслуживания памяти Pi.

Точный перечень 15 пакетов и версии: [`manifests/pi-packages.lock.json`](manifests/pi-packages.lock.json) и [`docs/components/README.md`](docs/components/README.md).

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
scripts/            install, launcher install, patch orchestration, verify, safety scan, memory embedder warm-up
instructions/       постоянные правила сопровождения репозитория
```

Скрипты существуют в двух вариантах: `.ps1` для Windows x64 и `.sh` для POSIX (macOS/Linux). Оба набора читают одни и те же manifests и применяют одни и те же patchers.

`update.ps1`/`update.sh` сейчас отсутствуют: обновление выполняется только как осознанное изменение manifests/templates/patches с повторной установкой и проверкой. Не используйте `latest` и не предполагайте наличие автоматического update workflow.

## Исторический кандидат Pi 0.99.1

- [Лабораторный план](docs/plans/pi-0.99.1-lab.md), [доска доказательств](docs/plans/pi-0.99.1-execution-board.md) и [модельная матрица](docs/plans/pi-0.99.1-model-matrix.md) разделяют проверенные функции, metadata и NOT TESTED; Sol 6.1 уже доступна владельцу на старом Pi, это не update-specific gain.
- [Изоляция лаборатории](docs/lab-isolation.md): отдельный owner-only root **и безопасный parent**, чистые synthetic HOME/config/auth/cache/session/trace/MCP, явные private executables; никаких изменений shared ACL. JavaScript guard не является OS sandbox.
- Проверены private Windows установка 15/12 пакетов, оба mock headless runtime и verified Apply no-op; дополнительно — two-peer intercom, native async child callback/artifact/terminal и CLI-only background shell output обоих профилей. Paired canonical bytes не менялись. Это narrow lifecycle PASS: native mock без attestation получил default acceptance REJECTED; все команды/провайдеры этим не подтверждены. WVM повторно оценён последним после source-only query corrections/review и gates: parent gateway connect33/public schema version1 PASS; прежние failures сохранены. Это не candidate protocol proof. Private query fixes имеют только managed/source approval, controlled native runner остаётся BLOCKED. Legacy SSE / streamable HTTP кандидата NOT TESTED. Adapter без доказанного live-паритета не заменяется.
- Полная zero-write изоляция не доказана: native observation сохранил raw host events и изменение timestamp рабочего memory WAL без PID-attribution; personal contents не читались. Исторический npm diagnostic log раскрыт, не удалён. `main`, рабочие профили и пользовательские данные не переключались. Будущий перенос/откат требует отдельного решения и согласованных private backups [runtime, обоих профилей и данных](docs/state-migration.md#откат).

## Начало работы

- Перед следующим обновлением: [паспорт стенда](docs/lab-stand.md), [upgrade workflow](docs/pi-upgrade-workflow.md), [контракт доказательств](docs/lab-evidence.md). [План D0–D6](docs/plans/lab-repeatability-and-portability.md) и [readiness board](docs/plans/lab-readiness-board.md) отделяют исторические эксперименты от текущего обычного обновления. Source и установка уже переведены на exact Pi 1.0.2; Trace default-off проверен загрузкой обоих профилей, explicit opt-in ещё проверяется.
- Установка и точные prerequisites: [`docs/setup.md`](docs/setup.md)
- Границы профилей: [`docs/profiles.md`](docs/profiles.md)
- Перенос приватного state: [`docs/state-migration.md`](docs/state-migration.md)
- Компоненты: [`docs/components/README.md`](docs/components/README.md)
- Заметки о поведении компонентов: [`docs/notes/README.md`](docs/notes/README.md)
- POSIX (macOS/Linux): [`docs/platforms.md`](docs/platforms.md); общие принципы установки — [`docs/setup.md`](docs/setup.md).

## Документация для агентов

[`AGENTS.md`](AGENTS.md) — короткий вход и полный каталог инструкций. При upgrade читайте [`BUILD.LabUpgrade`](instructions/BUILD.lab_upgrade.instructions.md), паспорт/runbook/evidence docs и текущий readiness board. Не переносите временные machine paths, модели reviewer или run history в постоянные правила; документы не выдают permission сами по себе. Проверенные команды Trace opt-in/off появятся после соответствующего runtime task — сейчас это pending implementation, не готовый recipe.

## Лицензирование

Оригинальные материалы проекта распространяются по [`LICENSE`](LICENSE) (MIT). Сторонние зависимости перечислены в [`THIRD_PARTY.md`](THIRD_PARTY.md). Точные notices для vendored/modified upstream source в `patches/` находятся в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) и соответствующих patch directories. Корневая MIT license не перелицензирует сторонний код, сервисы или модели.
