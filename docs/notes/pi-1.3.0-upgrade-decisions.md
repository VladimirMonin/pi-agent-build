# Pi 1.3.0 — решения обновления и границы доказательств

Дата: 2026-10-19. Принятый состав — [Pi 1.3.0 build.1](../releases/pi-1.3.0-build.1.md). Исходный [план](../../.hermes/plans/2026-10-19_114157-pi-upgrade.md) сохранён до runtime-изменений. Этот документ объясняет выбранные решения, а не разрешает переключение рабочих профилей.

## 1. Согласованное ядро вместо ремонта промежуточной установки

**Проблема:** установка прежнего top-level Pi 1.0.4 разрешила caret-зависимости в новое поколение и падала при SDK import. Один `pi --version` не доказывает согласованность внутренних пакетов.

**Решение:** failed install сохранён; новый кандидат установлен в fresh owned root на exact Pi 1.3.0. Проверены реальные dependency declarations и resolution всех семи family nodes: coding-agent, agent-core, AI, codemode, MCP, TUI, telemetry — exact 1.3.0. Chord отсутствует. Overrides, exports shims и ремонт старого root не использовались.

**Сохранено / доказано:** прежние Node/npm, два профиля и их filters; actual SDK import, local mock turn и cleanup. Это не lock полного стороннего dependency graph и не bit-for-bit/offline воспроизводимость.

## 2. Memory 1.6.1: exact rebase и user/custom lifecycle

**Проблема:** новый core вызывает `before_agent_start` и для custom continuation без user prompt. Прежний безусловный поиск мог получить неверный запрос или оставить recall прошлого запуска. Upstream 1.6.1 сам по себе не заменяет наши runtime/scope исправления.

**Решение:** один exact pristine/hash rebase, canonical apply/check/idempotence/restore и отказ на drift. Pending block очищается до поиска/early return каждого нового run и на session boundaries. Recall разрешён только непустому user prompt; custom/empty/search-error не наследуют старый block. Context/tool continuation того же user-run сохраняет block; явный `memory_search` остаётся доступен в служебных продолжениях.

**Сохранено / доказано:** Windows Node/выбранный CLI prefix, profile settings, настоящий session ID, ordered turns, aliases/project scope, целые записи и ephemeral upstream hybrid/RRF recall без записи в system/history/consolidation. Independent Code/Task smoke проверил связанную последовательность, включая реальную ошибку synthetic SQLite. Patch lifecycle и canonical installed states проверены отдельно.

Embedding provider/model/dimensions и DeepSeek-консолидация не менялись; personal DB не fixture. Миграции, backfill/reindex рабочих данных не запускались. Session Search 1.6.0 и его patch сохранены.

## 3. Adapter — единственный MCP owner

**Проблема:** streamable HTTP с SSE-ответом не эквивалентен legacy SSE. Новый builtin MCP не даёт требуемого транспортного паритета. Обновление OAuth SDK не доказывает безопасность всех ранее сохранённых credentials.

**Решение:** Adapter 5.3.2 остаётся единственным owner; `-builtin:mcp`, scripting off, shared configuration/direct-tool policy сохранены. Config/auth не мигрируются автоматически; redirects и secret-command shell проверяются только в фактически используемом scope.

**Доказано:** installed Adapter Both прошёл synthetic stdio discovery/describe/proxy/direct calls. Последним техническим шагом independent reviewer вызвал discovered read-only `settings_schema` у уже работающей WVM: **Code-installed Adapter — explicit legacy SSE; Task-installed Adapter — explicit streamable HTTP**, initialize/tools-list на обоих. Это два случая, не полная матрица profile × transport и не gateway proof. В отдельном owned SDK probe builtin выключен; остальные full-profile contracts приняты отдельно.

Schema обрабатывалась в памяти с конечным output bound 4 MiB; report содержит только безопасные counts/status. Первый private collector не распознал большой ограниченный ответ и превысил deadline: его FAIL сохранён. Fresh collector с корректным bounded result handling и освобождением принадлежащих ему HTTP requests после SDK shutdown завершился естественно. Самостоятельный HTTP teardown без такого observer ownership этим не заявляется. Settings get/plan/apply/preview, модели, очередь, microphone, GUI и server lifecycle не вызывались.

## 4. Координация: измерение вместо предположений

Subagents 0.79.1 и Intercom 0.17.1 обновлены парой; порядок **Subagents → Goal X → Intercom** сохранён. Старые активные children не считаются перенесёнными.

Independent fixture проверил actual initial/resumed runner path/hash, SDK entry/package identity и совпадение constructor активного SessionManager с candidate SDK; env host echo недостаточен. Wrong-class/hash controls отказали. Полезные результаты initial/resume различаются, прежние bytes сохранены; foreign session и отдельный SDK process на копии saved synthetic context не приняли live run.

Child completion физически удерживается до доставки совместного supervisor/Intercom exchange и settlement родителя. Измерен один joint wake без completion notice; после release — отдельно один completion notice/wake с run ID. Не используется предполагаемый completion slot или вычитание общего counter. Send receipt не приравнивается к выполнению моделью.

Client/extension restart state проверен при surviving broker; durability после полного broker restart не заявляется. Рабочий restart/установка отложены до отдельного безопасного post-exit этапа.

## 5. Почему нет speculative Goal/core/Polza patches

Goal X 0.32.3 прошёл native custom checkpoint, provider abort versus настоящий SDK Stop, native resume и durable completion с injected offline auditor. Настройки автономности/focus не менялись; Goal patch не понадобился. Paid auditor этим не проверен.

Polza остаётся exact 0.2.1 / `cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139`. Production stream с native Pi 1.3 transport прошёл synthetic reasoning/tool JSON/usage, DONE до delayed EOF и RUB accounting ровно один раз, без USD reinterpretation. Изменён locator fixture, не production provider. Отдельная docs-only публикация провайдера не требует runtime bump.

Старый CLI stimulus сообщал output 2 при maxTokens 128 и выбирал **early-length recovery**, а не terminal output limit. Пустой вывод той попытки остаётся сохранённым FAIL/непринятым наблюдением; прежняя атрибуция terminal print defect отозвана. Corrected stimulus: output 128, total 129, context window 65536. Independent actual bundled CLI прошёл шесть cases: bare/text current partial + warning + exit 1; JSON без omission/recovery/retry; normal restricted tools; persisted-tools resume; resumed terminal без stale output. JSON exit 0 соответствует отдельному mode contract. Обе print реализации и core остались stock.

## 6. Safety, helpers и выпуск

Memory fixture проверяет реальный installed profile/case и ancestors до product imports/settings I/O через существующие owner/Git/reparse guards. Девять sacrificial negatives отказали без imports/settings access; settings обоих валидных synthetic профилей восстановлены byte-exact.

Installed-state допускает только узкие pinned startup metadata: exact four-field empty-server Adapter onboarding и единственный Subagents last-seen-version file. Strict keys/types/size/version/path/link checks не разрешают arbitrary config/auth/runs/ownership state. Unknown state не очищается ради PASS.

Node **25.8.1**, npm **11.11.0**, Pi **1.3.0** закреплены runtime manifest. Отдельный Windows helper **Python 3.14.2** фактически проверен и не обновлялся: это не Pi/Polza version, не новый minimum/runtime pin и не замена managed Python Serena.

Public release содержит source/templates/patches/tests, не личный профиль или `node_modules`. Source ZIP строится штатным `git archive`, проверяется отдельно и сопровождается checksum; это не автономный установленный runtime bundle. Release publication не выполняет live install/backup/restart. Native POSIX, visual TUI/browser, paid/live-provider и OS containment остаются вне заявленного proof.
