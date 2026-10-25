# Pi 1.4.0 build.4 — строгие форматы embeddings и чистый смысловой поиск

Дата: 2026-10-25. Новый выпуск после [build.3](pi-1.4.0-build.3.md), без переноса прежнего tag. Формат тега: `pi-v1.4.0-build.4`. Все runtime/package pins сохранены: Pi1.4.0, Node25.8.1, npm11.11.0, Session Search1.6.0, Memory1.6.1 и Polza0.2.2. Основной срез — patch Session Search, его тесты, безопасный пример и документация; Memory query-only fix build.3 остаётся неизменным. В обоих public safety scanners адресно устранено ложное срабатывание на unquoted программную ссылку при сохранении прежнего ключа; такая же строка в кавычках по-прежнему отвергается regression-тестом. Ни секрет, ни новый credential этим исключением не разрешаются.

## Что исправлено

- Обязательный `embedder.modelPrefixes[точный model ID]` с двумя строками `queryPrefix` / `documentPrefix`. Явные `""` разрешены; отсутствие записи, неверные типы и неизвестный ID отвергаются до embedding HTTP. Нет substring/family/lowercase угадывания и молчаливой передачи raw текста.
- Общий resolver/formatter source/main/worker. Индексатор готовит документ перед `embedBatch`, вопрос перед `embed`; провайдер не форматирует повторно. Прежние отдельные `embedder.queryPrefix/documentPrefix` заменены записью mapping.
- Отдельный default `fusion: "semantic-only"`: фактический cosine score, без FTS-поиска и fusion, с project filter. Ошибка модели или отсутствие embedder не скрываются lexical fallback. Явные legacy `rrf`/`vector-primary` сохраняются; FTS без embeddings требует явного `rrf`.
- Мастер сохраняет весь существующий JSON и unknown fields, обновляя выбранные поля; показывает точный формат и подтверждает новую запись. Корневые пути, `fusion`, `sync` и остальные embedder-настройки не теряются из-за частичного save. Отмена не записывает конфиг.
- В существующий OpenAI-compatible transport добавлены optional API `input_type` и точный `embeddingsEndpoint`. API-роли допустимы только с пустыми текстовыми prefixes; двойная подготовка отвергается.
- Четыре точных Nemotron 3/3.5 HF ID и отдельно три подтверждённых hosted NIM request ID описаны в [каталоге](../../config/session-search.polza.example.json). [Первичные источники и ограничения маршрутов](../fixes/session-search.md#nemotron-четыре-модели-и-два-способа-передачи-роли). Пример по-прежнему выбирает Qwen, а не NVIDIA.

## Проверки до установки

На закреплённых Node25.8.1 / Python3.14.2 прошёл адресный запуск:

```sh
python -m unittest test_embedding_contracts test_runtime test_regression -v
```

Команда выполняется из `patches/session-search-profile/tests`; peer `SESSION_SEARCH_TYPEBOX` и private temp root настраиваются по [patch README](../../patches/session-search-profile/README.md#проверка-и-данные). Результат: **17 методов OK**. Покрыты точный mapping/empty/refusal, четыре Nemotron, loopback HTTP role/endpoint/no-double-prefix, фактические document/query input paths source/main/worker, cosine/no FTS/filter/error, preserving save/setup и guarded lifecycle. Exact build.3 bytes сохранены как historical state; переход, backup, идемпотентность, drift refusal и byte-exact restore проверяются отдельно от текущей семантики.

Независимый read-only reviewer принял исходник, реальный diff и generated source/main/worker; все семь frozen hashes совпали, существенных correctness/privacy/proof замечаний нет. Он повторил четыре контрактных метода и три выбранных native случая; это не новый полный runtime/model audit. При последующем изменении только docs/catalog source verdict не переатрибутируется.

## Рабочая установка — выполнена перед документацией

После освобождения reviewer-а, свежего exact Node/Pi argv holder check и проверки protected recovery выполнены штатные guarded apply: Code `--runtime-only`, Task profile-aware. Повторный check обоих пакетов вернул `patched`.

- **Code:** собственный прежний config дополнен mapping и `fusion: semantic-only`, остальные поля сохранены. Настоящий registered `session_search` в свежем installed SDK вызвал прежний Qwen/Polza1024d route. Неизменённый контрольный вопрос вернул ту же нужную сессию **первой из1293**, отображаемый cosine **32,1%**. Ни query, ни ID, ни содержимое результата не публикуются.
- **Task:** ранее глобального Search config/embedder не было. Создан только недостающий config того же Qwen/провайдера с отдельным profile index; остальные настройки не менялись. Normal SDK и настоящий search tool работают, но собственный индекс **пуст**. Это не доказательство качества поиска Task и не повод подмешивать Code sessions или запускать массовую индексацию.
- Normal installed extensions Code/Task загрузились через SDK без load/lifecycle errors, прежние основные provider/model selections сохранены. Main-model prompts и consolidation LLM не вызывались. Это не визуальная приёмка TUI.
- Все **1293 исходных Code vectors** сравнивались по opaque fingerprints: ни один не изменён, количество осталось1293; Task исходно и после проверки имеет0. Config/auth/settings/Memory runtime preservation проверены без публикации тел/секретов. Новые миграции, смена модели/размерности, ручной/массовый reindex не выполнялись.
- Штатный `verify.ps1 -Profile Both` с actual pinned Node/Python/Git завершился **failures=0, warnings=0**, patch checks Both приняты.

Первый проверочный SDK helper не инициализировал shared theme перед extension lifecycle: Code search уже прошёл контроль, но агрегат завершился ошибкой расширения. Диагностика без нового query установила причину; исправлен только helper штатным `initTheme`, production не менялся. Финальный Both прогон успешен. Итого два Code control embedding calls в этих попытках, из них один в финальном успешном прогоне; Task с пустым индексом embedding не запросил. Первый verifier выбрал bundled Git2.53 вместо установленного pinned2.54: повтор с process-local PATH к существующему правильному Git прошёл; Git не обновлялся, manifests не ослаблялись. Ранние ошибки не переименованы в PASS.

## Установка и совместимость конфига

Следуйте [короткому установочному маршруту](../../INSTALL_FOR_AGENTS.md). Patcher обновляет package, **не личный config**; preserving installer тоже не заменяет существующие файлы. При переходе с build.3 добавьте запись `embedder.modelPrefixes` для точного выбранного ID и, при желании чистого cosine, `fusion: "semantic-only"` поверх своих настроек. Сохраните credential, endpoint, model/dimensions, roots, sync и остальные поля. Не копируйте публичный пример поверх существующего конфига. После изменения `/reload` или новый запуск. Code/Task настраиваются раздельно; [подробный рецепт](../fixes/session-search.md#мастер-настройки-и-обновление-прежнего-конфига).

Для прежнего Qwen documentPrefix остаётся пустым: его исходный индекс не требует пересчёта. Для другой модели/размерности/document-формата совместимость не предполагается; пользователь управляет переиндексацией отдельно. Patcher принимает только точные известные состояния, включая `build3-patched`; unknown/mixed bundles отвергаются до writes. Package `--restore` возвращает stock package, но не настройки/данные; нужен собственный проверенный recovery. Публикация не заменяет установку у других пользователей; уже обновлённые Code/Task можно запускать.

## Границы результата

- **Nemotron:** выполнено публичное первичное исследование и parent readback четырёх pinned prompt configs, плюс синтетические transport/format tests. Веса не скачивались; NIM, LM Studio/GGUF, OpenRouter inference **не запускались**. Правила не являются полной native 3.5 template: она дополнительно экранирует `[`/`<` через U+200C; изображений этот текстовый patch не индексирует.
- OpenRouter `input_type` forwarding/remapping для NVIDIA не подтверждён, `:free` IDs не включены в готовый mapping. Бесплатные endpoints предупреждают о журналировании. Личная история не передавалась новым провайдерам.
- Hosted Nemotron3/8B route не подтверждён. Для 3.5/8B NIM2.4 matrix указывает2048, а HF/hosted reference4096: фактическую размерность нельзя угадывать.
- Один неизменённый контрольный вопрос — не гарантия полноты архива или качества всех запросов/моделей. Результаты build.2/build.3 остаются на своих версиях; untouched Memory/Trace/другие компоненты не получили новую live-матрицу.
- Native macOS/Linux, визуальный TUI и все внешние provider routes в этом ремонте не проверялись. Source ZIP содержит описание/исходники сборки, не offline runtime и не личные конфиги/сессии/БД/векторы. Top-level exact pins не гарантируют bit-for-bit transitive dependency tree.
