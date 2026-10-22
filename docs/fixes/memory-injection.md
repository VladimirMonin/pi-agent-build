# Memory 1.6: границы проектов и целые записи

**Статус:** локальный patch сборки для exact Memory из [manifest](../../manifests/pi-packages.lock.json) (текущий target `1.6.1`); [контракт patcher-а](../../patches/memory-windows-runtime/README.md). Это **не исправление upstream**. Исторические причины ниже сохраняются на своих версиях; новая версия требует проверки затронутого контракта. Публичный навык содержит [процедуру диагностики](../../skills/memory-ops/instructions/10-tags-budget.md).

## Наблюдение и причины

- `projectSlug(cwd)` делит путь только по `/`. Windows cwd с `\` даёт слагом весь путь. Первичный фильтр фактов `project.<slug>.*` не принимает обычную короткую бирку, хотя уроки с полным Windows-путём совпадают с таким cwd.
- После фильтра поисковые попадания через embeddings добавляются без повторной проверки проекта; затем соседние факты домена также добавляются без неё. В результате чужие `project.*` факты попадают в неродственный проект.
- `lessonInjection: "selective"` ищет уроки по тексту запроса, не оставляя гарантированного минимума уроков текущего рабочего каталога. Обычный запрос к одной рабочей ветке может получить **ноль её уроков**.
- Блок ограничен 8000 символами. Исходный код режет строку на границе символов, а не записей: часть факта или правила исчезает посреди предложения.

Форматер выводит ключ **без первого сегмента** (`project.alpha.rule` → `alpha.rule`). Для доказательства утечки нельзя судить по отображаемому префиксу; нужно сверять сырые выбранные ключи. Структурный `skills/memory-ops/scripts/inject-probe.mjs` не исполняет plugin и поэтому сам по себе не проверяет фактическое содержимое блока.

## Патч сборки и перенос локальных привязок

`injection.py` строит **один canonical bundle** из сверенного pristine target: все пути добавления фактов (текстовый поиск, embedding hits и соседи) проверяются одним scope; несколько местных уроков выбираются первыми; бюджет 8000 символов наполняется только **целыми строками**. Если записей больше, часть пропускается: полнота всех релевантных записей не гарантируется. База памяти не изменяется patcher’ом.

Тот же `projectFactScope()` теперь определяет recall, `memory_remember`, применение consolidation и допустимый префикс в её prompt. Запись `project.<current-scope>.<fact>` проверяется точно: дефис/подчёркивание не объединяются, чужой scope получает отказ с ожидаемым префиксом. Глобальные `pref.*`, `user.*`, `tool.*` сохраняют свою область. Факт о другом проекте нельзя молча записывать в текущий; старые записи БД не переименовываются массово.

Для нестандартных корней и worktree используйте **только приватный** `settings.json` выбранного профиля:

```json
{"memory":{"factProjectAliases":[
  {"path":"<ABSOLUTE_PROJECT_ROOT>","scope":"alpha"},
  {"path":"<ABSOLUTE_WORKTREE_PARENT>","scope":"alpha","includeChildren":true}
]}}
```

`path` сравнивается без учёта регистра и различия `/`/`\\`; без `includeChildren` правило действует только для точного каталога. `scope` — короткий второй сегмент ключа `project.<scope>.*`. Alias читаются **только из настроек профиля**, project-local `.pi/settings.json` не может их переопределить. При отсутствии alias применяется нормализованное имя последней папки. Личные пути, пользовательскую БД и старый локальный bundle **не публикуйте**.

Прежний local injector v1 принимался исторической процедурой только по exact hash и с private aliases, не по marker. Для текущего перехода действует [набор распознаваемых состояний](../../patches/memory-windows-runtime/README.md): installer проверяет и сохраняет known bundle **до** `pi install`; unknown не перезаписывается. Alias не делает произвольный локальный bundle известным. Новая automatic consolidation проверяется новым synthetic фактом без `memory_remember`: запись/source/scope, включение в подходящую сессию и исключение из чужой. Исполнение и область такого case называются отдельно, не предполагаются из текста инструкции.

## Сообщение автору плагина

Разделитель Windows-путей уже описан в [#32](https://github.com/samfoy/pi-memory/issues/32), обрезание блока — в [#33](https://github.com/samfoy/pi-memory/issues/33). Закрытый [#19](https://github.com/samfoy/pi-memory/issues/19) сообщил об утечке памяти между проектами; его исправление отфильтровало FTS, но обнаруженный путь через embeddings остался. Не создавай дублирующих issues. Для новой утечки используй синтетические ключи/значения, без путей машины, БД, содержимого уроков и сессий:

> **Title:** Project fact scope filter is bypassed by embedding hits and domain expansion
>
> **Historical report version:** `@samfp/pi-memory@1.5.0`; current build patch target `1.6.1`.
> **Expected:** when the current project is `alpha`, no `project.beta.*` fact is injected.
> **Actual:** `buildSelectiveBlock` filters FTS results by `parts[1] === slug`, but appends embedding hits and domain siblings *after* that filter without the same check. An embedding hit for `project.beta.one` can bring in `project.beta.two` as well.
> **Suggested fix:** enforce project scope for every candidate before adding it, including embeddings and sibling expansion. Add a synthetic regression test for a nonmatching project.

`selective` может отдельно не выбрать ни одного местного урока; если сообщать об этом автору, нужен собственный минимальный тест. Не утверждай, что upstream уже исправил это, пока не проверены новая версия и тесты.
