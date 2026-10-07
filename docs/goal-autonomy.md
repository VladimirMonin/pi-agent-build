# Goal X: автономный пресет

Сборка устанавливает [пресет](../config/pi-goal-x-settings.json) и [две постоянные инструкции](../config/goal-autonomy.AGENTS.md) в **Code и Task**. Новая установка получает их сразу; существующие файлы сохраняются. Замена персональных настроек разрешена только по явному запросу пользователя, с backup. Settings-only sync обычного `settings.json` не меняет Goal X.

## Значения

| Настройка JSON | Значение |
|---|---|
| `autoSelectSingleGoal` | `false` |
| `hideUnfocusedBanner`, `hideUnfocusedPrompt` | `false` |
| `disableContracts` | `false` — проверка результата включена |
| `strictExecutionContract` | `false` — implicit continuation, без обязательных ready/wait |
| `maxAutonomousRuns` | **ключ отсутствует: unlimited** |
| `stallTimeoutMinutes`, `objectiveMaxChars` | `0` |
| `disableTasks`, `subtaskDepth` | `false`, `2` |
| `disabled` | `false` — Completion Auditor включён |
| `provider`, `model`, `thinkingLevel` | `openai-codex`, `gpt-6.1-sol`, `high` |
| `oracle.enabled` | `true` |
| `oracle.provider`, `oracle.model`, `oracle.thinkingLevel` | `openai-codex`, `gpt-6.1-sol`, `high` |
| `oracle.projectResources` | `true` |
| `oracle.maxFailedAttemptsPerBlocker` | `2` |

В закреплённой **Goal X 0.32.3** строка autonomous runs скрывается при unlimited; появился `showAutonomousRuns`, но пресет не меняется. Recovery дополнительно распознаёт `PROTOCOL_ERROR` и `finish_reason: error`; quota/billing не повторяются. Старые goals читаются, но после сохранения scheduler больше не содержит `nextAction`: перед первой живой работой новой версии сохраните одну копию `.pi/goals` вне Git. Auditor project resources остаются default-off: независимая проверка не наследует исполняемые extensions проекта. Oracle получает project resources по явному запросу владельца.

Модель выбрана из доступного registry текущей Windows-сессии. Для её вызовов нужен собственный вход в `openai-codex`; сборка не поставляет и не переносит auth. На другой машине модель/провайдер выбираются явно в `/goal-settings`, с сохранением `high` и остальных правил пресета.

## Unlimited и наследование

Глобальный файл: `${PI_CODING_AGENT_DIR:-~/.pi/agent}/pi-goal-x-settings.json`; проектный: `<cwd>/.pi/pi-goal-x-settings.json`. Task использует свой agent directory. `PI_GOAL_GLOBAL_SETTINGS_FILE` / `PI_GOAL_SETTINGS_FILE` могут переопределить пути.

- В `/goal-settings` → **autonomous run allowance** → **Use inherited value**.
- Если унаследован числовой лимит, удалите override и на глобальном уровне. Ожидается **unlimited (default)**.
- `0` выключает продолжение; `9999` — всё ещё лимит. Нужен отсутствующий ключ, не `null` и не строка `unlimited`.
- После внешнего изменения файлов `/goal-refresh` перечитывает настройки без изменения цели. Новая сессия не выбирает чужую Goal: focus задаётся явно.

## Обычная автономная работа

`/goal` → Executor работает → при реальном техническом тупике **blocked → read-only Oracle** → Executor пробует совет → по завершении независимый **Auditor** проверяет результат. QA, ожидание результатов и желание избежать «пустых циклов» не являются причиной поставить Goal на pause или выключить продолжение. Oracle limit `2` ограничивает неудачные запуски Oracle на blocker, а не две попытки Executor исправить код.

Постоянные инструкции:

> Do not modify Goal X settings unless explicitly requested by the user. Never set maxAutonomousRuns to 0.
> For technical blockers use blocked, not paused, so Blocker Oracle can intervene.

## Фактически выполнено в Windows

По прямому запросу владельца этот пресет применён к существующим Code/Task, конфликтующие overrides текущего проекта проверены. Настоящий `loadSettingsSnapshot` установленной Goal X подтвердил значения и **unlimited**. Две инструкции добавлены в profile `AGENTS.md`. Auth, память, DB и сессии не читались и не менялись; provider calls для этой проверки не выполнялись. Это проверка конфигурации, не заявление о выполненном платном Oracle/Auditor run.
