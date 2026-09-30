# Матрица совместимости кандидата Pi 0.99.1

**Статус:** подготовка контракта этапа 3; **runtime не испытан**. [Доска и gates](pi-0.99.1-execution-board.md). Pi и набор пакетов закреплены в `manifests/*.lock.json`; наличие пакета в manifest либо успешная загрузка **не** означает функциональный PASS. Все проверки ниже выполняются *только после runtime isolation gate* с явным Pi из `<LAB_ROOT>/npm-prefix`, из синтетического `<LAB_ROOT>/test-cwd`, с приватным процессным окружением, без рабочих credential/БД. Отдельный результат Code и Task обязателен; `N/A` допустимо лишь для явно Code-only пакета, а не для непроверенного поведения.

| Компонент / pinned версия | Code | Task | Функциональный критерий для PASS; иначе зафиксировать причину и свидетельство |
|---|---|---|---|
| Core CLI `0.99.1` | NOT TESTED | NOT TESTED | Абсолютный бинарник/версия, headless JSON events, sessions и tool invocation; нет глобального fallback. |
| `pi-ollama-cloud@0.12.1` | NOT TESTED | NOT TESTED | Загрузка provider, корректная маршрутизация/ошибка без ключа; live model отдельно в модельной матрице. |
| `pi-trace-extension@0.1.16` + profile patch | NOT TESTED | NOT TESTED | Patch guard и события изолированного профиля; никакого shared trace. |
| `pi-context-inspector@1.1.1` | NOT TESTED | NOT TESTED | Команда/tool в headless и обработка синтетического контекста. |
| `@juicesharp/rpiv-todo@2.10.1` | NOT TESTED | NOT TESTED | Изолированный todo lifecycle/tool/result; не менять рабочие задачи. |
| `pi-polza@0.2.0` (закреплённый Git ref) | NOT TESTED | NOT TESTED | Provider loads без ключа; разрешённый реальный запрос/модель проверяются отдельно. Upstream исходники не изменять без доказанного дефекта. |
| `pi-subagents@0.70.1` | NOT TESTED | NOT TESTED | Дочерний процесс, инструменты, ограниченный stdout/artifact и отсутствующие секреты. |
| `pi-goal-x@0.31.9` | NOT TESTED | NOT TESTED | Цель и состояние *только* в test-cwd; headless/events и повторное чтение после рестарта. |
| `pi-intercom@0.13.0` | NOT TESTED | NOT TESTED | Scope lab, два synthetic peer и отсутствие рабочих broker/messages. |
| `pi-background-tasks@2.6.2` | NOT TESTED | NOT TESTED | Synthetic task lifecycle, shutdown/restart и файлы только в lab. |
| `pi-session-search@1.4.3` + Task profile patch | NOT TESTED | NOT TESTED | Byte-exact guard, index и **источник** sessions/archives под lab; search без чтения рабочих сессий. |
| `@samfp/pi-memory@1.5.0` + Windows runtime patch | NOT TESTED | NOT TESTED | Version/hash guard; scope, lesson budget, embedding, full-record truncation, фактическое открытие synthetic DB/WAL/SHM и полный `<memory>` в JSON/payload. |
| Memory consolidation child `--no-extensions` | NOT TESTED | NOT TESTED | Built-ins действительно отключены; статический `polza-memory` работает без динамического провайдера, исходящий запрос только по отдельному разрешению; отсутствие ключа ≠ PASS. |
| `pi-mcp-adapter@2.36.0` | NOT TESTED | NOT TESTED | Изолированный config, обязательные маршруты/виртуализация и `/mcp` без конкуренции с built-in; WVM здесь **не запускать**. |
| `@nicknisi/pi-ast-grep@0.2.0` | NOT TESTED | N/A | Tool с synthetic TypeScript и ожидаемые AST matches. |
| `@bacnh85/pi-serena@0.9.16` + patch | NOT TESTED | N/A | Tool index/symbol на test project, изолированные cache/process; patch guard. |
| `pi-cbm@1.2.1` + patch | NOT TESTED | N/A | Index/graph query синтетического проекта, private cache; patch guard. |
| SDK/RPC/codemode и new thinking suffix | NOT TESTED | NOT TESTED | Контракт tools/hooks/events и provider/id:thinking без ложного fallback; только заявленные возможности. |

**Доказательства:** для каждой ячейки указывать приватный ID команды/результата на [доске](pi-0.99.1-execution-board.md), exact package/version/профиль и наблюдаемый функциональный результат; сырые логи и payload не публиковать. При изменении патча или установщика повторить затронутые тесты обоих профилей. Legacy SSE и streamable HTTP WVM проверяются **последним техническим этапом** и фиксируются отдельно: отсутствие WVM до этого шага не повышает статус MCP до PASS. Модели/платные ответы ведутся в собственной матрице с раздельными catalog/auth/response/tool/limits.
