---
applyTo: "patches/**,scripts/apply-patches.ps1,manifests/pi-packages.lock.json,docs/fixes/**"
name: "PATCH.Maintenance"
description: "Читай при создании, обновлении, применении, проверке или откате локальных исправлений установленных Pi-пакетов и Windows executable staging."
---

# PATCH — Сопровождение локальных исправлений

## Принцип

Установленный `node_modules` — изменяемый runtime, а не источник истины. Источником истины является каталог `patches/<имя>/` с причиной, жёсткой областью совместимости, fail-closed patcher и проверкой поведения.

## Обязательный контракт patch-каталога

Каждый patch содержит:

1. `README.md`: дефект, причина, целевые версии, применение, проверка, откат, ограничения;
2. patcher или воспроизводимый diff;
3. точную проверку версии и исходной структуры/hashes;
4. режим `check` без записи;
5. идемпотентный apply;
6. byte-exact restore либо runtime-backup с checksum manifest;
7. проверку реального дефекта, а не только marker;
8. отказ на неизвестной версии или смешанном состоянии.

## Записи и backups

- Patcher не пишет backups, manifests и временные файлы внутрь Git tree.
- Runtime-backup хранится под выбранным `PI_CODING_AGENT_DIR/.pi-agent-build-backups/<patch>/` либо в явном локальном state-dir.
- В вывод не попадают credentials и содержимое пользовательских данных.
- Проверка не делает модельных вызовов, если это не отдельный явно включённый live-mode.

## После package update

1. **До package replacement** распознать установленное исходное состояние по версии и достоверным hashes/равноценным preconditions; сохранить нужный backup. Проверка только целевой версии не годится для распознавания известной прежней.
2. Отдельно проверить целевой package и его поддержанную версию; убедиться, что upstream ещё требует исправления.
3. Выполнить явно поддержанный переход из конкретного опубликованного прежнего состояния в новый canonical patch. Не принимать все старые версии по диапазону и не считать marker доказательством неизменности bundle.
4. Unknown/mixed/private edits — отказ **до перезаписи**, с причиной и путём восстановления. Сохранить ручную правку и сопоставить поведение; не объявлять её stock и не отключать guards.
5. Для изменения patch синхронизировать исполняемые bundles/worker, hashes, check/apply/backup/restore, README/manifest и affected tests. Изменённый TypeScript при старом dist не завершает repair.
6. Проверить fresh install, known previous transition, current no-op и unknown refusal. После исправления повторить затронутую runtime-границу; полный suite — на согласованном выпуске либо при общем impact.

Не называй переход атомарным без восстановления частичного сбоя. Продолжай только наблюдаемый незавершённый остаток, не полный installer заново. При сохранённых неизменённых inputs повтор старых checks не требуется только из-за новой даты.

Нельзя расширять version guard по предположению «скорее всего совместимо». Если upstream уже исправил дефект, подтвердить это reproduction/contract test и явно изменить нужность patch, а не оставить marker-based обход.

Reuse предыдущих checks допустим только при unchanged существенных source/fixture/dependency/API/platform inputs; changed installed bundle проходит fresh checks. Source review/компиляция не дают runtime approval. Promotion private helper в public tests сохраняет настоящие ownership/error/cleanup assertions и не переносит compiled DLL/raw receipts. Общий [lab workflow](BUILD.lab_upgrade.instructions.md) определяет допуск исполнения.

## Приёмка

Patch принимается, когда:

- Python/Node/PowerShell синтаксис валиден;
- check корректно различает stock/patched/unknown;
- apply/check/restore пройдены на изолированной копии;
- повторный apply идемпотентен;
- runtime-test воспроизводит исходный класс дефекта;
- safety scan не находит личных путей, секретов или живых данных.
