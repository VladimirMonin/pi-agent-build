---
applyTo: "**"
name: "DOCS.CommitMessages"
description: "Читай при подготовке staging, проверок, commit, tag и публикации: смысловые границы, Conventional Commits, запрет секретов и release-tag по версии Pi."
---

# DOCS — Коммиты и теги

## Принцип

Один commit — один проверяемый смысл. История должна позволять понять, когда появился manifest, конкретный patch, skill или документ, и при необходимости откатить их независимо.

## Сообщения

Используй Conventional Commits на английском в заголовке:

```text
chore: initialize portable Pi build repository
feat(manifest): capture Pi 0.87.0 package set
feat(memory): add Polza embeddings configuration
fix(trace): preserve Russian UI and Windows UTF-8
fix(cbm): adapt pi-cbm to CBM 0.11 schema
feat(skill): add Pi memory operations skill
docs(plugins): document installed extensions
```

Заголовок — повелительный, без точки, обычно до 72 символов. Подробности и причины — в body при необходимости.

## Перед staging

1. Прочитай diff каждого файла.
2. Убедись, что изменение соответствует текущему логическому срезу.
3. Не добавляй runtime data, чужие несвязанные изменения и generated cache.
4. Запусти `scripts/safety-check.ps1` и релевантные тесты.
5. Проверь, что инструкция обновлена, если изменился устойчивый workflow.

Не используй без разбора `git add .`. Добавляй точные пути или заранее проверенный набор.

## Перед commit

```text
git diff --check
git diff --cached --stat
git diff --cached
```

Проверки должны соответствовать содержанию commit. Документационный commit как минимум проверяет links/frontmatter/safety; patch commit — дополнительно check/apply/test/restore contract.

## Теги совместимости

Формат:

```text
pi-v<версия Pi>-build.<номер>
```

Тег ставится только на последнем проверенном commit выпуска, после общего verifier и чистого `git status`. Он означает совместимость сборки с указанной версией Pi, а не версию отдельных плагинов.

Перед тегом:

1. проверить runtime manifest;
2. проверить оба профиля;
3. проверить public safety scan;
4. проверить patch states и документацию;
5. проверить отсутствие незакоммиченных файлов;
6. создать аннотированный тег с кратким перечнем состава.

Push commit/tag и создание публичного GitHub-репозитория выполняются только по явному разрешению владельца.
