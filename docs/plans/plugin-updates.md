# Обновления личной сборки — короткий план

## Правило владельца

Это личная сборка. Работаем короткими законченными обновлениями: **исследование → минимальные изменения → запуск и проверка → commit/push/release → установка себе → полный перезапуск**. Не ждём следующих upstream releases и не двигаем выбранные версии вслед за latest.

Без новых стендов, VM, isolation frameworks, широких аудитов, платных проверок по умолчанию и многоступенчатых approval loops. Один ответственный writer. Один read-only саб уточняет текущий план, не создаёт дополнительные этапы. Конкретный баг исправляем локально и повторяем только связанную проверку. Рабочие settings, auth, память и sessions не заменяем шаблонами. Goal X settings и human-owned focus не меняем.

## A — следующий релиз

Pi остаётся **1.0.4**. Обновляем только:

- `pi-subagents`: **0.76.0 → 0.76.1**;
- `pi-goal-x`: **0.31.9 → 0.32.3**;
- `pi-intercom`: **0.13.0 → 0.16.1**.

1. Меняем pins в `manifests/pi-packages.lock.json`, `profiles/{code,task}/settings.template.json` и только связанные current-version fixtures/docs, включая pinned-order settings в `tests/scripts/run-tests.ps1`. Сохраняем **Goal X перед Intercom**, изображения и все прочие версии/настройки. Порядок работы: Subagents → Goal X → Intercom.
2. Существующими средствами запускаем кандидат Code/Task в отдельном обычном каталоге с synthetic settings/state. Не создаём новый installer или test framework.
3. Короткая проверка: `tests/sdk/profile-loading.mjs <SDK_ROOT> <SYNTHETIC_PROFILE>` отдельно для Code/Task в private HOME; synthetic background completion разбудил parent обычным turn и сохранил prompt additions. Одним коротким совместным smoke проверяем старый synthetic goal с `nextAction`, его продолжение/завершение, обмен двух локальных test-сессий Intercom через Windows broker и idle wake. Сохранённый порядок Goal X → Intercom проверяем этим же headless сценарием; старую матрицу не повторяем. Fake transient recovery проверяем дополнительно только при конкретном дефекте. Публичный Subagents RPC/Polza contract по переданному исследованию не менялся: отдельный paid Polza smoke не требуется.
4. `scripts/verify.ps1 -RepositoryOnly`, `tests/scripts/run-tests.ps1`, safety scan и просмотр diff. Core-only smoke не повторяем: Pi не меняется. Если всё работает — один mini-release **`pi-v1.0.4-build.2`**, commit/push/tag/GitHub Release. Не расширяем support claims за пределы реально запущенного.
5. Ставим эти же три exact npm-spec себе штатным package lifecycle с явным `PI_CODING_AGENT_DIR` для Code/Task; не используем полный installer, `update --all`, замену configs или миграцию памяти/auth. До первой живой работы нового Goal X один раз сохраняем копию текущего `.pi/goals` вне Git: новый scheduler после сохранения теряет `nextAction`. Это одна копия данных, не разработка rollback-системы. Проверяем наличие custom `brokerCommand` только если он задан. Полностью перезапускаем Pi и проверяем обычный запуск. Готово.

Текущий статус: **A завершён** — `pi-v1.0.4-build.2` опубликован и эти же три exact пакета установлены в живые Code/Task. Candidate и fresh-process loading actual installed payloads13/10 без ошибок/предупреждений/fetch; короткий synthetic wake/legacy-goal + два процесса Windows Intercom broker PASS; Windows regressions24/24, verifier0/0. Настройки Goal X, другие версии и patch bytes сохранены; одна копия project goals вне Git. Уже открытые Pi-сессии и сабы владелец полностью перезапускает. [Release notes](../releases/pi-1.0.4-build.2.md). Исследования владельца служат входом, недостающие детали проверяются только при необходимости конкретного изменения.

## Следующие обновления — тот же алгоритм

Владелец досылает исследования. Они не расширяют этап A автоматически.

- **B — Serena 0.9.20:** по исследованию владельца небольшой exact rebase: скрыть `serena_check_onboarding_performed` и `serena_find_implementations`, убрать упоминание `find_implementations` из `SERENA_FIRST_GUIDANCE`. Новый pristine для 0.9.20 и exact guidance patch; не расширять guard старых bytes. Serena Agent 1.7.0/Python/Pyright оставляем. Короткая приёмка: 20 stock → 18 visible tools, обе ложные capabilities отсутствуют, guidance их не предлагает, `serena_find_symbol` реально работает через Pyright. Не добавлять отдельный migration framework.
- **C — Session Search 1.6.0:** исследование владельца принято как вход для небольшого нового exact patch, не механического переноса 1.4.3. Task сохраняет `<PROFILE>/session-search/{config.json,index}`, `<PROFILE>/sessions` и `<PROFILE>/sessions-archive`; Code сохраняет прежние stock config/index paths. Session/archive roots передавать штатно через `IndexOptions → workerData`, не патчить `dist/index-worker.js`. Учесть различие `PI_SESSION_DIR` плагина и `PI_CODING_AGENT_SESSION_DIR` Pi1.0.4; существующие явные overrides не терять. В `session_read` использовать фактические configured/profile roots и Windows-safe containment вместо `startsWith(root + "/")`. Сохранить cleanup проигравшего initial-sync timer. Короткая приёмка: worker стартует/закрывается, Task ищет и читает собственную synthetic session, Code читает свою, чужой путь отклоняется. Существующие config/index paths и Polza embedding config сохраняем; по исследованию форматы FTS/hybrid совместимы — forced `/session-reindex`, paid embeddings и смену `fusion` не добавляем. Если при реализации обнаружится конкретная несовместимость, исправляем только её.
- **D — Memory 1.6.0:** проверить оставшиеся необходимые исправления, выбрать embedding backend и проверить на synthetic DB. Перед живым переходом одна копия данных; это не основание строить инфраструктуру отката.
- **E — MCP Adapter 5.1.0:** выбрать одного MCP owner, проверить нужные серверы включая WVM. Не держать два владельца одних серверов.

Каждый этап — небольшой самостоятельный релиз и установка себе после запуска. Inspector, Background Tasks, внешние инструменты и соседние настройки без отдельного решения не трогаем.
