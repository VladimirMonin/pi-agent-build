# Pi Agent Build

Переносимое, version-pinned описание Pi Agent для Windows x64 и POSIX (macOS/Linux): два профиля, 14 верхнеуровневых Pi-пакетов, провайдер Polza AI, внешние инструменты Code-профиля, локальные исправления и проверки.

Это не копия `~/.pi` и не курс. Репозиторий хранит декларативную конфигурацию, безопасные шаблоны, patchers, manifests, проверки и документацию. API-ключи, память, сессии, traces и другие личные данные сюда не входят.

> Статус: до первого release tag интерфейсы install/verify и состав manifests могут меняться. Корневой `AGENTS.md` пока не выпущен; постоянные правила находятся в `instructions/`.

## Граница повторяемости

Сборка закрепляет и проверяет **верхнеуровневые** версии: Pi `0.87.0`, Node.js/npm, 14 Pi-пакетов, внешние CLI и immutable Git object для Git-источника. Installer вызывает штатный `pi install` для каждого profile package, а patchers принимают только поддержанные версии/структуры; правила сохранения существующего `settings.json` описаны в [setup](docs/setup.md).

Это даёт повторяемую установку заявленных top-level versions, но **не bit-for-bit reproducibility**. Репозиторий пока не содержит переносимых transitive lockfiles/полного dependency graph, integrity hashes всех скачиваемых artifacts, lock Python dependencies или идентичного образа ОС. Повторная установка может получить иной transitive dependency tree даже при тех же верхнеуровневых версиях. Для release artifact нужно отдельно зафиксировать transitive locks/hashes и затем проверить итоговый bundle.

## Что описывает сборка

- профили `pi-code` и `pi-task` с 14 и 11 Pi-пакетами соответственно;
- нативный провайдер [pi-polza](https://github.com/VladimirMonin/pi-polza);
- Trace, Context Inspector, Todo, subagents/intercom, MCP, session search и SQLite memory;
- Code-профиль с ast-grep, Serena и Codebase Memory;
- русификацию Trace и Windows/profile-aware исправления;
- Polza embeddings для поиска истории и служебную модель консолидации memory;
- навык обслуживания памяти Pi.

Точный перечень 14 пакетов и версии: [`manifests/pi-packages.lock.json`](manifests/pi-packages.lock.json) и [`docs/components/README.md`](docs/components/README.md).

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
docs/components/    документация 14 установленных Pi-пакетов
scripts/            install, launcher install, patch orchestration, verify, safety scan
instructions/       постоянные правила сопровождения репозитория
```

Скрипты существуют в двух вариантах: `.ps1` для Windows x64 и `.sh` для POSIX (macOS/Linux). Оба набора читают одни и те же manifests и применяют одни и те же patchers.

`update.ps1`/`update.sh` сейчас отсутствуют: обновление выполняется только как осознанное изменение manifests/templates/patches с повторной установкой и проверкой. Не используйте `latest` и не предполагайте наличие автоматического update workflow.

## Начало работы

- Установка и точные prerequisites: [`docs/setup.md`](docs/setup.md)
- Границы профилей: [`docs/profiles.md`](docs/profiles.md)
- Перенос приватного state: [`docs/state-migration.md`](docs/state-migration.md)
- Компоненты: [`docs/components/README.md`](docs/components/README.md)
- POSIX (macOS/Linux) установка: [`docs/setup.md`](docs/setup.md#posix-macoslinux) и [`docs/platforms.md`](docs/platforms.md)

## Документация для агентов

Корневой `AGENTS.md` находится в статусе **pending** и не входит в текущий release surface. Пока используйте [`instructions/BUILD.master.instructions.md`](instructions/BUILD.master.instructions.md) и тематические файлы из `instructions/`; не утверждайте, что каталог уже агрегирован в `AGENTS.md`.

## Лицензирование

Оригинальные материалы проекта распространяются по [`LICENSE`](LICENSE) (MIT). Сторонние зависимости перечислены в [`THIRD_PARTY.md`](THIRD_PARTY.md). Точные notices для vendored/modified upstream source в `patches/` находятся в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) и соответствующих patch directories. Корневая MIT license не перелицензирует сторонний код, сервисы или модели.
