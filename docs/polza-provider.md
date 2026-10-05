# Провайдер Polza AI (`pi-polza` 0.2.1)

## Назначение

`pi-polza` регистрирует Polza AI как нативный динамический provider Pi. Он получает каталог доступных chat-моделей, дополняет подтверждённые метаданные, поддерживает streaming/tool calls и учитывает фактический `usage.cost_rub` отдельно от долларового поля Pi.

## Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" \
  pi install https://github.com/VladimirMonin/pi-polza@cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139
```

Release `v0.2.1`: annotated tag object `a93589ecd0075d3f4c34eb1f13bda891c5983d8c` peels to commit `cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139`. Manifest/installer передаёт именно immutable commit `cbc8…`; tag object и имя `v0.2.1` хранятся отдельно как проверяемая release metadata. Это фиксирует top-level Git source, но не transitive npm tree. Требования: Pi `1.0.2` из manifest и Node.js не ниже `22.6`.

В 0.2.1 нативный RUB учитывается один раз по последнему `usage.cost_rub` после успешного ответа, независимо от задержки закрытия SSE после `[DONE]`. Ошибки, отмена и некорректная/отсутствующая стоимость остаются unknown; настоящий ноль сохраняется. Неудачное обновление баланса сохраняет последнюю сумму с пометкой `stale`, успешное снимает пометку; частота запросов не меняется. Проверенная граница — Pi **1.0.2**, не все версии 1.x. Evidence и ограничения: [build.3](releases/pi-1.0.2-build.3.md).

## Авторизация и данные

В интерактивном Pi:

```text
/login → Polza AI → Sign in with an API key
```

Pi сохраняет credential в профильном `auth.json`; сам plugin отдельный secret store не ведёт. Для headless допускается `POLZA_API_KEY`, но не записывайте значение в tracked `.env`, launcher или документацию.

Plugin кэширует OpenRouter enrichment в project-local `.pi/pi-polza-cache/`. Стоимость сессии хранится в session entries; background-subagent cost импортируется после завершения запуска. Эти данные могут раскрывать модели, стоимость и контекст запуска — не публикуйте живые session/trace artifacts.

## Команды и интеграции

| Команда | Назначение |
|---|---|
| `/polza-model-info` | лимиты, capabilities, цены и provenance текущей модели |
| `/polza-cost` | фактические рублёвые расходы и coverage |
| `/polza-balance` | баланс всего аккаунта |
| `/polza-refresh` | обновление Polza catalog и OpenRouter enrichment |

Модели выбираются через `/model` под provider id `polza`. Интеграция с `pi-subagents` опциональна: foreground cost входит в root total без attribution по имени, background cost импортируется по завершении.

## Риски и ограничения

- Каждый model/chat/balance вызов обращается к внешнему сервису; prompt и переданные tool context покидают машину согласно условиям Polza и выбранной upstream-модели.
- `/polza-balance` — баланс аккаунта, не стоимость одной сессии. Разницу баланса нельзя использовать как точный session cost.
- Неизвестная стоимость остаётся unknown/`partial`, а не превращается в `0 ₽`.
- Polza catalog — источник существования и тарификации; OpenRouter используется только для exact-id enrichment. `unknown` означает отсутствие доказательств.
- Долларовый `cost` Pi намеренно равен нулю; реальные рубли не смешиваются с USD.
- Полный live-тест background import не является гарантией релиза 0.2.1: эта ветка заявлена как offline-tested. Live acceptance новой сессии сообщена владельцем отдельно, не как полный background-live тест.

## Проверка

Без платного chat-вызова:

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi list
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi --list-models
```

После `/login`: `/polza-refresh`, `/polza-model-info`, `/polza-balance`. Платный smoke выполняйте осознанно коротким запросом и затем сравните `/polza-cost` с `Coverage: complete` либо документированным `partial`.

## Удаление и откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" \
  pi remove https://github.com/VladimirMonin/pi-polza
```

Затем удалите Polza credential через Pi `/login`/logout flow и при необходимости project cache `.pi/pi-polza-cache/`. Удаление plugin не удаляет прошлые session entries. Для отката версии установите конкретный предыдущий tag и снова проверьте catalog/auth/cost; не переключайте Git-install на плавающий branch.

`pi-polza` не заменяет статический provider `polza-memory`: причина описана в [Polza memory](polza-memory.md).
