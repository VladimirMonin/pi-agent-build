# Trace: русский UI, Windows UTF-8 и профильные пути

В текущей сборке Trace **installed/default-off** в Code/Task. [Проверенный opt-in/off](../trace.md) использует однократный `pi -e` без правки filters; сам patch не включает extension. Pi1.0.2 SDK/CLI mock подтверждает JSONL/HTML и natural shutdown; browser UI отдельно NT.

## Назначение

Patch `trace-ru-windows-profile` поддерживает только `pi-trace-extension 0.1.16` и исправляет три независимые проблемы:

1. Trace hardcodes `~/.pi/agent/traces`, поэтому Task смешивает данные с Code;
2. Python renderer печатает `✓`, а Windows console в cp1251/cp866 может завершить уже успешный render с `UnicodeEncodeError`;
3. viewer/dashboard поставляются с не-русским UI.

Patch использует `PI_CODING_AGENT_DIR`, reconfigure stdout/stderr в UTF-8, заменяет пользовательские literals и пересобирает `viewer/assets.json`.

## Применение

```bash
python patches/trace-ru-windows-profile/apply.py \
  --agent-dir "<PROFILE_DIR>" --check
python patches/trace-ru-windows-profile/apply.py \
  --agent-dir "<PROFILE_DIR>" --apply
```

Примените отдельно к Code и Task. Patcher проверяет exact version и SHA-256 известных stock/patched/transitional файлов, создаёт runtime backup под `<PROFILE_DIR>/.pi-agent-build-backups/` и отказывается от unknown state.

## Конфигурация и данные

- output: `<PROFILE_DIR>/traces/`;
- Python override: `PI_TRACE_PYTHON`;
- patch payload меняет installed package, но backup хранится вне Git;
- после любого package update patch может исчезнуть.

## Команды

`/trace`, `/trace all`; отдельного `/trace-dashboard` нет. Shell renderer может запускаться напрямую из установленного package, но profile env должен быть тем же.

## Риски

Patch заменяет шесть source files и rebuild artifact; неизвестный upstream layout блокируется. Trace остаётся privacy-sensitive и без retention. Русификация не является redaction.

## Проверка

```bash
python patches/trace-ru-windows-profile/apply.py \
  --agent-dir "<PROFILE_DIR>" --check
```

Ожидается `ALREADY PATCHED`. После `/reload` выполните `/trace` и `/trace all`; HTML должен открыться без `trace render failed`, быть русским и оказаться в каталоге текущего профиля. Для Windows-bug проверяйте процесс без маскирующих `PYTHONUTF8`/`PYTHONIOENCODING`, если воспроизводите upstream defect.

## Удаление/откат

```bash
python patches/trace-ru-windows-profile/apply.py \
  --agent-dir "<PROFILE_DIR>" --restore
```

Restore берёт последний checksum-verified runtime backup. Затем `/reload`. Для полного удаления package используйте `pi remove npm:pi-trace-extension`; traces остаются до отдельного удаления.
