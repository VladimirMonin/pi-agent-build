# Схемы settings.json / auth.json / ключи памяти

Короткий справочник ключей, которые иначе вычитывают из исходников пакетов. Это **не полная схема** — полный список живёт в upstream-пакетах; здесь только то, что использует сборка.

## settings.json профиля (частные настройки)

| Ключ | Назначение |
|---|---|
| `defaultProvider`, `defaultModel`, `defaultThinkingLevel` | основная модель профиля (штатный `/model`, `/thinking`); уровни `off`/`minimal`/`low`/`medium`/`high`/`xhigh`/`max` — список ограничивает модель; дефолты сборки и почему `:1017` — в [заметке](notes/model-defaults.md) |
| `shellPath` | shell для tool-execution |
| `memory.consolidationModel` | `provider/model` консолидации; дефолт `polza-memory/deepseek/deepseek-v4.1-flash` — **дефолт, не инвариант**, допустим любой доступный id из `models.json` |
| `memory.embedding.*` | embedding-маршрут памяти: `type`, `model`, `baseUrl` (**без `/v1`**), `dimensions`, `sendDimensions`, `apiKey`-литерал; у patch-а также `queryPrefix` — [подробно](polza-memory.md#memoryembedding-для-памяти) |
| `memory.factProjectAliases` | приватные aliases проектов; читаются только из профиля |
| `packages` | список Pi-пакетов (состав — в [composition](components/composition.md)) |

Ключи `@samfp/pi-memory`, известные из исходников пакета (список может расти — сверяйте с пакетом): `localPath`, `lessonInjection`, `perTurnInjection`, `injectionMode`. Отдельной «модели для уроков» **нет**: уроки делает `consolidationModel`.

Переживают повторный Apply: installer сохраняет существующие settings и `models.json` (`preserved`/merge), ваши `defaultProvider`/`defaultModel`/`defaultThinkingLevel` не перезаписываются шаблоном.

## auth.json (штатное хранение credential)

`<PROFILE_DIR>/auth.json` создаётся `/login`. Запись провайдера с API-ключом:

```json
{ "polza": { "type": "api_key", "key": "<LOCAL_SECRET>" } }
```

Headless-вариант — записать файл вручную с правами только пользователя. Не в Git/архивы; повторный `/login` предпочтительнее переноса файла между машинами. Проверка — короткий запрос в новой сессии, не наличие файла.

## models.json (static providers)

Служебный `polza-memory` для консолидации: имя, endpoint, `apiKey` (литерал или `!<credential-helper>`), список моделей. Поле `cost: 0` в шаблоне — заглушка и **не отражает фактическое списание**: нативный учёт `cost_rub` ведёт только динамический `pi-polza`.
