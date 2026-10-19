# Pi 1.3.0 build.1 — согласованное ядро, память и координация

Дата: 2026-10-19. Тег: `pi-v1.3.0-build.1`. Предыдущий выпуск: [Pi 1.0.4 build.6](pi-1.0.4-build.6.md).

## Состав

Runtime manifest: **Node 25.8.1 / npm 11.11.0 / Pi 1.3.0**. Реальные семь внутренних Pi family nodes и их declarations — exact 1.3.0; chord отсутствует. Проверенный отдельно Windows helper — **Python 3.14.2**, без обновления Python, нового minimum pin или утверждения Pi/Polza compatibility version. Managed Python и внешние backends остаются по прежнему external-tools lock.

Все **15** верхнеуровневых пакетов: Code — 15, Task — 12. Source/version и filters соответствуют [manifest](../../manifests/pi-packages.lock.json) и actual installed identities.

| Пакет | Exact source | Code / Task | Extensions / patch |
|---|---|---|---|
| pi-ollama-cloud | `npm:pi-ollama-cloud@0.12.1` | оба | включён |
| pi-trace-extension | `npm:pi-trace-extension@0.1.16` | оба | установлен, default-off; Trace patch |
| pi-context-inspector | `npm:pi-context-inspector@1.3.0` | оба | включён |
| @juicesharp/rpiv-todo | `npm:@juicesharp/rpiv-todo@2.12.0` | оба | включён |
| pi-polza | `https://github.com/VladimirMonin/pi-polza@cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139` | оба | версия 0.2.1; immutable Git pin |
| pi-subagents | `npm:pi-subagents@0.79.1` | оба | перед Goal X |
| pi-goal-x | `npm:pi-goal-x@0.32.3` | оба | перед Intercom; без нового patch |
| pi-intercom | `npm:pi-intercom@0.17.1` | оба | после Goal X |
| pi-background-tasks | `npm:pi-background-tasks@2.6.2` | оба | установлен, default-off |
| pi-session-search | `npm:pi-session-search@1.6.0` | оба | сохранён profile/runtime patch |
| @samfp/pi-memory | `npm:@samfp/pi-memory@1.6.1` | оба | exact memory-windows-runtime rebase |
| pi-mcp-adapter | `npm:pi-mcp-adapter@5.3.2` | оба | sole owner; `-builtin:mcp`, scripting off |
| @nicknisi/pi-ast-grep | `npm:@nicknisi/pi-ast-grep@0.2.1` | только Code | CLI 0.45.3 и Windows staging сохранены |
| @bacnh85/pi-serena | `npm:@bacnh85/pi-serena@0.9.20` | только Code | tools patch; backend 1.7.0 сохранён |
| pi-cbm | `npm:pi-cbm@1.2.1` | только Code | CBM patch; backend 0.11.0 сохранён |

Polza tag object `a93589ecd0075d3f4c34eb1f13bda891c5983d8c` и peel к указанному commit проверены. Обновления остальных плагинов/backends из исследовательской таблицы не включены попутно. Новых профилей нет; Trace opt-in остаётся [явным](../trace.md).

## Решения и сохранённое поведение

[Архитектурные решения](../notes/pi-1.3.0-upgrade-decisions.md) описывают причины, proof и limits. Failed mixed intermediate install сохранён; согласованный successor создан fresh без peer/exports overrides. Memory rebase сохраняет Windows/profile/session-ID/ordered-turn/scope/aliases/whole-record/automatic-vector fixes и ephemeral hook. Pending recall очищается перед каждым новым user/custom run; tool continuation того же user-run его сохраняет. Custom/empty/search-error не наследуют прошлый block; доступен явный `memory_search`.

Provider/model/dimensions обеих текстовых памятей, DeepSeek-консолидация, рабочие данные/auth и Goal settings/focus/autonomy не менялись. Session Search patch, русская Trace/Windows UTF-8 и различия Code/Task сохранены. Production Goal/core/Polza patches по предположению не добавлялись.

## Evidence — command / origin / scope

Evidence ID: `pi130-review03`. Independent reviewer проверил полный frozen source и затем actual candidate; неизменённые author receipts переиспользованы в их исходном scope, не переименованы в свежие проверки.

| Проверка | Origin / результат |
|---|---|
| Memory profile guard | **Independent PASS:** 9 sacrificial refusals до imports/settings I/O, sentinel bytes неизменны; существующие owner/ancestor/Git/reparse guards |
| `memory-smoke.mjs <SDK> <FRESH_ROOT> code\|task <INSTALLED_SYNTHETIC_PROFILE>` | **Independent PASS Both:** по 8 checks, user/tool/custom/empty/SQLite error/fresh/session reset, прежние contracts; settings byte-restored; local embedder, не paid call |
| `core-smoke.mjs <SDK> <FRESH_ROOT> <PROFILE> coordination` | **Independent PASS:** initial/resumed runner и SDK identity/class, wrong-identity controls, useful results/new output/prior bytes, real foreign-process live-owner refusal; отдельно joint wake и released completion notice/wake |
| `core-smoke.mjs <SDK> <FRESH_ROOT> <PROFILE> cli` | **Independent PASS, 6 cases:** actual stock bundled CLI; terminal bare/text/resumed partial + warning + exit 1; JSON output128/total129 без omission/recovery; normal/persisted restricted tools |
| Goal / Polza / Adapter / full profiles | **Reused unchanged accepted source + actual author receipts:** Goal Stop versus provider abort и offline auditor; production Polza/native transport synthetic SSE/DONE/RUB-once; Adapter Both stdio proxy/direct; Session Search workers/read/escape/cleanup и Trace Both off→on→off |
| Repository / regressions / installed packages | **Independent PASS:** repository verifier 0 failures/0 warnings, regressions 24/24, Both exact 15/12 identities и canonical patches. Installed verifier сохраняет 1 общий NOT TESTED warning для optional/live/POSIX scope; это не ложный общий runtime PASS |
| WVM — последняя техническая проверка | **Independent PASS, два actual Adapter cases:** Code legacy SSE с explicit `httpTransport:"sse"`; Task explicit streamable HTTP. На каждом health, initialize/tools-list, discovered `settings_schema`, 35 callable tools/325 schema fields. Не полная матрица profile × transport |

CLI terminal stimulus исправлен, а не production print: output128=max128, total129, contextWindow65536. Старый early-length recovery FAIL с output2/max128 сохранён; его прежняя атрибуция terminal print defect отозвана. Этот отдельный recovery case не объявлен принятым.

WVM calls выполнялись через installed Adapter в owned SDK probe с builtin off, in-memory session и bounded schema handling; HTTP requests observer-а освобождены после SDK shutdown, процессы завершились естественно. Первый collector FAIL/timeout сохранён, не переименован. Default output-guard sizing и самостоятельный HTTP teardown этим не квалифицируются. Raw WVM payloads/settings/URLs в public evidence не включены; schema-only calls не доказывают readiness моделей, providers или всего приложения.

## Поставка, ограничения и рабочая установка

Поставка — repository source/templates/guarded patches/tests и source ZIP от точного release ref с checksum. Установленный candidate bundle проверен отдельно. ZIP не содержит private runtime-state, рабочих профилей/auth/DB/sessions или `node_modules` и не является offline runtime installer. Transitive locks всех сторонних пакетов/bit-for-bit reproducibility не заявляются.

Не проверены заново: native Linux/macOS, visual TUI/browser, live/paid providers/auditor, OS containment и полный broker restart durability. Client restart proof не переносится на restart общего broker. Historical live embedding evidence остаётся у [build.6](pi-1.0.4-build.6.md), не нового пакета.

**Рабочая установка в этом этапе не выполнялась.** После завершения использующих её Pi roles владелец/оркестратор отдельно проводит существующий protected backup/install/readback/full-restart этап с [откатом](../state-migration.md#откат). Publication не меняет launchers, рабочие профили или данные и не завершает всю кампанию.
