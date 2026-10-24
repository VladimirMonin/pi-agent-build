# pi-session-search 1.6.0: model prefixes, смысловой поиск и Windows roots

Поддерживается ровно `pi-session-search@1.6.0`. Immutable store и hashes охватывают source files из `REL_FILES` в [patcher-е](apply.py) и **оба `dist/index.js`/`dist/index-worker.js`**; проверка предшествует writes. Display path включает utils, session/FTS index и index-service. Исполняемый worker входит в тот же check/apply/backup/restore contract, не только исходный TypeScript.

Task сохраняет `<TASK_PROFILE>/session-search/{config.json,index}`, `sessions` и `sessions-archive`. Code сохраняет stock `~/.pi/session-search` и стандартные sources. Project `localPath` и явные config overrides не меняются.

Оба режима:

- учитывают `PI_SESSION_DIR`, затем `PI_CODING_AGENT_SESSION_DIR`; archive override `PI_SESSION_ARCHIVE_DIR` сохраняется;
- передают выбранные source roots в `IndexOptions → workerData`;
- показывают настоящий `session.cwd`, если он есть; без cwd сохраняют исходный slug, не угадывают путь заменой дефисов. Одинаковое правило действует в main/worker и производном summary;
- `session_read` использует те же configured/default/extra roots, Windows-safe `path.relative` containment и canonical paths для защиты от symlink/junction escape;
- очищают проигравший initial-sync timeout в `finally` при resolve/reject, сохраняя настоящий timeout.

Native default home и раскрытие/сокращение `~` теперь используют `node:os.homedir()`, не `HOME || "~"`/пустую строку. Windows без `HOME` больше не получает относительный root с буквальным `~`, а file references из search/list можно передать в `session_read`.

Incremental sync удаляет исчезнувшие записи **только из успешно просмотренной части sources**. Missing/unreadable root или подкаталог сохраняет прежние JSON/vectors/FTS rows и reader state; readable empty root по-прежнему позволяет удалить действительно исчезнувшие сессии. Отсутствующий optional archive не блокирует удаление из доступного active root. Записи вне выбранных roots консервативно сохраняются при смене конфигурации.

Legacy `hybrid-fts.db`, таблица `s`: load дополняет отсутствующие **session IDs** из сохранённой metadata, не перезаписывая существующий полный текст и JSON/vector bytes, без вызовов embedder. Равные counts не доказывают равный состав IDs; chunks другой базы не сравниваются с session count. Отсутствовавший полный текст нельзя полностью восстановить из stripped metadata.

Новый cross-process reload/sync framework не добавлен: tools используют тот же `IndexService`, который выполняет sync. Успешный собственный sync обновляет list/search/read и в прежнем 1.6.0. Мгновенная видимость произвольной записи JSON другим процессом не обещается: нужны обычный sync либо reload.

Без `project` поиск межпроектный внутри выбранного config/index, с `project` — суженный. Это не объединяет профили и project-local индексы. В [build.2](../../docs/releases/pi-1.4.0-build.2.md#известное-ограничение-смыслового-поиска) ранжирование ещё не исправлено; прежний FAIL не переименовывается в PASS. Текущая delta добавляет `embedder.documentPrefix/queryPrefix` с модельными defaults и явными пустыми overrides, а default `fusion` меняет на `vector-primary` без вызова FTS arm. Явный `rrf` остаётся доступным; модель/размерность/индексы не переключаются. Таблица шести моделей, точные строки, первоисточники, локальные aliases и границы backend-проверки — в [основном описании](../../docs/fixes/session-search.md#правила-документов-и-вопросов).

## Использование

```powershell
# Code: stock config/index paths
python .\patches\session-search-profile\apply.py --agent-dir "$HOME\.pi\agent" --runtime-only --apply
# Task: profile config/index paths
python .\patches\session-search-profile\apply.py --agent-dir "$HOME\.pi\task" --apply
```

Для `--check`/`--restore` используйте тот же режим. Check states: `patched` (exit 0), `stock`/`previous-patched`/`published-patched`/`released-patched` (exit 1), unknown/unsupported (exit 2). Исторические состояния — root/timer без display, последующий display patch и build.2 без prefix/ranking delta. Это точные полные byte sequences, не диапазон версий и не marker check. Apply идемпотентен, все known previous получают verified backup всех `REL_FILES` с SHA-256 receipt перед переходом; restore byte-exact из immutable store. Backups только под выбранным профилем `.pi-agent-build-backups/session-search-profile`. Mixed main/worker и чужой режим отвергаются до writes. Несколько file writes не объявляются атомарными: interrupted mixed state требует verified backup recovery, не обхода guard.

## Проверка и данные

`python patches/session-search-profile/tests/test_runtime.py` проверяет режимы, drift refusal, restore и реальные resolve/reject/timeout settlement. Windows script regression проверяет immutable stores. Native short smoke на synthetic sessions: actual worker стартует/закрывается, Code/Task ищут и читают свои sessions/archive/extra roots; посторонние пути и symlink escape отклоняются.

Индексы/config/Polza model остаются на прежних путях. Старые сохранённые FTS/vector summaries обновляются для display при чтении из session с cwd, без изменения сохранённых rows/vectors. **Не нужен forced `/session-reindex` ради обновления**. При смене модели/размерности/documentPrefix переиндексацией управляет пользователь; новых проверок совместимости, миграций и автоматического пересчёта нет. У Qwen documentPrefix остаётся пустым, поэтому query-only исправление не требует пересчитывать документы той же модели. Явный старый `fusion: rrf` сохраняется: для перехода меняется только это поле. Reinstall стирает patch; примените его снова и перезапустите Pi. Package restore не откатывает индекс или настройки.

Текущая delta проверяет no-HOME paths/read round trip, недеструктивный partial scan и FTS ID coverage; прежние display/timer/containment cases сохранены. Наличие команд в README не является результатом запуска. Независимая source приёмка и normal SDK/native tools рабочего обновления разделены в [release evidence](../../docs/releases/pi-1.4.0-build.2.md); loopback fixture не доказывает качество настоящего semantic provider.

До рабочего обновления освободите фактических index writers и сохраните verified recovery snapshot. Полезный существующий JSON с векторами оставьте на месте: недостающие legacy FTS IDs достраиваются локально при load. Если прежний writer уже опустошил JSON, patch сам не восстановит утраченные vectors — сначала нужен проверенный непустой snapshot. Не маскируйте отсутствие recovery массовым платным reindex.

`python -B -m unittest discover -s patches/session-search-profile/tests -p "test_*.py" -v` дополнительно проверяет native Windows Node с отсутствующим `HOME` **до imports**, настоящие registered handlers в main/actual worker/affected TypeScript, default/config/env/extra roots, search-file → read round trip, containment, missing root, реальный native `ENOTDIR` у неперечислимого существующего root, readable empty deletion, partial legacy FTS и reader после собственного sync. Нужны locked Node на PATH, `SESSION_SEARCH_TYPEBOX` с entry module реального установленного peer и `TMP`/`TEMP`/`TMPDIR` внутри разрешённого private fixture root. Только Pi registry/UI host — fixture; неизменённые TS dependencies берутся из shipped bundle. Synthetic hybrid использует loopback fixture embeddings, не live semantic provider. Эти checks не являются проверкой личной истории, native permission-denied или real SDK lifecycle.

`test_embedding_prefixes.py`: 15 пар document/query на настоящих source/main/worker factory bodies, точные wire inputs и пустые/custom overrides, config default/явный RRF и semantic path без keyword arm. Сетевой ответ — fixture, не проверка доступности шести моделей. Код провайдеров и существующая численная шкала результата не переписаны.
