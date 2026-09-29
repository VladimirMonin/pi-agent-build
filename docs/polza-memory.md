# Polza для памяти и поиска истории

В сборке Polza используется двумя независимыми путями:

1. `pi-session-search` отправляет embeddings модели `qwen/qwen3-embedding-8b`;
2. `@samfp/pi-memory` консолидирует диалог моделью `deepseek/deepseek-v4.1-flash` через статический provider `polza-memory`.

Это не третий plugin. `polza-memory` — запись в штатном `models.json` Pi.

> **Embedder памяти — не Polza.** Семантический поиск по фактам внутри `pi-memory` считает **локальная** модель `Xenova/paraphrase-multilingual-MiniLM-L12-v2` (384d, offline, без ключа), которую ставит patch `memory-windows-runtime`. Polza в `pi-memory` отвечает только за консолидацию фактов. Подробнее: [memory fix](fixes/memory.md).

## Почему нужен статический provider

pi-memory `1.5.0` запускает дочерний Pi так:

```text
pi -p <prompt> --print --no-extensions --no-tools --no-session --model <model>
```

`--no-extensions` отключает **динамический** provider `pi-polza`. Прежний статический `polza` из `models.json`, если он уже настроен, остаётся доступен дочернему процессу, но конфликтует по имени с динамическим provider в обычной Pi-сессии. Core Pi читает `models.json`; отдельное имя `polza-memory` делает служебный маршрут доступным без extensions и устраняет коллизию.

Дочерний процесс наследует `PI_CODING_AGENT_DIR` и окружение родителя. Поэтому `models.json` нужен в **каждом** профиле. Из примера ниже `POLZA_API_KEY` должен быть доступен до запуска Pi; альтернативно рабочий приватный `apiKey: "!<credential-helper>"` разрешается статическим provider и исполняется при запросе. Credential, сохранённый только для plugin provider `polza`, сам по себе не настраивает статический `polza-memory`.

## Консолидация memory

Скопируйте/объедините [`models.polza-memory.example.json`](../config/models.polza-memory.example.json) в `<PROFILE_DIR>/models.json`. Он объявляет:

```text
provider: polza-memory
base URL: https://polza.ai/api/v1
API: openai-completions
model: deepseek/deepseek-v4.1-flash
credential: $POLZA_API_KEY
```

В `settings.json`:

```json
{
  "memory": {
    "consolidationModel": "polza-memory/deepseek/deepseek-v4.1-flash"
  }
}
```

### Миграция со старого static provider `polza`

Если прежний `models.json` уже объявляет статический provider `polza`, не оставляйте его рядом с динамическим `pi-polza`: одинаковый provider id делает происхождение model ambiguous. В остановленном Pi:

1. переименуйте **только запись в `models.json`** из `polza` в `polza-memory`;
2. замените literal credential на `"$POLZA_API_KEY"` **либо сохраните уже проверенный приватный `!`-helper** (не публикуйте его путь/содержимое);
3. обновите `memory.consolidationModel` на полный id выше;
4. сохраните plugin `pi-polza` — его dynamic provider по-прежнему называется `polza`;
5. повторите изменение отдельно в Code и Task, затем проверьте `--list-models` и короткий ответ дочернего Pi с `--no-extensions --provider polza-memory --model deepseek/deepseek-v4.1-flash`. Перед изменением сохраните byte-for-byte backup `models.json`; не переносите `auth.json` или сам credential.

Stock pi-memory `1.5.0` читает user-global memory settings из `~/.pi/agent/settings.json` даже в Task. В этой сборке `memory-windows-runtime` исправляет путь на `<PI_CODING_AGENT_DIR>/settings.json`; patch должен быть применён отдельно к Code и Task. Project-local `<project>/.pi/settings.json` может переопределить обычные параметры `memory`/`pi-memory`, **но не приватные `memory.factProjectAliases`**: они читаются только из профиля. БД по умолчанию остаётся общей — `~/.pi/memory/memory.db`; profile-aware settings сами по себе не изолируют сохранённые факты.

### Проверка

```bash
POLZA_API_KEY="<SET_IN_CURRENT_SHELL>" PI_CODING_AGENT_DIR="<PROFILE_DIR>" \
  pi --list-models
```

В списке должна быть `polza-memory/deepseek/deepseek-v4.1-flash`. В Pi выполните `memory_stats`, затем в тестовой сессии с минимум тремя user messages — `/memory-consolidate`. Проверьте изменение stats, но не выводите содержимое всей БД. Вызов модели платный.

## Embeddings для session-search

Создайте локальный config из [`session-search.polza.example.json`](../config/session-search.polza.example.json):

```json
{
  "embedder": {
    "type": "openai-compatible",
    "baseUrl": "https://polza.ai/api",
    "model": "qwen/qwen3-embedding-8b",
    "dimensions": 1024,
    "sendDimensions": true,
    "apiKey": "<LOCAL_SECRET>"
  }
}
```

`pi-session-search` сам добавляет `/v1/embeddings`, поэтому итоговый endpoint — `https://polza.ai/api/v1/embeddings`. `sendDimensions: true` отправляет `dimensions: 1024`; изменение dimensions требует полного reindex, иначе старые и новые vectors несовместимы.

Пути в этой сборке:

- Code: `~/.pi/session-search/config.json`;
- Task: `~/.pi/task/session-search/config.json` после [profile patch](fixes/session-search.md).

Config хранит API key как literal. Ограничьте доступ к файлу и не добавляйте его в Git. После настройки:

```text
/session-reindex
/session-sync
session_search(query="контрольный запрос", limit=3)
```

Первый reindex делает внешние embedding-запросы для истории, может занять время и стоить денег. Сессии содержат приватный код и prompts; включайте semantic mode только если допустима их передача Polza.

## Риски

- Консолидация отправляет выбранные фрагменты диалога внешней LLM; embeddings отправляют извлечённый текст прошлых сессий внешнему endpoint.
- pi-memory `1.5.0` передаёт полный consolidation prompt дочернему Pi через аргументы `pi -p <prompt>`. На Windows этот текст виден в command line процесса локальным средствам мониторинга, администраторам и software, собирающему process telemetry. Не считайте child process приватным каналом и не запускайте консолидацию над секретами, которые недопустимо раскрывать таким наблюдателям.
- `cost` в статической model config задан нулями и не отражает фактическое списание. В отличие от `pi-polza`, этот core route не ведёт нативный `cost_rub`.
- pi-memory молча пропускает consolidation при неверной модели/ключе; ориентируйтесь на `memory_stats` и runtime test, а не на отсутствие ошибки.
- Запуск без `POLZA_API_KEY` делает пример с env credential unavailable; приватный проверенный `!`-helper — альтернативный путь. Простой static-check не исполняет helper: подтвердите маршрут отдельным child Pi smoke.
- Не запускайте reindex одновременно из многих profile/child процессов; настройте `sync.disableForChild` при активных subagents.

## Удаление и откат

1. Удалите provider `polza-memory` из локального `models.json`.
2. Замените `memory.consolidationModel` на проверенный доступный core/static model либо удалите override; не оставляйте недоступный id.
3. Удалите embedder block, чтобы вернуться к FTS5-only search, затем `/session-reindex`.
4. Удалите `POLZA_API_KEY` из process/secret injection и literal key из session-search config.

Удаление provider/config не удаляет `memory.db`, sessions или search indexes. Их удаление — отдельная необратимая операция; сначала сделайте приватную backup и остановите Pi.
