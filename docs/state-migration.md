# Перенос пользовательского состояния

Этот репозиторий повторяет закреплённые top-level versions и конфигурационную схему, но не обещает byte-identical dependency tree без transitive locks. Он намеренно не хранит secrets, память, сессии, traces и индексы. Runtime-state переносится отдельным зашифрованным каналом вне Git.

## Стенд не является переносом пользовательского состояния

[Лабораторный паспорт](lab-stand.md) и [upgrade workflow](pi-upgrade-workflow.md) создают новую synthetic среду. Машина B получает repository source/fixtures и private dependency provisioning, **не** old profiles, memory, auth, sessions или stale locks. Runtime migration/backups ниже выполняются в действующем scope рабочего переключения; release репозитория его сам не выполняет. Уже данное разрешение переносится в continuation, а не запрашивается заново. Core package update не требует миграции auth, памяти/DB или sessions и не разрешает менять Goal settings.

## Классификация

| Категория | Примеры | Перенос |
|---|---|---|
| Декларативная | `settings.json`, `models.json`, несекретные MCP settings | пересоздать из шаблонов и вручную сравнить allowlist |
| Credentials | `auth.json`, OAuth/keyring, API keys | предпочтительно повторный `/login`; не коммитить и не печатать |
| Пользовательские данные | `sessions/`, `traces/`, `memory.db`, intercom/session-search data | только если действительно нужны, в зашифрованном архиве |
| Восстановимое | чистые `npm/`, `git/`, индексы session-search/CBM, caches | при переносе машины восстановить из exact sources; dirty work сначала сохранить, индекс перестраивать только при необходимости |
| Локальные patches | изменённые файлы внутри packages | не копировать; применить patchers к чистой поддержанной версии |

## Локальное обновление и новая машина

На той же машине сохраняйте действующие configs и data routes: смена package version сама по себе не требует переноса auth/DB/history или reindex. При partial failure продолжайте [незавершённый этап](pi-upgrade-workflow.md#рабочая-установка-короткое-продолжение-не-повтор-installer), сохраняя original preservation witnesses, не создавая новую baseline из изменённых live files.

Dirty extension work сохраняется целиком вне profile discovery; force/reset/clean для её удаления не применяются. При разрешённой замене проверенный standalone public checkout и старый tree переключаются rename-only на одной volume, без overwrite/copy/delete fallback. Перед каждым rename проверяются identities, links и коллизии; разрешённые links сохраняются без dereference. После перемещения retained tree проверяется по pinned root/`.git` identity и HEAD: прежний absolute `core.worktree` не обязан совпадать с новым top-level, а retained tree не считается runnable checkout. Resume требует проверенного observed state, не одного journal label; неизвестное состояние означает отказ.

На новой машине packages устанавливаются из exact sources, configs создаются из безопасных templates, а выбранные пользовательские данные переносятся отдельно зашифрованным каналом. Сохранение dirty work при локальном обновлении не означает её автоматического включения в новую canonical установку.

## Подготовка источника

1. Завершите обе сессии Pi штатно, чтобы SQLite WAL и trace writers закрылись.
2. Убедитесь, что нет процессов Pi, Serena, CBM и фоновых children, работающих с каталогами.
3. Запишите версии `pi --version`, `node --version`, `pi list` для каждого профиля.
4. До replacement сохраните profiles/runtime/launchers, exact identities, patch states и original preservation witnesses **вне Git/sync** с restrictive ACL. Recovery copy должна пройти file-set/byte verification; общая DB — SQLite backup API и destination integrity check. Не заменяйте witnesses post-failure baseline.
5. Зашифруйте архив до переноса на другую машину; пароль/ключ передавайте отдельным каналом.

Не создавайте архив в каталоге Git даже временно: случайный `git add -A` может сохранить секреты в истории.

## Что переносить при необходимости

### Профильные данные

Для каждого `<PI_CODING_AGENT_DIR>` отдельно:

- `sessions/` и `sessions-archive/`, если нужна история;
- `traces/`, только если нужны локальные отчёты;
- `auth.json` — только как крайний вариант между доверенными машинами; безопаснее новый `/login`;
- локальные provider/package configs без cache;
- intercom config, но не stale pid/lock/socket files.

Caches и stale process locks не переносятся. Retained trees и recovery backups локального обновления сохраняются по правилам выше; они не являются disposable cache.

### Общая память

По умолчанию оба профиля используют:

```text
~/.pi/memory/memory.db
~/.pi/memory/memory.db-wal
~/.pi/memory/memory.db-shm
```

Это **default, не доказательство active route**. Public resolver учитывает actual CWD и project `.pi/settings.json`: `pi-memory.localPath`, затем legacy `pi-total-recall.localPath`; при отсутствии selectors используется homedir default независимо от Code/Task profile dir. Проверяйте выбранные CWD/HOME/selector routes безопасной metadata/path-only проверкой, не читайте config bodies ради отчёта.

Для согласованной копии используйте SQLite backup API и проверьте destination integrity до replacement. Quiescent file-copy допустима только при действительно остановленных writers и согласованном WAL-наборе; один основной `.db` во время записи не копируется.

Если в согласованном scope нужна функциональная проверка выбранного shared route: `memory_remember` создаёт уникальный безвредный fact с owned key/nonce в Code; `memory_search` в Task должен вернуть **ту же** запись; `memory_forget` с `type: fact` и полным exact key удаляет только её, следующий поиск подтверждает отсутствие. Результаты фильтруются по собственному marker **до** display/report; чужой текст/counts не публикуются. Используйте установленные product/tool APIs, не raw SQL. Регистрация tools не заменяет retrieval; FTS-only fallback, успешный embedding и вклад vector ranking — разные claims. Уже принятую применимую проверку не повторяйте ради нового timestamp.

Project-local memory (`<project>/.pi/.../memory.db`) переносится вместе с проектом, но остаётся приватным runtime-data и должен быть исключён из Git.

### Session search

Это поиск по history/index, **не shared Memory fact store**. Восстановимый индекс не требует автоматического массового `/session-reindex` после каждого package update. Сохраняйте действующий index/config route; reindex нужен при реальной необходимости и в разрешённом scope. Default index/config roots сборки:

- Code: `~/.pi/session-search/`;
- Task после patch: `~/.pi/task/session-search/`.

History source roots по умолчанию Code — `~/.pi/agent/sessions`/`sessions-archive`, Task после patch — соответствующие каталоги Task. Они не совпадают с Memory DB. Project-local index redirects, runtime env и extra roots могут менять выбор; defaults/registration не доказывают здоровье всего personal index. Для проверки маршрутов/owned-file чтения переиспользуйте применимые source/native evidence, не запускайте broad personal-history indexing ради отчёта.

`config.json` Polza содержит API key в явном поле `apiKey`; не помещайте его в незашифрованный архив и лучше введите ключ заново. Индексы могут содержать извлечённый текст приватных сессий и тоже считаются чувствительными. Границы разрешённого paid lifecycle определяет [BUILD.LabUpgrade](../instructions/BUILD.lab_upgrade.instructions.md#исполнение-и-gates). Учитывайте естественный startup bound pinned Memory (сейчас до64 записей за старт), не добавляйте starts как retry-loop.

### CBM и Serena

- CBM databases под `~/.cache/codebase-memory-mcp/` восстанавливаются переиндексацией. Если всё же переносите крупный индекс, сохраните `_config.db` и проектные DB согласованно, но проверяйте их новой версией CLI.
- `.db-wal`/`.db-shm` у CBM — нормальные файлы WAL, а не признак зависшего процесса.
- Serena project state `.serena/` зависит от проекта и версии. При переносе конфигурации учитывайте ключ `language_servers:` в Serena `1.7.0`; cache можно пересоздать.

## Развёртывание на целевой машине

1. Выполните чистую [установку](setup.md) по manifests.
2. Создайте profile configs из публичных шаблонов.
3. Выполните `/login` заново и задайте secrets локально.
4. Примените patches к установленным чистым пакетам.
5. Остановите Pi и только затем восстановите выбранные сессии/память.
6. Не заменяйте новый `settings.json` старым целиком: перенесите только известные поля, чтобы не вернуть старые versions/source filters.
7. Сохраните совместимые индексы; переиндексируйте только при необходимости, не попутно со сменой package version.

## Проверка после переноса

- `pi-code list` и `pi-task list` показывают правильный состав;
- `/context` подтверждает различие tool surfaces;
- `/trace` пишет в каталог активного профиля;
- `session_list` не смешивает Task и Code после профильного patch;
- если shared-Memory проверка нужна по scope, canary проходит remember → cross-profile retrieval → exact-key forget → отсутствие; successful embeddings и fallback различаются, цену без измерения не заявляйте;
- `/polza-model-info`, `/polza-balance` и `pi --list-models` работают после повторного входа;
- `serena_status`, `ast_search` и `/cbm status` работают только в Code.

Проверяйте выборочные записи, а не публикуйте полные дампы в issue или CI logs.

## Откат

Откат применяется к actual baseline/partial checkpoint разрешённого рабочего переключения, не к историческому номеру candidate. Он не даёт worker разрешения использовать credentials/личные DB как fixtures и не означает автоматическое восстановление при любом failure.

До будущего переключения сохраните в `<PRIVATE_BACKUP>` оба полных Code/Task профиля, launchers, точные runtime/package identities и patch states. Данные памяти/сессий/индексов/traces сохраняйте согласованно: SQLite online backup либо quiescent window, не main DB без активного WAL. Сохраняйте source=user, scope/aliases и старые каталоги; secrets только приватно.

Если миграция не прошла:

1. Штатно остановите candidate-owned jobs; не завершайте посторонние сессии.
2. Верните **оба** launcher на `<BASELINE_RUNTIME>` и `<BASELINE_CODE_PROFILE>`/`<BASELINE_TASK_PROFILE>` с совместимыми tools/environment. Старый baseline не удалять.
3. Восстановите только изменённую конфигурацию из согласованных private backups, не новый settings целиком поверх старого runtime.
4. При изменениях схемы/записей восстановите compatible SQLite backup в остановленную БД; не перезаписывайте open DB. Сохраните отдельно candidate-only новые записи, когда это требуется.
5. Верните sessions/archive/index/trace маршруты, проверьте scope, source=user, launcher/version/patch проверки обоих профилей. Для model smokes соблюдайте [действующие границы разрешений](../instructions/BUILD.lab_upgrade.instructions.md#исполнение-и-gates).

Git revert сам по себе **не откат**: должны совпасть executable, оба профиля и данные. Не запускайте две копии SQLite DB через сетевую/sync-папку и не очищайте shared npm cache. Удаление backup/ротация credentials — отдельное действие после подтверждённой целостности.
