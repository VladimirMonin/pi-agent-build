# ast-grep на Windows: настоящий EXE для `shell:false`

Целевая версия: `@ast-grep/cli@0.45.3`.

Глобальная npm-установка создаёт shell wrappers `ast-grep`, `ast-grep.cmd` и `ast-grep.ps1`. Расширение Pi запускает команду без shell, поэтому wrapper, работающий в терминале, может дать `ENOENT`/`EINVAL` внутри Pi.

Настоящий бинарник находится здесь:

```text
<NPM_PREFIX>/node_modules/@ast-grep/cli/ast-grep.exe
```

Сценарий копирует его в `<NPM_PREFIX>/ast-grep.exe`, который уже находится в Windows `PATH`.

## Использование

```powershell
.\patches\ast-grep-windows\stage-exe.ps1 -Mode Check
.\patches\ast-grep-windows\stage-exe.ps1 -Mode Apply
```

Проверка должна вернуть версию и `ALREADY STAGED`.

Откат:

```powershell
.\patches\ast-grep-windows\stage-exe.ps1 -Mode Restore
```

Runtime-backup и manifest хранятся под `%LOCALAPPDATA%\pi-agent-build\backups`, а не в Git.

После обновления `@ast-grep/cli` staged EXE автоматически не меняется: повтори `Check`/`Apply` и direct spawn test. Не размещай бинарник в `~/.pi/agent/bin`: этот каталог не обязан находиться в системном `PATH`.
