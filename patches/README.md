# Патчи сборки — карта наших изменений против upstream

Карта **всех локальных патчей**: что каждый меняет в чужом коде, от какого upstream-базиса считается диф, где рунбук и как проверить/откатить. Задумано для **обновлений плагинов** — чтобы при обновлении upstream контролировать, что из наших фиксов переносить, а что снимать.

Upstream-базис каждого патча (точный npm-тарболл, `gitHead`, SHA-256 pristine-копий) — в его `NOTICE.md`; хеши здесь не дублируются, чтобы не расходиться с NOTICE. Побайтовые копии исходников upstream лежат в `store/` внутри патча — это точка отсчёта дифа и эталон отката.

## Как это контролирует обновления

- **Guard не даёт молча применить патч к чужой новой версии.** Каждый `apply.py` сверяет stock-хеш/версию: новая upstream-версия → `unknown` и отказ (`--check` exit 2), а не тихая запись.
- **`--check` / `--restore`:** `0` — canonical (наш патч применён), `1` — stock/previous (нужен патч), `2` — unknown / новая версия / mixed / fatal. `--restore` возвращает побайтовый stock, но **не откатывает данные** (SQLite, настройки, индекс поиска).
- **Порядок при обновлении** — [PATCH.Maintenance](../instructions/PATCH.maintenance.instructions.md): сверить, задеты ли наши зоны изменениями upstream, и решить — перенести / снять / подождать. Готовые решения по прошлым обновлениям — [recon 2026-11-11](../docs/recon/2026-11-11-plugins.md).
- **Reinstall стирает патч** — после переустановки пакета примените патч заново и перезапустите Pi.

## Карта патчей

| Патч | Плагин (target) | Что меняет | Check / Restore | Рунбук | Статус |
|---|---|---|---|---|---|
| [`memory-windows-runtime`](memory-windows-runtime/) | `@samfp/pi-memory` 1.6.1 | запуск child на Windows (настоящий `cli.js`, не `.cmd`-шим), пары user/assistant для консолидации с бюджетами, scope фактов/уроков, vector recall (`searchMemory` вместо stock FTS), query-префикс Qwen, сброс lifecycle-блока | `apply.py --agent-dir <PROFILE> --check` / `--restore` | [fixes/memory](../docs/fixes/memory.md), [memory-injection](../docs/fixes/memory-injection.md) | активен |
| [`session-search-profile`](session-search-profile/) | `pi-session-search` 1.6.1 | Windows-пути без `HOME`, профильные пути Task, реальный `cwd`, строгие `modelPrefixes`, `fusion: "semantic-only"`, недеструктивный partial-scan, достройка legacy FTS IDs | `apply.py --agent-dir <PROFILE> --check` / `--restore` (для Code — `--runtime-only`) | [fixes/session-search](../docs/fixes/session-search.md) | активен (перенесён на 1.6.1) |
| [`serena-tools`](serena-tools/) | `@bacnh85/pi-serena` 0.10.1 | скрытие 2 нерабочих инструментов + правка `SERENA_FIRST_GUIDANCE` (остаётся 18 tools) | `apply.py --agent-dir <PROFILE> --check` / `--restore` | [fixes/serena](../docs/fixes/serena.md) | активен |
| [`ast-grep-windows`](ast-grep-windows/) | `@nicknisi/pi-ast-grep` 0.3.4 | стейджинг настоящего `ast-grep.exe` вместо npm `.cmd`-шимов (ENOENT/EINVAL при `shell:false`) | `stage-exe.ps1 -Mode Check` / `-Mode Restore` | [fixes/ast-grep-windows](../docs/fixes/ast-grep-windows.md) | активен |
| [`trace-ru-windows-profile`](trace-ru-windows-profile/) | `pi-trace-extension` 0.1.16 | русский интерфейс viewer/dashboard, UTF-8 stdout/stderr Python-рендера на Windows, каталог traces под `PI_CODING_AGENT_DIR` | `apply.py --agent-dir <PROFILE> --check` / `--restore` | [fixes/trace](../docs/fixes/trace.md) | активен |
| [`pi-cbm-011`](pi-cbm-011/) | `pi-cbm` 1.2.1 | адаптер графа кода под `codebase-memory-mcp` 0.11 (compact tables → legacy shape) | `apply.py --check` / `--restore` | [fixes/cbm](../docs/fixes/cbm.md) | **снят 2026-11-11** (влит в `pi-cbm` 2.0.0; хранится для отката) |

Патчей для `pi-subagents`, `pi-goal-x`, `pi-intercom`, `pi-mcp-adapter` и провайдеров **нет** — эти пакеты используются как есть.

## Если обновили плагин

1. `python patches/<патч>/apply.py --agent-dir <PROFILE> --check` → если `2` (unknown/новая версия), патч к новой версии **не применять**.
2. Сверить зоны наших замен с изменениями upstream — [PATCH.Maintenance](../instructions/PATCH.maintenance.instructions.md).
3. Решить: **перенести** патч на новую версию (новый stock-хеш + пере-разрешённые anchors), **снять** (если влит апстримом, как `pi-cbm-011`), или **подождать**. Примеры таких решений — [recon 2026-11-11](../docs/recon/2026-11-11-plugins.md).
4. После переустановки пакета — применить патч заново и перезапустить Pi.

Откат данных (SQLite памяти, индекс поиска, настройки) — отдельно от `--restore`: restore возвращает только код.
