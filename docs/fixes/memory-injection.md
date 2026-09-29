# Pi-memory 1.5.0: границы проектов и обрезание памяти

**Статус:** для закреплённого `@samfp/pi-memory@1.5.0` обобщённое исправление встроено в единый [version-guarded patcher](../../patches/memory-windows-runtime/apply.py). Это локальный patch сборки, **не исправление upstream**; новая версия плагина требует отдельной проверки. Публичный навык содержит [процедуру диагностики](../../skills/memory-ops/instructions/10-tags-budget.md).

## Наблюдение и причины

- `projectSlug(cwd)` делит путь только по `/`. Windows cwd с `\` даёт слагом весь путь. Первичный фильтр фактов `project.<slug>.*` не принимает обычную короткую бирку, хотя уроки с полным Windows-путём совпадают с таким cwd.
- После фильтра поисковые попадания через embeddings добавляются без повторной проверки проекта; затем соседние факты домена также добавляются без неё. В результате чужие `project.*` факты попадают в неродственный проект.
- `lessonInjection: "selective"` ищет уроки по тексту запроса, не оставляя гарантированного минимума уроков текущего рабочего каталога. Обычный запрос к одной рабочей ветке может получить **ноль её уроков**.
- Блок ограничен 8000 символами. Исходный код режет строку на границе символов, а не записей: часть факта или правила исчезает посреди предложения.

Форматер выводит ключ **без первого сегмента** (`project.alpha.rule` → `alpha.rule`). Для доказательства утечки нельзя судить по отображаемому префиксу; нужно сверять сырые выбранные ключи. Структурный `skills/memory-ops/scripts/inject-probe.mjs` не исполняет plugin и поэтому сам по себе не проверяет фактическое содержимое блока.

## Патч сборки и перенос локальных привязок

`injection.py` преобразует только сверенный pristine 1.5.0 в **один canonical bundle**: все пути добавления фактов (текстовый поиск, embedding hits и соседи) проверяются одним scope; несколько местных уроков выбираются первыми; бюджет 8000 символов наполняется только **целыми строками**. Если записей больше, часть пропускается: полнота всех релевантных записей не гарантируется. База памяти не изменяется patcher’ом.

Для нестандартных корней и worktree используйте **только приватный** `settings.json` выбранного профиля:

```json
{"memory":{"factProjectAliases":[
  {"path":"<ABSOLUTE_PROJECT_ROOT>","scope":"alpha"},
  {"path":"<ABSOLUTE_WORKTREE_PARENT>","scope":"alpha","includeChildren":true}
]}}
```

`path` сравнивается без учёта регистра и различия `/`/`\\`; без `includeChildren` правило действует только для точного каталога. `scope` — короткий второй сегмент ключа `project.<scope>.*`. Alias читаются **только из настроек профиля**, project-local `.pi/settings.json` не может их переопределить. При отсутствии alias применяется нормализованное имя последней папки. Личные пути, пользовательскую БД и старый локальный bundle **не публикуйте**.

Проверенный локальный injector v1 принимается для разовой миграции **только по точному SHA-256** и только при наличии приватного списка alias; patcher делает backup до записи. Неизвестное состояние остаётся `UNKNOWN` с запретом перезаписи; installer проверяет его **до** `pi install`. Тесты на синтетическом store покрывают Windows/forward-slash cwd, FTS, embedding hits, соседей, местные уроки, отсутствие запроса и целые записи. При смене версии upstream остановитесь и сверяйте исходник заново.

## Сообщение автору плагина

Разделитель Windows-путей уже описан в [#32](https://github.com/samfoy/pi-memory/issues/32), обрезание блока — в [#33](https://github.com/samfoy/pi-memory/issues/33). Закрытый [#19](https://github.com/samfoy/pi-memory/issues/19) сообщил об утечке памяти между проектами; его исправление отфильтровало FTS, но обнаруженный путь через embeddings остался. Не создавай дублирующих issues. Для новой утечки используй синтетические ключи/значения, без путей машины, БД, содержимого уроков и сессий:

> **Title:** Project fact scope filter is bypassed by embedding hits and domain expansion
>
> **Version:** `@samfp/pi-memory@1.5.0`.
> **Expected:** when the current project is `alpha`, no `project.beta.*` fact is injected.
> **Actual:** `buildSelectiveBlock` filters FTS results by `parts[1] === slug`, but appends embedding hits and domain siblings *after* that filter without the same check. An embedding hit for `project.beta.one` can bring in `project.beta.two` as well.
> **Suggested fix:** enforce project scope for every candidate before adding it, including embeddings and sibling expansion. Add a synthetic regression test for a nonmatching project.

`selective` может отдельно не выбрать ни одного местного урока; если сообщать об этом автору, нужен собственный минимальный тест. Не утверждай, что upstream уже исправил это, пока не проверены новая версия и тесты.
