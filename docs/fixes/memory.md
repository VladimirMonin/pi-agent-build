# Memory: профильные settings, Windows spawn и порядок реплик

## Назначение

Patch `memory-windows-runtime` поддерживает `@samfp/pi-memory 1.5.0`:

- заменяет жёсткий `~/.pi/agent/settings.json` на `<PI_CODING_AGENT_DIR>/settings.json`, чтобы Task использовал свой блок `memory`/`pi-memory`;
- на Windows заменяет запуск npm `.cmd` через `spawn(shell:false)` на прямой запуск Pi CLI текущим Node, устраняя `ENOENT`;
- хранит ordered `pendingTurns` в session-local lexical scope и строит пары User/Assistant по реальному порядку, а не по двум рассинхронизированным массивам;
- исправляет старую ошибочную patch-версию, где `pushTurn` оказался module-scope и падал на `agent_end` с `pending*Messages is not defined`.

## Применение

У этого patcher нет `--apply`: отсутствие `--check`/`--restore` означает apply.

```bash
python patches/memory-windows-runtime/apply.py \
  --agent-dir "<PROFILE_DIR>" --check
python patches/memory-windows-runtime/apply.py \
  --agent-dir "<PROFILE_DIR>"
```

Примените к обоим профилям. Patcher пересобирает canonical output из vendored pristine `1.5.0`, принимает для записи только byte-exact stock или byte-exact previous canonical patch и не перезаписывает marker-shaped/unknown/custom build. Для неизвестного состояния сначала выполните штатный reinstall пакета.

## Конфигурация и данные

Patch меняет `dist/index.js`; memory DB и сами settings не преобразует. При заданном `PI_CODING_AGENT_DIR` user-global config читается из `settings.json` активного профиля, без переменной сохраняется stock fallback `~/.pi/agent/settings.json`. На Windows путь к global Pi CLI строится от `PI_AGENT_BUILD_NPM_PREFIX`, который задают rendered launchers; fallback — `%APPDATA%\npm`. Служебный child по-прежнему запускается с `--no-extensions --no-tools --no-session`; static `polza-memory` описан отдельно.

## Tools/команды

Интерфейс package не меняется: `memory_*` и `/memory-consolidate`. Patch касается lifecycle/consolidation internals.

## Риски

Любой reinstall package стирает правку. `node --check` недостаточен: module-scope bug синтаксически валиден. Runtime test вызывает модель и может стоить денег. Полный consolidation prompt передаётся child Pi через аргумент `-p` и виден в process command line локальным наблюдателям. Restore возвращает stock с Windows-дефектом и общей привязкой settings к Code.

## Проверка

```bash
python patches/memory-windows-runtime/apply.py \
  --agent-dir "<PROFILE_DIR>" --check
```

Ожидается `verdict: RUNTIME-SAFE`; этот verdict также требует marker profile-aware settings.

Структурная проверка для произвольного профиля:

```bash
node patches/memory-windows-runtime/tests/test-memory-pushturn.mjs \
  "<PROFILE_DIR>/npm/node_modules/@samfp/pi-memory/dist/index.js"
```

Реальный ExtensionRunner smoke (платный/model-dependent):

```bash
node patches/memory-windows-runtime/tests/test-memory-runtime-scope.mjs code
node patches/memory-windows-runtime/tests/test-memory-runtime-scope.mjs task
```

Дополнительно выполните `memory_stats` и осознанный `/memory-consolidate`; отсутствие visible error само по себе не доказывает запись.

## Удаление/откат

```bash
python patches/memory-windows-runtime/apply.py \
  --agent-dir "<PROFILE_DIR>" --restore
```

Restore пишет vendored pristine `1.5.0`. После package update сначала `--check`: новый version/layout требует нового аудита, а не принудительного применения старого patch.
