# План задач

## `@juicesharp/rpiv-todo` 2.10.1

### Назначение

Добавляет model-facing todo list и TUI overlay для многошаговой работы. Состояние восстанавливается из tool calls текущей session branch и переживает `/reload`/compaction без отдельной БД.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" \
  pi install npm:@juicesharp/rpiv-todo@2.10.1
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
