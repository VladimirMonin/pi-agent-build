# Провайдеры моделей

## `pi-ollama-cloud` 0.12.1

### Назначение

Нативный provider `ollama-cloud`: динамически получает модели с tool support, capabilities и context limits. Может добавить web search/fetch и usage footer без локального Ollama server.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:pi-ollama-cloud@0.12.1
```

### Конфигурация и данные

Credential задаётся через `/login → Use an API key → Ollama Cloud` либо `OLLAMA_API_KEY`. Конфигурация: `<PROFILE_DIR>/ollama-cloud.json`; project-local `.pi/ollama-cloud.json` имеет приоритет. Шаблон сборки отключает web tools и включает usage status. Cache web results хранит полный текст и URLs под `<PROFILE_DIR>/cache/pi-ollama-cloud/cache.json`; URLs с query secrets туда передавать нельзя.

### Команды, tools и skills

- команды: `/ollama-cloud-usage`, `/ollama-usage-status on|off`, `/ollama-webtools on|off`;
- при включении: `ollama_web_search`, `ollama_web_fetch`;
- catalog обновляется при startup, открытии `/model` и `pi update --models`; старой `/ollama-cloud-refresh` нет;
- отдельных skills пакет не поставляет.

### Риски

Web tools передают запросы Ollama Cloud и кэшируют результаты локально. Показанная per-token стоимость — сопоставимая оценка по pricing page, а не фактический счёт subscription. Новые catalog IDs могут временно иметь нулевую цену. Live catalog требует сеть и credential; fallback catalog может устареть.

### Проверка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi --list-models
```

После `/login` вызовите `/ollama-cloud-usage`; при включённых web tools выполните один безопасный search без секретов. Для сборки ожидается `webTools: false`.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:pi-ollama-cloud
```

Удалите credential через Pi, config и cache отдельно. Для отката установите точную прежнюю версию, не `latest`.

## `pi-polza` 0.2.1

### Назначение

Нативный динамический provider Polza с реальным рублёвым `usage.cost_rub`, model provenance, streaming и integration с subagents.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" \
  pi install https://github.com/VladimirMonin/pi-polza@cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139
```

### Конфигурация и данные

Credential — Pi `/login` или `POLZA_API_KEY`; plugin не хранит отдельный ключ. OpenRouter enrichment cache находится в project `.pi/pi-polza-cache/`; cost state входит в session data.

### Команды, tools и skills

`/polza-model-info`, `/polza-cost`, `/polza-balance`, `/polza-refresh`; model provider виден как `polza`. Отдельных model-facing tools/skills пакет не регистрирует.

### Риски

Внешняя передача prompts, платные запросы, sensitive session cost. Баланс аккаунта не равен стоимости сессии; unknown cost не должен интерпретироваться как ноль. Стандартный Pi USD cost намеренно не используется.

### Проверка

`pi --list-models`, `/polza-refresh`, `/polza-model-info`, `/polza-balance`; платный smoke — только с явным бюджетом и последующей проверкой `/polza-cost`/Coverage.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" \
  pi remove https://github.com/VladimirMonin/pi-polza
```

Удалите credential/cache отдельно. Полная документация: [Polza provider](../polza-provider.md). Служебный static route описан в [Polza memory](../polza-memory.md).
