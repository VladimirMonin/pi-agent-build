# Модельная матрица кандидата Pi 0.99.1

**Статус:** подготовка контракта этапа 4. Runtime isolation gate ещё не выполнен; ни каталог кандидата, ни авторизация, ни исходящий запрос не проверены. [Доска](pi-0.99.1-execution-board.md). Источники заявленных семейств: [v0.87.1](https://github.com/earendil-works/pi/releases/tag/v0.87.1), [v0.99.0](https://github.com/earendil-works/pi/releases/tag/v0.99.0), [v0.99.1](https://github.com/earendil-works/pi/releases/tag/v0.99.1). Семейство из release notes **не** гарантирует точный model ID, доступ через Polza или ответ от провайдера.

| Маршрут / семейство для сверки | Каталог и точный ID в кандидате | Auth/доступ | Ответ Code | Ответ Task | Tool/reasoning/limits | Свидетельство |
|---|---|---|---|---|---|---|
| Текущий основной Polza (ID определить из разрешённого каталога, не копируя рабочие secrets) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | — |
| Статический `polza-memory` для ребёнка `--no-extensions` | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | — |
| OpenAI Responses / GPT-6 Sol и Luna (релиз 0.87.1) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | — |
| Anthropic / Claude Opus 5.5 (релиз 0.87.1) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | — |
| Anthropic / Claude Sonnet 5.5 (релиз 0.99.0) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | — |
| OpenAI/Azure Responses/Codex / GPT-6.1 Sol (релиз 0.99.1) | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | NOT TESTED | — |

После изолированной установки и plugin gate: снять **офлайн** каталог кандидата явным бинарником Pi из `<LAB_ROOT>/npm-prefix` при синтетическом cwd/child-env; записать точный provider/model ID, thinking, контекст и пределы, различая каталоги Pi и Polza. Проверка каталога не повышает статусы auth/response. Секреты не писать в CLI-аргументы, Git, публичные логи или тестовую БД; рабочий `auth.json` не копировать.

Платные реальные запросы выполнять только после отдельного разрешения владельца по маршруту/квоте и runtime isolation gate. Для каждой **заявленной в релизе** модели нужно доказать actual outgoing provider/model ID и ответ, reasoning, tool call/ошибку и пределы; отдельно Code и Task. Для памяти нужен синтетический scoped payload с полным `<memory>` без чужих записей и усечённой последней строки. Приватный ID результата помещать на доску, payload хранить лишь в `<LAB_ROOT>/evidence/`. Если разрешения/доступа нет — `NOT TESTED` и сузить релизное утверждение, а не объявлять модель рабочей.
