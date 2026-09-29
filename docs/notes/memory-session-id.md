# Идентификатор сессии в консолидации памяти

## Наблюдение

Консолидированные записи в `memory.db` получали источник `session:unknown` вместо реального id сессии. Заметно по таблице `lessons`: колонка `source` содержала `session:unknown` для всех записей, созданных консолидацией.

```
lessons: rule=... | source=session:unknown | project=voiceover-pipeline
```

## Причина

Stock `@samfp/pi-memory 1.5.0` берёт id сессии так:

```js
sessionId = ctx.sessionId ?? ctx.session?.id;
```

Но `ExtensionContext` не содержит ни поля `sessionId`, ни `session` — только read-only `sessionManager` (см. `@earendil-works/pi-coding-agent`, `dist/core/extensions/types.d.ts`). Оба обращения к `ctx.*` дают `undefined`, поэтому выражение всегда разрешается в `undefined`, а метка источника становится `session:unknown`.

Проверено на живом ExtensionRunner: `Object.keys(ctx)` не содержит `sessionId`/`session`, а `ctx.sessionManager.getSessionId()` возвращает реальный id.

## Область влияния

- **Факты** (`semantic`) не затронуты: их `source` жёстко равен `consolidation` в коде, id сессии туда не попадает.
- **Lessons** затронуты: `source = session:<id>`, поэтому все записи помечались `session:unknown`.

На поиск, инъекцию и порог это не влияет — страдает только прослеживаемость происхождения записи.

## Исправление

Patch `memory-windows-runtime` переписывает присваивание:

```js
sessionId = ctx.sessionManager?.getSessionId?.() ?? ctx.sessionId ?? ctx.session?.id;
```

Прежние fallback'и сохранены — если session manager недоступен, поведение остаётся безопасным. Проверено end-to-end: новая консолидация записывает `source = session:<реальный id>`.

Процедура применения, тесты и откат: [memory fix](../fixes/memory.md). Структурный тест — `patches/memory-windows-runtime/tests/test-memory-sessionid.mjs`.

## Оговорка

Записи, созданные до применения patch, сохраняют исторический `session:unknown` — patch не переписывает существующие строки в БД. Новые консолидации после patch получают корректный id.
