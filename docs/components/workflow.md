# План задач

## `@juicesharp/rpiv-todo` 2.12.0

### Назначение

Добавляет model-facing todo list и TUI overlay для многошаговой работы. Состояние восстанавливается из tool calls текущей session branch и переживает `/reload`/compaction без отдельной БД.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" \
  pi install npm:@juicesharp/rpiv-todo@2.12.0
```

### Конфигурация и данные

Опциональный config: `~/.config/rpiv-todo/config.json` либо `$XDG_CONFIG_HOME/rpiv-todo/config.json`:

```json
{"maxWidgetLines": 8, "collapseKey": "alt+t"}
```

Extension читает config, но не пишет его. Task snapshots находятся в conversation entries; удаление session удаляет единственный persistent source списка.

### Команды, tools и skills

- tool `todo`: actions `create`, `update`, `list`, `get`, `delete`, `clear`; statuses `pending`, `in_progress`, `completed` плюс tombstone `deleted`; поддерживает `blockedBy`;
- `/todos` — полный список по статусам;
- `Ctrl+Shift+T` по умолчанию сворачивает overlay;
- отдельных skills нет; optional `@juicesharp/rpiv-i18n` в эту сборку не входит.

### Риски

Tool snapshot увеличивает session context; todo labels могут содержать приватные детали. Headless runs получают tool, но не overlay. Todo — средство отслеживания, а не гарантия выполнения или transactional scheduler.

### Проверка

На новой TUI-сессии `/todos` должен сообщить об отсутствии задач. Создайте тестовый todo, обновите status, выполните `/reload` и проверьте восстановление.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" \
  pi remove npm:@juicesharp/rpiv-todo
```

Удалите optional config отдельно. Исторические todo tool calls останутся в session files.

## `pi-goal-x` 0.32.3

### Назначение

Добавляет `/goal` и `/sisyphus`: агент обсуждает цель, предлагает objective и план задач, затем продолжает работу автономно, пока цель активна. Состояние (objective, задачи, прогресс, evidence) сохраняется между сессиями в файлах проекта, а не только в conversation branch. Опциональный независимый completion auditor проверяет результат перед закрытием цели.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" \
  pi install npm:pi-goal-x@0.32.3
```

### Конфигурация и данные

Настройки слоёные: `environment > <cwd>/.pi/pi-goal-x-settings.json > ${PI_CODING_AGENT_DIR:-~/.pi/agent}/pi-goal-x-settings.json > defaults`. Файлы разрежённые (sparse), неизвестные ключи сообщаются в diagnostics. Ключевые настройки: `strictExecutionContract`, `maxAutonomousRuns`, `subtaskDepth`, `stallTimeoutMinutes`, `objectiveMaxChars`, `auditorProjectResources`, `goalsRoot`, `disabled`, `hideUnfocusedBanner`. Сборка сразу устанавливает [автономный пресет](../goal-autonomy.md): absent `maxAutonomousRuns` = unlimited, `strictExecutionContract:false`, tasks depth2, Auditor/Oracle high. Existing персональные settings сохраняются.

Состояние цели — project-local: `<cwd>/.pi/goals/` (`active_goal_*.md`, `goal_events.jsonl`, `.goals-pool-snapshot.json`), архив — `<cwd>/.pi/goals/archived/`. Это не общий с `~/.pi` state: цели привязаны к рабочему каталогу, а не к профилю.

### Команды, tools и skills

- tools: `create_goal`, `get_goal`, `update_goal`, плюс `set_goal_tasks`/`update_goal_task` (при включённых задачах) и transient drafting tools `goal_question`, `goal_questionnaire`, `propose_goal_draft`;
- команды: `/goal`, `/sisyphus`, `/goal-direct`, `/sisyphus-direct`, `/goal-list`, `/goal-status`, `/goal-focus`, `/goal-unfocus`, `/goal-tweak`, `/goal-pause`, `/goal-resume`, `/goal-clear`, `/goal-cancel`, `/goal-settings`, `/goal-recovery`, `/goal-refresh`;
- dashboard над редактором: `Ctrl+Shift+T` разворачивает дерево задач, `Ctrl+Shift+A` переключает аудитора, `Esc` во время работы ставит цель на паузу;
- отдельных skills нет.

### Риски

- **порядок загрузки:** `pi-goal-x` должен грузиться раньше `pi-intercom` (так закреплено в манифесте и шаблонах). При обратном порядке в headless-режиме (`pi -p`) `turn_end` печатает ошибки boundary и stale ctx; на работу цели это не влияет, но засоряет stderr. Подробности — [notes/goal-x-intercom-order.md](../notes/goal-x-intercom-order.md);
- peer range `@earendil-works/pi-* >=0.83.0 <2.0.0`: при апгрейде Pi за пределы диапазона пакет перестанет соответствовать заявленной совместимости;
- автономное продолжение расходует токены; текущий владелец сознательно выбрал unlimited. Агент не меняет Goal X settings без явного запроса и никогда не ставит `maxAutonomousRuns:0`; технический blocker передаётся Oracle через `blocked`, не `paused`;
- auditor по умолчанию изолирован от project resources (`auditorProjectResources: false`); включение расширяет его поверхность;
- состояние пишется в рабочий каталог (`.pi/goals/`), поэтому попадает под project-local файлы и не должно коммититься;
- в делегированных subagent-сессиях (`PI_SUBAGENT_CHILD=1` / `PI_SUBAGENT_DEPTH>0`) расширение намеренно не наследует владение родительской целью.

### Проверка

В новой TUI-сессии `/goal-status` должен сообщить об отсутствии цели. Создайте цель через `/goal-direct <objective>`, убедитесь, что появился `<cwd>/.pi/goals/active_goal_*.md`, затем `/goal-pause` и `/goal-clear`.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" \
  pi remove npm:pi-goal-x
```

Project-local `.pi/goals/` удаляется отдельно.
