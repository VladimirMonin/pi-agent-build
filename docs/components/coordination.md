# Подагенты и координация

## `pi-subagents` 0.79.1

Сборка Pi 1.3.0 закрепляет Subagents **0.79.1** и Intercom **0.17.1** вместе; Goal X остаётся **0.32.3**. Этот выпуск не переключает рабочий build.6; его прежнее evidence не выдаётся за проверки нового состава. Сохраняется порядок **Subagents → Goal X → Intercom**.

Пакеты координации предшествуют новому core: старые Subagents требуют удалённый из Pi 1.2+ `chord`; новая пара согласует защиту от двойного parent wake. Это причина очереди обновления, не runtime-доказательство совместимости. Tool schemas могут быть lazy, параметры `options` нужно брать из актуального tool contract: прежнее фиксированное число tools не является критерием PASS.

Приёмочный synthetic case: новый child задаёт supervisor вопрос, получает ответ и завершает полезный результат вместе с Intercom message; подтверждаются ровно один wake и доступный итог. Resume такого ребёнка создаёт новый output, сохраняя прежний, и не передаёт владение активными runs другому Pi process. В broker fixture отдельно проверяются send/receipt, ask/reply и восстановление extension-state после restart. Receipt — не доказательство выполнения задачи моделью. На coherent Pi1.3.0 этот local-mock case выполнен: actual detached initial/resumed children с host-first SDK/PID linkage и завершением; supervisor reply дал полезный результат, Intercom send получил socket receipt, совместный supervisor + busy Intercom exchange имеет ровно один parent wake. Позднее отдельное completion event может дать ещё один wake; fixture различает эти события и проверяет один completion notice, а не требует один turn на всю жизнь ребёнка. Отдельный настоящий SDK host process открывает byte-copy saved synthetic session с тем же UUID и получает live-run resume refusal; исходный ребёнок после этого нормально завершает работу своим владельцем. Это не конкурентная запись двух CLI в один session file. Новый resume output не перезаписал прежний; ask/reply и extension-state readback после client restart проверены при живом peer/broker. Broker state не объявляется durable после broker restart. Это synthetic SDK/RPC evidence, не paid model или visual TUI. Independent fresh acceptance дополнительно проверила actual runner/SDK/class identity обоих children и физически разделённые joint/completion phases с измеренными wakes и run ID. Corrected terminal CLI discriminator принят без core patch; [fixture](../../tests/sdk/README.md) и [release scope](../releases/pi-1.3.0-build.1.md).

### Назначение

Запускает focused child Pi sessions: foreground/background delegation, parallel/chain workflows, reviews, scouting и council patterns.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:pi-subagents@0.79.1
```

### Конфигурация и данные

Опциональный config — `<PROFILE_DIR>/extensions/subagent/config.json`; settings-level `subagents.*` живут в Pi settings. Package, project и user agent definitions могут расширять builtins. Async runs, transcripts, missions и artifacts содержат приватный context; точные пути показывает installed `/subagents-guide observability`.

### Команды, tools и skills

- tools: `subagent`, `subagent_supervisor`, `bg_wait` и management actions через `subagent`;
- команды: `/subagents-doctor`, `/subagents-guide [topic]`, `/subagents-fleet`, `/council`;
- builtins: `scout`, `researcher`, `evidence-auditor`, `worker`, `reviewer`, `oracle`, `delegate`;
- skills: `pi-subagents`, `council-mode`; package также поставляет prompt shortcuts.

### Риски

Каждый child может расходовать model quota и видеть forked/frozen context и унаследованные skills. Fork не является информационной изоляцией. Активные runs старой версии не переносятся на ходу; новая resume-схема не обещается для детей, созданных старой версией. Background processes переживают parent control flow; проверяйте status и terminal result. Tool allowlist не является OS sandbox. Не доверяйте child summary без artifacts/tests; bounded spawn limits не отменяют стоимость.

### Проверка

`/subagents-doctor`, затем `subagent({action:"guide", topic:"overview"})` или безопасный foreground `scout`. Для background дождитесь terminal state и прочитайте result, не считайте launch receipt завершением.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:pi-subagents
```

До удаления остановите active runs. Runtime artifacts/sessions остаются и чистятся отдельно после аудита.

## `pi-intercom` 0.17.1

### Назначение

Локальные адресные сообщения между одновременно работающими Pi sessions; интегрируется с subagents для supervisor escalation.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:pi-intercom@0.17.1
```

### Конфигурация и данные

`<PROFILE_DIR>/intercom/config.json` управляет `enabled`, `confirmSend`, `inboundTrigger`, `replyHint` и trusted broker override. Runtime broker PID/locks/sockets тоже профильные. Messages записываются в session history; mailbox broker — bounded in-memory и не переживает broker restart.

Для строгого режима установите `inboundTrigger: "replies"` или `"never"`, а для разделения групп процессов — одинаковый `PI_INTERCOM_SCOPE_ID` только внутри доверенной группы.

### Команды, tools и skills

- tool `intercom`: `list`, `list-cwd`, `send`, `ask`, `reply`, `pending`, `status`, `cancel`;
- child-only `contact_supervisor` появляется только при bridge metadata от pi-subagents;
- commands `/intercom`, `/intercom-id`, `/alias`; shortcut `Alt+M`;
- skill `pi-intercom`.

### Риски

`inboundTrigger: "always"` может автоматически запустить turn по входящему локальному сообщению. Local broker не аутентифицирует недоверенный код как security boundary; scope — routing boundary, не sandbox. Attachments и messages становятся частью session context. `ask` блокируется до ответа/timeout.

### Проверка

Откройте две именованные sessions, выполните `intercom({action:"status"})` и `list`, затем отправьте не-секретное test message. Проверьте reply threading и отсутствие связи между разными scope IDs.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:pi-intercom
```

После обновления нужен полный перезапуск относящихся к установке Pi sessions и общего broker: `/reload` одной сессии не гарантирует новый broker. Одинаковый stable ID у одновременно активных сессий отвергается. Не убивайте процессы по имени и не удаляйте чужое состояние.

Для удаления сначала закройте sessions/broker; затем удалите profile intercom runtime files. Исторические messages останутся в sessions.

## `pi-background-tasks` 2.6.2 — установлен, но отключён

### Назначение

Upstream package предоставляет background shell jobs, delegated inspect agents, attested child runs и Fusion workflows.

### Установка в этой сборке

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:pi-background-tasks@2.6.2
```

В `settings.json` обязательно:

```json
{"source":"npm:pi-background-tasks@2.6.2","extensions":[]}
```

Причина: 2.6.2 несовместим с system-role conversation blocks Pi 0.87.0. Пока filter пуст, extension не загружается.

### Конфигурация и данные

В отключённом состоянии package не создаёт tasks. Если будущая совместимая версия будет включена, upstream пишет project runtime в `.pi/tasks/`, `.pi/delegate/`, `.pi/fusion/`; shell jobs выполняются с правами пользователя и не sandboxed.

### Команды, tools и skills

В текущей сборке — **нет активных surfaces**. Upstream surfaces (`/bg`, `/jobs`, `bg_run`, `bg_delegate`, `bg_result`, `fusion_*` и др.) перечислены здесь только для диагностики: их неожиданное появление означает, что filter потерян. Skills package не объявляет.

### Риски

Случайное раскрытие `extensions` включает выполнение shell jobs/children и конфликтный parser. `pi list` пишет `(filtered)` и при корректном explicit list, и при некоторых изменениях filter; проверяйте сам JSON и отсутствие `/bg-tasks`.

### Проверка

Проверьте object entry в обоих settings и убедитесь, что `/bg-tasks` не зарегистрирована. После любого `pi config`/install повторите проверку.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:pi-background-tasks
```

Удаление безопаснее включения. Не активируйте новую версию, пока реальный system-role smoke не пройден и manifest/docs не обновлены.
