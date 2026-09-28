# ast-grep на Windows: real executable

## Назначение

`@nicknisi/pi-ast-grep 0.2.0` запускает `ast-grep` через Pi `exec`/Node `spawn` с `shell:false`. Глобальный npm install на Windows создаёт shell wrappers `ast-grep`, `ast-grep.cmd`, `ast-grep.ps1`; PATH достаточно для Git Bash, но не для такого spawn. Типичные результаты — `ENOENT` для shim без расширения или `EINVAL` для `.cmd`.

Реальный binary находится внутри `@ast-grep/cli 0.45.3`. Fix копирует его в npm prefix как `ast-grep.exe`, который уже находится на PATH.

## Установка

```bash
npm install -g @ast-grep/cli@0.45.3
npm_prefix="$(npm prefix -g | tr '\\' '/')"
cp "$npm_prefix/node_modules/@ast-grep/cli/ast-grep.exe" \
   "$npm_prefix/ast-grep.exe"
```

`~/.pi/agent/bin/` не используйте: Pi может хранить там `fd.exe`, но этот каталог не гарантирован в системном PATH.

## Конфигурация и данные

Config не нужен. Копия binary не содержит user data. После update `@ast-grep/cli` staged copy может остаться старой — повторите копирование и version check.

## Tools/команды

Fix обслуживает `ast_search` и `ast_rewrite`; самостоятельных Pi commands/skills нет.

## Риски

Копирование поверх существующего `ast-grep.exe` может затронуть другую установку. Сначала сравните `--version` и источник. Binary исполняет structural rewrites с правами пользователя; fix не добавляет sandbox/rollback.

## Проверка

Shell-check:

```bash
ast-grep.exe --version
```

Host-like check должен использовать plain Node `spawn('ast-grep.exe',['--version'],{shell:false})`, а не Bash resolution. Затем в Pi выполните read-only `ast_search`; preview `ast_rewrite` оставьте с default `dryRun:true`.

## Удаление/откат

Удалите только staged `<npm-prefix>/ast-grep.exe`, затем при необходимости:

```bash
npm uninstall -g @ast-grep/cli
```

Удаление CLI не удаляет wrapper package автоматически. Если wrapper остаётся активным, tools будут выдавать executable unavailable.
