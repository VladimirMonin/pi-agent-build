# Перенос пользовательского состояния

Этот репозиторий повторяет закреплённые top-level versions и конфигурационную схему, но не обещает byte-identical dependency tree без transitive locks. Он намеренно не хранит secrets, память, сессии, traces и индексы. Runtime-state переносится отдельным зашифрованным каналом вне Git.

## Стенд не является переносом пользовательского состояния

[Лабораторный паспорт](lab-stand.md) и [upgrade workflow](pi-upgrade-workflow.md) создают новую synthetic среду. Машина B получает repository source/fixtures и private dependency provisioning, **не** old profiles, memory, auth, sessions или stale locks. Runtime migration/backups ниже выполняются только при отдельном разрешённом working-profile switch; release репозитория его не выполняет.

## Классификация

| Категория | Примеры | Перенос |
|---|---|---|
| Декларативная | `settings.json`, `models.json`, несекретные MCP settings | пересоздать из шаблонов и вручную сравнить allowlist |
| Credentials | `auth.json`, OAuth/keyring, API keys | предпочтительно повторный `/login`; не коммитить и не печатать |
| Пользовательские данные | `sessions/`, `traces/`, `memory.db`, intercom/session-search data | только если действительно нужны, в зашифрованном архиве |
| Восстановимое | `npm/`, `git/`, индексы session-search/CBM, caches | не переносить; переустановить/переиндексировать |
| Локальные patches | изменённые файлы внутри packages | не копировать; применить patchers к чистой поддержанной версии |

## Подготовка источника

1. Завершите обе сессии Pi штатно, чтобы SQLite WAL и trace writers закрылись.
2. Убедитесь, что нет процессов Pi, Serena, CBM и фоновых children, работающих с каталогами.
3. Запишите версии `pi --version`, `node --version`, `pi list` для каждого профиля.
4. Сделайте файловую резервную копию профилей и общей memory DB **вне рабочего дерева репозитория**.
5. Зашифруйте архив до переноса; пароль/ключ передавайте отдельным каналом.

Не создавайте архив в каталоге Git даже временно: случайный `git add -A` может сохранить секреты в истории.

## Что переносить при необходимости

### Профильные данные

Для каждого `<PI_CODING_AGENT_DIR>` отдельно:

- `sessions/` и `sessions-archive/`, если нужна история;
- `traces/`, только если нужны локальные отчёты;
- `auth.json` — только как крайний вариант между доверенными машинами; безопаснее новый `/login`;
- локальные provider/package configs без cache;
- intercom config, но не stale pid/lock/socket files.

Не переносите `npm/`, `git/`, `.pi-agent-build-backups/`, package cache и process locks. Пакеты ставятся заново, затем patches применяются заново.

### Общая память

По умолчанию оба профиля используют:

```text
~/.pi/memory/memory.db
~/.pi/memory/memory.db-wal
~/.pi/memory/memory.db-shm
```

При полностью остановленных процессах SQLite обычно checkpoint-ит WAL. Если `-wal`/`-shm` всё ещё есть, переносите согласованный набор из трёх файлов либо используйте SQLite backup API; копировать только основной `.db` во время записи нельзя. После переноса установите restrictive ACL и выполните `memory_stats`/`memory_search`.

Project-local memory (`<project>/.pi/.../memory.db`) переносится вместе с проектом, но остаётся приватным runtime-data и должен быть исключён из Git.

### Session search

Индекс восстанавливаемый, поэтому безопаснее перенести только локальный `config.json`, затем выполнить `/session-reindex`. В сборке:

- Code: `~/.pi/session-search/`;
- Task после patch: `~/.pi/task/session-search/`.

`config.json` Polza содержит API key в явном поле `apiKey`; не помещайте его в незашифрованный архив и лучше введите ключ заново. Индексы могут содержать извлечённый текст приватных сессий и тоже считаются чувствительными.

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
7. Переиндексируйте session-search и CBM.

## Проверка после переноса

- `pi-code list` и `pi-task list` показывают правильный состав;
- `/context` подтверждает различие tool surfaces;
- `/trace` пишет в каталог активного профиля;
- `session_list` не смешивает Task и Code после профильного patch;
- `memory_stats` возвращает ожидаемые ненулевые counts, а тестовый `memory_search` не падает;
- `/polza-model-info`, `/polza-balance` и `pi --list-models` работают после повторного входа;
- `serena_status`, `ast_search` и `/cbm status` работают только в Code.

Проверяйте выборочные записи, а не публикуйте полные дампы в issue или CI logs.

## Откат

Pi 0.99.1 остаётся **candidate**: main/user switch и backup рабочих данных в лабораторном прогоне не выполнялись. Этот порядок применяется только после отдельного разрешения владельца, не даёт worker разрешения читать credentials/личные DB.

До будущего переключения сохраните в `<PRIVATE_BACKUP>` оба полных Code/Task профиля, launchers, точные runtime/package identities и patch states. Данные памяти/сессий/индексов/traces сохраняйте согласованно: SQLite online backup либо quiescent window, не main DB без активного WAL. Сохраняйте source=user, scope/aliases и старые каталоги; secrets только приватно.

Если миграция не прошла:

1. Штатно остановите candidate-owned jobs; не завершайте посторонние сессии.
2. Верните **оба** launcher на `<BASELINE_RUNTIME>` и `<BASELINE_CODE_PROFILE>`/`<BASELINE_TASK_PROFILE>` с совместимыми tools/environment. Старый baseline не удалять.
3. Восстановите только изменённую конфигурацию из согласованных private backups, не новый settings целиком поверх старого runtime.
4. При изменениях схемы/записей восстановите compatible SQLite backup в остановленную БД; не перезаписывайте open DB. Сохраните отдельно candidate-only новые записи, когда это требуется.
5. Верните sessions/archive/index/trace маршруты, проверьте scope, source=user, launcher/version/patch проверки обоих профилей. Реальные model smokes требуют отдельного разрешения.

Git revert сам по себе **не откат**: должны совпасть executable, оба профиля и данные. Не запускайте две копии SQLite DB через сетевую/sync-папку и не очищайте shared npm cache. Удаление backup/ротация credentials — отдельное действие после подтверждённой целостности.
