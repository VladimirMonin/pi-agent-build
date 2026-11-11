# Polza для памяти и поиска истории

Не смешивайте четыре независимых пути:

| Назначение | Настройка |
|---|---|
| Основной агент `polza/<model-id>` | Динамический `pi-polza`, нативный `/login`, модель профиля/явные launch arguments |
| Консолидация Memory | Статический `polza-memory` в каждом `models.json` и `memory.consolidationModel` |
| Embeddings Memory | Отдельный `memory.embedding` в приватных settings; в существующем Polza-сценарии Qwen, 1024d |
| Поиск истории | Собственные config/index `pi-session-search`; FTS без embeddings, semantic mode отдельно |

Штатный сохранённый login для **main `polza`** не требует `.env`. Он не настраивает автоматически credential служебного provider, Memory embeddings или session-search. Успех любого из трёх вспомогательных путей не подтверждает основную модель.

Порядок получения ключа основного `polza` (по исходникам `pi-polza`): (1) сохранённый credential `/login polza`; (2) `POLZA_API_KEY` из окружения процесса — в том числе заполненный из `.env`; (3) не настроен → Pi сообщает provider unconfigured вместо 401. `.env` читается из **каталога запуска Pi** (`<cwd>/.env`; иной путь — `PI_POLZA_ENV_FILE`), не из каталога пакета. Переменные, заданные после старта Проводника/старого терминала, не видны уже запущенным процессам — перезапустите их.

Это не третий plugin. `polza-memory` — запись в штатном `models.json` Pi.

> В Memory1.6 Polza используется в двух независимых ролях: DeepSeek для консолидации (без изменения модели) и `qwen/qwen3-embedding-8b`,1024d для automatic vector recall через `memory.embedding`. Старый локальный Xenova384d удалён из patch; incompatible dimensions не сравниваются, upstream backfill обновляет vectors после restart. SQLite backup сделана до переключения. Подробнее: [memory fix](fixes/memory.md).

## Ключи Polza: все роли и ротация

Секрет упоминается в четырёх независимых местах — это разные роли, не дубликаты:

| Роль | Где хранится | Форма |
|---|---|---|
| Основной агент `polza` | `<PROFILE_DIR>/auth.json`, штатный `/login` | credential Pi (приоритет 1) |
| Основной агент, запасной путь | `POLZA_API_KEY` в окружении или `<cwd>/.env` | env-переменная |
| Статический `polza-memory` (консолидация) | `apiKey` в `<PROFILE_DIR>/models.json` | литерал или `!<credential-helper>` |
| Embeddings Memory | `memory.embedding.apiKey` в приватных settings | литерал (env-fallback у этого типа нет) |
| Поиск истории | `embedder.apiKey` в session-search `config.json` | литерал |

Headless-формат `auth.json` (когда `/login` недоступен): запись провайдера `"polza": { "type": "api_key", "key": "<LOCAL_SECRET>" }` в `<PROFILE_DIR>/auth.json`; файл — только для пользователя, не в Git и не в архивы. Проверка фактического маршрута — короткий запрос в новой сессии (§6 INSTALL_FOR_AGENTS), не наличие файла.

**Ротация ключа:** выпустите новый ключ в кабинете Polza, затем замените его во **всех** местах таблицы (`/login polza` заново, `models.json`, `memory.embedding`, session-search config, `.env` при использовании) и отзовите старый. Частичная замена оставляет тихо сломанный служебный маршрут.

## `memory.embedding` для памяти

Embedding-маршрут памяти живёт в приватных settings профиля (`memory.embedding`), отдельно от session-search. Поля (по исходникам `@samfp/pi-memory`): `type` (для Polza — `"openai-compatible"`), `model`, `baseUrl`, `dimensions`, `sendDimensions`, `apiKey`, плюс patch-поле `queryPrefix`:

```json
{
  "memory": {
    "embedding": {
      "type": "openai-compatible",
      "model": "qwen/qwen3-embedding-8b",
      "baseUrl": "https://polza.ai/api",
      "dimensions": 1024,
      "sendDimensions": true,
      "apiKey": "<LOCAL_SECRET>"
    }
  }
}
```

**Ловушки:** `baseUrl` — **без `/v1`** (пакет сам дописывает `/v1/embeddings`; лишний `/v1` даёт 404); для типа `openai-compatible` env-fallback у `apiKey` **нет** — только литерал (env есть лишь у `openai`/`mistral` через `OPENAI_API_KEY`/`MISTRAL_API_KEY`); `dimensions` должна совпадать с существующими векторами БД — одинаковая длина не делает разные embedding spaces совместимыми. Правило `queryPrefix` для Qwen — в [memory fix](fixes/memory.md#query-only-формат-qwen).

## Почему нужен статический provider

Memory использует служебный child с отключёнными extensions (версия пакета закреплена в manifest):

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

Stock Memory читает user-global memory settings из `~/.pi/agent/settings.json` даже в Task. `memory-windows-runtime` исправляет путь на `<PI_CODING_AGENT_DIR>/settings.json`; patch применяется отдельно к Code и Task. Project-local `<project>/.pi/settings.json` может переопределить обычные параметры `memory`/`pi-memory`, **но не приватные `memory.factProjectAliases`**: они читаются только из профиля. БД по умолчанию общая — `~/.pi/memory/memory.db`; profile-aware settings сами по себе не изолируют сохранённые факты.

### Проверка

В shell, где уже безопасно доступен настроенный credential:

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi --list-models
```

В списке должна быть `polza-memory/deepseek/deepseek-v4.1-flash`; listing не доказывает запрос/создание факта. Для разрешённой проверки на synthetic данных используйте новый уникальный факт и настоящую консолидацию, **не `memory_remember`**. Проверьте новую запись, source=`consolidation`, точный scope и автоматический контекст новой подходящей сессии с исключением чужого проекта. Старый повтор без новых фактов может быть дедупликацией. Не выводите всю БД; вызов модели может быть платным.

## Embeddings для session-search

Создайте локальный config из [`session-search.polza.example.json`](../config/session-search.polza.example.json):

```json
{
  "fusion": "semantic-only",
  "embedder": {
    "type": "openai-compatible",
    "baseUrl": "https://polza.ai/api",
    "model": "qwen/qwen3-embedding-8b",
    "dimensions": 1024,
    "sendDimensions": true,
    "apiKey": "<LOCAL_SECRET>",
    "modelPrefixes": {
      "qwen/qwen3-embedding-8b": {
        "queryPrefix": "Instruct: Given a web search query, retrieve relevant passages that answer the query\nQuery:",
        "documentPrefix": ""
      }
    }
  }
}
```

`modelPrefixes` обязателен: точный `model` должен иметь две string-prefixes, включая явные пустые строки; неизвестная/неполная запись даёт ошибку, не fallback. При обновлении дополните только эти поля в своём конфиге, сохранив секрет/endpoint/roots/прочие настройки. `semantic-only` не вызывает FTS и возвращает cosine; прежний `rrf` остаётся явным opt-in. [Форматы, preserving setup и Nemotron](fixes/session-search.md).

Без `embeddingsEndpoint` `pi-session-search` сам добавляет `/v1/embeddings`, итоговый endpoint — `https://polza.ai/api/v1/embeddings`. `sendDimensions: true` отправляет `dimensions: 1024`. Смена **модели или размерности** требует отдельного согласованного rebuild/reindex; одинаковая длина не делает разные embedding spaces совместимыми. Обычный update/cwd display fix не является такой миграцией.

Пути в этой сборке:

- Code: `~/.pi/session-search/config.json`;
- Task: `~/.pi/task/session-search/config.json` после [profile patch](fixes/session-search.md).

⚠ **Асимметрия путей:** конфиг Code живёт **вне** профиля, Task — внутри. Бэкап или перенос «профиля» Code не захватывает его session-search config — включайте этот путь отдельно (см. также [state-migration](state-migration.md#session-search)).

Config хранит API key как literal. Ограничьте доступ к файлу и не добавляйте его в Git. JSON записывайте в **UTF-8 без BOM**: `ConvertTo-Json | Set-Content` пишет UTF-16/BOM, который Pi читает не тем способом; используйте `[IO.File]::WriteAllText($path, $json, [Text.UTF8Encoding]::new($false))`. Не допускайте ключей, различающихся только регистром: JSON их различает, а PowerShell `ConvertFrom-Json` падает с «duplicated keys». Валидатор конфига: `node scripts/check-session-search-config.mjs <путь к config.json>` (0 — валиден, 3 — не настроен, 2 — ошибка записи). Для уже настроенного индекса начните с короткой проверки, без forced reindex:

```text
/session-sync
session_search(query="контрольный запрос", limit=3)
```

`/session-reindex` — отдельная операция: делает внешние embedding-запросы для истории, может занять время и стоить денег. Не запускайте её автоматически после установки или display fix. Сессии содержат private code/prompts; semantic mode допустим только при разрешённой передаче. Обычный startup/sync тоже учитывается по реальному lifecycle до запуска, не считается заведомо zero-cost.

## Риски

- Консолидация отправляет выбранные фрагменты диалога внешней LLM; embeddings отправляют извлечённый текст прошлых сессий внешнему endpoint.
- Memory передаёт полный consolidation prompt дочернему Pi через аргументы `pi -p <prompt>`. На Windows этот текст виден в command line процесса локальным средствам мониторинга, администраторам и software, собирающему process telemetry. Не считайте child process приватным каналом и не запускайте консолидацию над секретами, которые недопустимо раскрывать таким наблюдателям.
- `cost` в статической model config задан нулями и не отражает фактическое списание. В отличие от `pi-polza`, этот core route не ведёт нативный `cost_rub`.
- pi-memory молча пропускает consolidation при неверной модели/ключе; ориентируйтесь на `memory_stats` и runtime test, а не на отсутствие ошибки.
- Запуск без `POLZA_API_KEY` делает пример с env credential unavailable; приватный проверенный `!`-helper — альтернативный путь. Простой static-check не исполняет helper: подтвердите маршрут отдельным child Pi smoke.
- Не запускайте reindex одновременно из многих profile/child процессов; настройте `sync.disableForChild` при активных subagents.

## Удаление и откат

1. Удалите provider `polza-memory` из локального `models.json`.
2. Замените `memory.consolidationModel` на проверенный доступный core/static model либо удалите override; не оставляйте недоступный id.
3. При явном отказе от semantic mode удалите соответствующий embedder block. Действия с производным индексом/reindex — отдельно по версии и данным; не удаляйте исходную историю попутно.
4. Удалите `POLZA_API_KEY` из process/secret injection и literal key из session-search config.

Удаление provider/config не удаляет `memory.db`, sessions или search indexes. Их удаление — отдельная необратимая операция; сначала сделайте приватную backup и остановите Pi.
