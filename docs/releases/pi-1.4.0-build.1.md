# Pi 1.4.0 build.1 — штатный Polza startup, project scope и Context7

Дата: 2026-10-22. Аннотированный тег: `pi-v1.4.0-build.1`. Предыдущий выпуск: [Pi 1.3.0 build.1](pi-1.3.0-build.1.md).

## Состав и результат

Runtime: **Pi 1.4.0 / Node 25.8.1 / npm 11.11.0**. Установленный Windows candidate содержит семь согласованных внутренних Pi family nodes с exact 1.4.0 и без chord; проверены actual SDK import, ответ local mock, settlement и cleanup. Это не полный transitive lock всех сторонних зависимостей.

Code получает **15**, Task — **12** верхнеуровневых пакетов. Единственное обновление provider — `pi-polza` **0.2.2**; остальные пакеты/backends сохранены из принятого состава: Memory **1.6.1 patched**, Session Search **1.6.0 patched**, MCP Adapter **5.3.2**, Subagents **0.79.1**, Goal X **0.32.3**, Intercom **0.17.1**. Полный source/version/filter перечень — [packages lock](../../manifests/pi-packages.lock.json), runtime и внешние инструменты — [runtime lock](../../manifests/runtime.lock.json) и [external-tools lock](../../manifests/external-tools.lock.json).

Во всех трёх pin inputs (manifest, Code и Task) закреплён доступный Git source Polza:

- commit `e91b09504f7a445b477eaab77cc02d1db067a1e7`;
- release [`v0.2.2`](https://github.com/VladimirMonin/pi-polza/releases/tag/v0.2.2);
- annotated tag object `363c5476397ad042fcbd0596d372bc450b64977f`.

Local path override в переносимом составе отсутствует. Source pin и metadata согласованы с реально установленными Code/Task. Trace и background tasks установлены/default-off; sole MCP owner и порядок Subagents → Goal X → Intercom сохранены. Goal X и выбранные пользователем модели, embeddings/provider/dimensions не переопределялись.

## Что исправлено

- **Polza:** штатно сохранённый credential читается публичным Pi API до начальной загрузки каталога. Холодный старт/перезапуск больше не требуют дополнительного `.env` для основного `polza`. Отсутствующий/отклонённый ключ, сеть и отсутствующая модель различаются; RUB accounting и unknown cost сохранены.
- **Основная модель:** `scripts/check-main-model.mjs` создаёт новую in-memory сессию, сравнивает expected/actual provider/model и структурированный ответ. Registry membership обязателен; fallback/unknown, mismatch, error, abort и timeout не считаются успехом. Это настоящий one-request helper, не offline-only installer stage.
- **Memory:** единый exact project scope используется при remember, консолидации и automatic recall. Дефис и подчёркивание не становятся одним проектом; чужой scope отклоняется с ожидаемым префиксом, explicit aliases/global keys сохранены. Patcher распознаёт пять конкретных известных состояний и отказывается от unknown bytes; backup/check/apply/no-op/restore согласованы.
- **Session Search:** display берёт настоящий `session.cwd`; без него сохраняет slug, не угадывает путь. Исправлены main и worker, расширены guarded inputs и backup/restore. Старое derived display исправляется при чтении без массового reindex; UUID, history filtering и embedding model не менялись.
- **Лаунчеры:** тест принимает реальные explicit launcher/SDK/profile paths; custom installation roots не требуют дополнительных симлинков.
- **Context7:** стандартная fresh установка создаёт remote URL `https://mcp.context7.com/mcp` через adapter 5.3.2, Streamable HTTP/lazy, Code и Task. Adapter-specific файл — `mcp-adapter.json`; в no-key default нет headers, `scriptMode:false`. Реальный loader сохраняет shared sources/imports/settings, собственный URL/auth и явный disable. Local CLI/npx/exclusive mode не требуются. Новые npm-discovery и node-config children используют прежний sanitized-child contract.
- **Документация:** короткий установочный вход, companion links и существующие rules согласованы с PFK; диагностика не получила нового постоянного logger. [MCP](../components/mcp.md), [Memory](../fixes/memory.md), [Session Search](../fixes/session-search.md), [logging](../components/observability.md).

## Приёмка и происхождение evidence

Платформа текущего installed candidate — **Windows 11 x64**, actual Node **25.8.1**, npm **11.11.0**. Helper Python **3.14.2** проверен отдельно, это не новый minimum pin. Независимая приёмка R всех исходных обязательств сохранена; R-final принимает только изменённый R1 и финальную source/release boundary. Числа перекрывающихся запусков не складываются в новый aggregate.

| Группа | Результат / область |
|---|---|
| Polza startup и существенные отказы | R: полный suite **212 tests / 165 PASS / 47 legacy SKIP / 0 FAIL** на locked Node; actual installed native login → отдельный cold start → запрос → отдельный restart, synthetic HTTP, без env-ключа и cache |
| Основная модель | Reused B на actual Pi 1.4 SDK/native CLI: **11 cases**, **8 nonzero refusals**; source review R. Не paid service proof |
| Memory scope / новая консолидация | Reused B: actual shutdown hook создаёт новый synthetic SQLite fact с `source=consolidation`, затем automatic own/alias recall и foreign exclusion. Настоящий runtime с synthetic HTTP, не live paid Polza |
| Patch transitions | Source review R + reused B: fresh, exact known previous, current no-op, unknown refusal; five Memory states и согласованные main/worker hashes, guards не ослаблены |
| Session Search / launchers | Reused B actual SDK/main/worker cases; R actual candidate launchers Both возвращают 1.4.0. Не native POSIX proof |
| Code/Task / SDK graph | R installed verifier **0 failures / 1 явный NOT TESTED warning**; exact 15/12 identities и canonical patches. Loading **13/10 active extensions**, errors=0/warnings=0/fetch=0; 7 internal SDK nodes, core mock. Всего **10/10 bounded runtime cases R**, не дополнительная независимая матрица |
| Context7 config и preservation | R actual Both install/config + reused B real-loader controls. R1-author после sanitization: **15 named checks / 2 shell groups** (PowerShell/Git Bash на Windows) с Both; prefix-absent discovery shim + real node/loader сохранили обе конфигурации byte-exact |
| Context7 public live | Reused **одна** B цепочка через MCP adapter: tools discovery → `resolve-library-id` → `query-docs`, публичная документация. Не повторялась ради нового отчёта |
| R1 child environment | R-final независимый выбранный regression **native exit 0, 1 PASS / 0 FAIL**; synthetic SECRET_SENTINEL отсутствует у npm/uv/Pi и нового node child. Внешний prefix временно снимается самим тестом |
| Final source / safety / package | R-final: полный существующий `tests/scripts/run-tests.ps1` **native exit 0, 24 leaf PASS / 0 FAIL**; `verify.ps1 -RepositoryOnly -Profile Both` **exit 0, failures=0/warnings=0**. JSON/Python/Node/Bash syntax, PowerShell parser, 413 relative file links, 6 instruction headers и **Tree safety 236 files / no findings / exit 0**. Source ZIP строится только от принятого commit; installed receipts R не переименованы в новый install |

Первоначальный независимый Windows source aggregate **23 PASS / 1 FAIL, native exit 1** сохранён: он обнаружил unsanitized fallback, который прежний explicit-prefix harness обходил. R1 не меняет этот исторический результат задним числом. First installer CBM checkpoint отказал из-за local CRLF pristine против уже committed LF bytes: preimage сохранён, восстановлены exact HEAD bytes; штатный patch checkpoint прошёл без reinstall, unknown installed bytes не разрешались по marker.

## Установка нового пользователя

Начните с **[INSTALL_FOR_AGENTS.md](../../INSTALL_FOR_AGENTS.md)**: проверить remote/status/fetch/SHA → prerequisites → PLAN/Apply своей ОС → launchers → verifier Both. Для отдельного checkout принятого выпуска:

```sh
git clone --branch pi-v1.4.0-build.1 https://github.com/VladimirMonin/pi-agent-build.git "<REPO_ROOT>"
```

В каждом новом профиле `/login` → Polza AI → API key, затем `/model` и `/polza-model-info`. Основной `polza` и static `polza-memory` — разные routes; login основного provider не настраивает автоматически служебный credential/embeddings/search. Ключи вводятся локально, не в CLI arguments или отчёте.

Короткая functional проверка выполняется из проверяемого cwd с разрешением на один реальный запрос:

```sh
node scripts/check-main-model.mjs --sdk-root "<SDK_ROOT>" --profile-dir "<PI_ROOT>/agent"
# Для явной альтернативы добавьте --provider и --model; failure exit 2, success 0.
```

Context7 уже настроен для Both: проверьте discovery/resolve/query через MCP, а сетевой/auth/rate-limit отказ укажите отдельно. Безключевой доступ ограничен сервисом. Не повторяйте весь release suite при обычной установке.

## Поставка, состояние и ограничения

GitHub Release поставляет **`pi-agent-build-1.4.0-build.1-source.zip`** из точного release commit через `git archive` и **`SHA256SUMS.txt`**. ZIP — исходники/templates/guarded patches/tests, не offline runtime и не `node_modules`. Нет private auth/settings/БД/sessions/traces. Воспроизводимость top-level pins не равна bit-for-bit transitive reproducibility.

**Рабочая установка владельца не переключалась.** Personal profiles/core/settings, Goal X, credentials, history и embeddings не читались как fixtures и не менялись этой кампанией; protected recovery backup сохранён вне Git. Publication не требует нового рабочего backup или paid probe. Пользователю после собственного patch update нужен полный restart; unknown patch требует сохранения и адресной диагностики, а не отключения guard. [State/restore](../state-migration.md).

Не заявляются fresh native macOS/Linux, visual TUI, live paid model/embedding/consolidation matrix или OS containment. Git Bash проверяет shell/config contract на Windows. Исторические Mac/1.3/WVM/live embedding результаты остаются на исходных версиях. У opt-in Trace нет автоматической rotation/retention; это отдельное известное ограничение незатронутого компонента, не скрытый release gate.
