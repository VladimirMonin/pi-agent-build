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

1. Запустить check до применения старого patch.
2. Проверить реальную установленную версию.
3. Если версия новая — остановиться и выяснить, существует ли дефект upstream.
4. Повторить reproduction/smoke-test на чистой копии.
5. Только затем обновить patch, hashes, README, manifest и тесты.
6. Применить к нужным профилям и проверить runtime.

Нельзя расширять version guard по предположению «скорее всего совместимо».

## Приёмка

Patch принимается, когда:

- Python/Node/PowerShell синтаксис валиден;
- check корректно различает stock/patched/unknown;
- apply/check/restore пройдены на изолированной копии;
- повторный apply идемпотентен;
- runtime-test воспроизводит исходный класс дефекта;
- safety scan не находит личных путей, секретов или живых данных.
