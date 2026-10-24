# Pi 1.4.0 build.2 — Windows session-search и сохранность индекса

Дата: 2026-10-24. Тег выпуска: `pi-v1.4.0-build.2` (аннотированный). Предыдущий выпуск: [Pi 1.4.0 build.1](pi-1.4.0-build.1.md). Ниже — приёмка кандидата; публикация commit/tag/Release выполняется отдельно.

## Состав и результат

Runtime остаётся **Pi 1.4.0 / Node 25.8.1 / npm 11.11.0**. Code — **15**, Task — **12** верхнеуровневых пакетов. Polza **0.2.2**, commit `e91b09504f7a445b477eaab77cc02d1db067a1e7`; Memory **1.6.1 patched**, Session Search **1.6.0 patched**, `pi-cbm` **1.2.1** / CBM **0.11.0**. Все pins, installer и профильные templates неизменны: [runtime](../../manifests/runtime.lock.json), [packages](../../manifests/pi-packages.lock.json), [external tools](../../manifests/external-tools.lock.json).

Это адресный repair принятого build.1, не новая общая Pi/ОС/model qualification. Trace и background tasks остаются installed/default-off, MCP Adapter **5.3.2** — единственный MCP owner; remote Context7 и порядок Subagents → Goal X → Intercom сохранены. Модели и настройки Goal X не переопределяются.

## Что исправлено

- **Native Windows без `HOME`:** source, main и worker используют системный home через `node:os.homedir()`, а не относительный буквальный `~`. Настроенные config/env/extra roots сохраняют приоритет; file reference из search/list можно передать в `session_read`. Containment и отказ для traversal/sibling/junction escape сохранены.
- **Недоступные sources:** incremental sync удаляет записи только из успешно перечисленной части дерева. Missing/unreadable root или subtree сохраняет прежние JSON/vectors/FTS и reader state; доступное пустое дерево удаляет действительно исчезнувшие сессии. Missing optional archive не мешает очистке доступного active root.
- **Legacy FTS coverage:** load дополняет отсутствующие session IDs по сохранённой metadata даже при непустом sidecar или равных counts с разным составом. Полный уже существующий текст и JSON/vector bytes не перезаписываются, embedder для этой операции не нужен. Полный отсутствовавший текст нельзя восстановить из stripped metadata.
- **Guarded transitions:** stock, точный root/timer patch и опубликованный display patch распознаются по всем bytes; source и оба bundles входят в один check/apply/backup/restore contract. Current no-op, wrong-mode/mixed/unknown refusal и verified backup сохранены. Multi-file writes не объявляются атомарными.
- **CBM mixed endings:** discriminator сравнивает весь известный current/previous body после только CRLF→LF, включая mixed endings. Произвольные whitespace/semantic edits, bare CR, другая версия или отсутствующий `--format` по-прежнему отвергаются. Current apply не переписывает bytes/mtime и не создаёт backup ради endings; byte-exact stock/restore guard не расширен. Это не новый normalizer или поддержка CBM 0.12+.

Новая cross-process reload-архитектура не добавлена: tools видят собственный sync через тот же `IndexService`. Это работало и в прежнем 1.6.0; мгновенное чтение чужой произвольной JSON-записи не обещается. [Session Search contract](../fixes/session-search.md), [patch](../../patches/session-search-profile/README.md), [CBM](../../patches/pi-cbm-011/README.md).

## Приёмка и происхождение evidence

Платформа свежих native результатов — **Windows 11 x64**, qualified Node **25.8.1**; helper Python **3.14.2** — не новый minimum pin. Числа перекрывающихся проверок не складываются в дополнительную матрицу.

| Группа | Результат / область |
|---|---|
| Session Search source | Независимо **ACCEPTED**: retained final RED/GREEN, **13 tests / 36 native scenario cases**, 15 containment witnesses. Actual handlers main/worker/affected TS, synthetic registry/UI и loopback embeddings; не live SDK/provider proof |
| Partial scan | Fresh independent main/Code, keyword и hybrid: scripted subtree `EACCES` сохраняет недоступную запись, удаляет исчезнувшего здорового соседа, затем допускает обычную очистку после восстановления доступа. Published positive control FAIL; fixed PASS. Native filesystem discriminator — `ENOTDIR`; настоящий ACL-denied не проверен |
| CBM source | Независимо **9/9 PASS**; публичная реконструкция exact mixed-EOL body совпала с reported installed bytes. Check/apply no-op, backup/restore, unknown/version/format refusals; внешние version/help — synthetic doubles, не новый live CBM feature test |
| Рабочее обновление | Preserving Windows update завершён: actual Pi и семь внутренних SDK packages **1.4.0**, Polza **0.2.2** Both. Memory **1.6.1** сохранён без reinstall. Patch Check Both и штатный verifier: **0 failures / 0 warnings** |
| Обычный SDK / CLI | Code из home и project cwd, Task из home: `HOME` отсутствует до import; startup/extension registration и actual native list/read приняты. Сохранены исходные main-model selections, Trace off. **6/6 CLI surfaces exit0** (`--version`, `list`, выбранный `--list-models` Both). Отдельный live main-model answer в этом ремонте **не запускался** |
| Данные | Исходные IDs/vectors, выбранные JSONL, auth/model/Goal X witnesses и non-managed settings сохранены; **4 SQLite integrity checks OK**. Это preservation конкретного исходного состояния, не проверка semantic recall всего архива. Обычный Memory startup отдельно заполнил две ранее отсутствовавшие embeddings; forced/manual reindex и замены старых vectors не было |
| Настоящий semantic route | Query прошёл actual SDK/provider, **HTTP200 / 1024d**. Нужная сессия **не вошла в top25**; исходная проверка остаётся **FAIL**, подробнее ниже. Пустой Task FTS-only проверяет изоляцию, а не semantic качество |
| Неизменённая общая квалификация | [Build.1](pi-1.4.0-build.1.md): exact Pi graph, Polza startup/native synthetic transport, main-model checker controls, Trace policy и Context7 config/live public chain переиспользуются только в прежней применимой области. Новая общая model/OS matrix не запускалась |

Свежие финальные source/docs gates: repository-only verifier Both — **exit0, failures0/warnings0**; существующий relevant patch-composition regression — **exit0, 1 leaf PASS / 0 FAIL**, не повтор полного suite. Syntax: **16 JSON, 15 Python, 46 JS/MJS, 13 TypeScript, 12 Bash, 20 PowerShell**; отдельных YAML-файлов нет, YAML frontmatter проверен в 7 документах, включая 6 instruction headers. Проверены **103 Markdown / 438 relative links / 37 anchor links**, ошибок нет. **Tree safety: 240 files / no findings / exit0**, включая untracked tests; diff/whitespace и ручной просмотр пройдены. Точные команды/exits и final path/hash set передаются выпускающему отдельно; staged/commit/archive/remote проверки выполняются на фактическом release commit, не подменяются старым отчётом.

## Известное ограничение смыслового поиска

**Доступный индекс и читаемая сессия не гарантируют результат широкого тематического query.** В контрольном реальном запросе нужная сессия осталась вне top25, хотя source, FTS и vectors доступны. Без `project` поиск межпроектный **внутри выбранного индекса**, с явным `project` выборка сужается; профиль или `localPath` может выбирать другое хранилище. Это различие scope, а не обещание recall.

Offline replay настоящего search на сохранённом query vector воспроизвёл miss: target имеет **cosine rank39**, а при active RRF — **rank95 в pool125**. Поэтому его нет в top25 даже без fusion. Один отдельно проверенный embedding **точного нынешнего document payload** через тот же configured provider/model дал **cosine rank33**, также вне top25. Сохранённый и свежий vectors **не идентичны**: cosine между ними **0.9957823913**. Старый index v3 не хранит исторический model/payload provenance; точное происхождение небольшого численного расхождения не установлено. Свежий vector в индекс не записывался.

Новый implementation defect этим разбором не доказан. Исходный FAIL сохранён как известное ограничение текущих **model + representation + ranking**, а не переименован в PASS по факту HTTP200, list/read или сохранности. Два адресных примера не дают оценки точности всего архива. Patch не обещает улучшить recall/ранжирование; query/model/fusion не подбирались ради успеха, vectors не заменялись. Отсутствие результата не означает отсутствия разговора; чтение по известному ID не заменяет semantic search.

Это ограничение не требует держать уже проверенные Code/Task выключенными, откатывать принятую установку или запускать массовый платный reindex. Дальнейшее изменение representation/ranking/model — отдельная задача с собственным критерием, не скрытая часть этого patch.

## Установка и обновление

Основной маршрут — **[INSTALL_FOR_AGENTS.md](../../INSTALL_FOR_AGENTS.md)**: выбрать опубликованный SHA → prerequisites → preserving PLAN/Apply → Code/Task → локальные credentials → короткая приёмка. Для отдельного checkout после публикации:

```sh
git clone --branch pi-v1.4.0-build.2 https://github.com/VladimirMonin/pi-agent-build.git "<REPO_ROOT>"
```

При уже установленных exact pins не переустанавливайте всё ради исправления paths/endings. Сначала проверьте известное исходное состояние и выполните только нужный preserving tail по [workflow](../pi-upgrade-workflow.md#рабочая-установка-короткое-продолжение-не-повтор-installer). До runtime replacement освободите фактических writers и сохраните проверенный private recovery. Если эта установка и проверки уже завершены, повторять их или останавливать новые пользовательские Pi ради публикации не нужно.

Session Search: Code использует `--runtime-only`, Task — без него; `--check` должен подтвердить canonical patched. CBM current mixed-EOL — ожидаемый no-op. После собственного package/patch update полностью перезапустите Pi. **Не выполняйте forced `/session-reindex`**, не меняйте модель/размерность/индекс ради этого repair. Если старый writer уже потерял vectors, patch их не создаст из ничего: нужен verified непустой recovery, не слепой reindex. [Данные и restore](../state-migration.md), [подробная установка](../setup.md).

## Поставка и границы

GitHub Release поставляет **`pi-agent-build-1.4.0-build.2-source.zip`** через прежний `git archive` от точного принятого release commit и **`SHA256SUMS.txt`**. Это исходники/templates/patches/tests, **не offline runtime**, не `node_modules`, личные profiles/credentials/indexes/sessions или raw receipts. Exact top-level pins не означают bit-for-bit transitive reproducibility. Старый tag/Release build.1 не перемещается и его notes не переписываются; npm/PyPI publication не входит в выпуск.

Новые native macOS/Linux, visual TUI/browser, полная live main-model/embedding/consolidation matrix, настоящий ACL-denied и OS containment **не заявляются**. Git Bash checks относятся к Windows shell/source contract. Прежние Trace/Context7/Polza/прочие результаты сохраняют исходную версию, платформу и synthetic/live scope. У Trace по-прежнему нет автоматической rotation/retention.
