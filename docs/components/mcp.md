# MCP: единственный adapter и удалённый Context7

Владелец MCP — `pi-mcp-adapter@5.3.2`. Code/Task сохраняют `extensions: ["-builtin:mcp"]`: builtin и adapter не должны одновременно обслуживать серверы. Действие подавления проверяется на целевом ядре, не предполагается из номера версии. Полный install идёт через [основной маршрут](../../INSTALL_FOR_AGENTS.md); [manifest](../../manifests/pi-packages.lock.json) владеет pin.

## Стандартный Context7

В новых Code и Task стандартная конфигурация — `<PROFILE_DIR>/mcp-adapter.json`:

```json
{
  "mcpServers": {
    "context7": {
      "url": "https://mcp.context7.com/mcp",
      "httpTransport": "streamable-http",
      "lifecycle": "lazy"
    }
  },
  "settings": {
    "scriptMode": false
  }
}
```

Это удалённый **Streamable HTTP** server, не npm executable. Local `npx`, `context7-mcp`, дополнительный Pi plugin или прокси не нужны. Сервис не имеет закреплённой npm-версии; фиксируются URL, клиент/протокол. `lazy` сохраняет доступность по требованию, не постоянное соединение. Для discovery adapter может кратко подключить сервер, получить tools и закрыть его; connected=0 не равно disabled.

Безключевой default **не содержит `headers`**, пустого Bearer или ссылки на отсутствующую переменную. Не обещайте безлимитный доступ: сервис может вернуть rate limit или потребовать auth. OAuth не является обязательным шагом базовой URL-установки.

Оба installer-а после package install вызывают [`scripts/ensure-context7.mjs`](../../scripts/ensure-context7.mjs), используя [`config/mcp-adapter.default.json`](../../config/mcp-adapter.default.json) и loader именно установленного adapter 5.3.2. Fresh defaults задают `scriptMode:false`; существующий пользовательский `true` сохраняется. Read-only configuration check: `node scripts/ensure-context7.mjs --profile-dir "<PROFILE_DIR>" --sdk-root "<INSTALLED_CORE_PACKAGE>" --check`. Это проверка effective configuration, не tools/call.

[`config/mcp.example.json`](../../config/mcp.example.json) — большой пример дополнительных servers, не файл для слепого копирования в профиль. Brave/Fetch и их credentials не включаются вместе с обязательным default Context7.

### Необязательный HTTP auth

Только если у пользователя действительно есть ключ и переменная доступна процессу Pi, добавьте в **локальную запись Context7**:

```json
{
  "headers": {
    "Authorization": "Bearer ${CONTEXT7_API_KEY}"
  }
}
```

Pinned adapter поддерживает env interpolation HTTP headers. Это фрагмент записи server, не весь config и не секрет для Git. Если переменной нет — не добавляйте поле. `env` stdio-сервера не заменяет HTTP header. Не создавайте новое хранилище ключей; используйте поддержанный механизм конфигурации/credentials. [Headers/auth адаптера](https://github.com/nicobailon/pi-mcp-adapter/blob/v5.3.2/docs/auth.md#headers-bearer-tokens-and-secret-commands), [schema полей](https://github.com/nicobailon/pi-mcp-adapter/blob/v5.3.2/docs/servers.md), [официальная установка Context7](https://github.com/upstash/context7#installation).

## Loader 5.3.2 и сохранение настроек

Adapter-specific settings/imports/overrides принадлежат `mcp-adapter.json`. На современном Pi файл `mcp.json` имеет **Pi-native** контракт: loader переводит только поддержанные servers, не произвольные adapter поля. Нельзя переносить туда `settings.scriptMode`, `lifecycle` и transport override в надежде на одинаковую семантику.

Основные layers в порядке возрастания приоритета:

1. `~/.config/mcp/mcp.json`, `~/.agents/mcp.json`, `~/.agents/mcp/mcp.json`.
2. `<PROFILE_DIR>/mcp.json` (Pi-native), затем `<PROFILE_DIR>/mcp-adapter.json`.
3. Явно opted-in ancestors; в cwd `.mcp.json`, `.pi/mcp.json` (Pi-native), `.pi/mcp-adapter.json`.

Ancestor discovery по умолчанию off, host-specific imports имеют собственные правила. Используйте **effective config штатного loader**, не вторую реализацию приоритетов и не проверку одного файла. [Точный контракт loader](https://github.com/nicobailon/pi-mcp-adapter/blob/v5.3.2/config.ts), [configuration](https://github.com/nicobailon/pi-mcp-adapter/blob/v5.3.2/docs/configuration.md).

При обновлении сохраняйте другие servers/imports/settings, действительные credentials, пользовательский Context7 URL/auth и явный disable. Не создавайте profile default поверх существующей shared записи с более высоким приоритетом. Отсутствующая настройка получает default; уже сделанный выбор пользователя не отменяется.

`PI_MCP_CONFIG_MODE=exclusive` **не входит в рабочие defaults/launchers**: он скрывает shared sources. Создание `mcp-adapter.json` само по себе не включает exclusive. Изолированный fixture может выбирать его по своему scope. Project trust/approval adapter-а сохраняются; не обходите их ради зелёного результата.

## Короткая функциональная проверка

1. В обоих профилях проверьте effective Context7 definition и единственного MCP owner. Панель `/mcp`/`/mcp-adapter` должна принадлежать adapter-у, не второму владельцу.
2. Обнаружьте tools через `mcp` search и прочитайте schema нужного tool. Выполните **`resolve-library-id` → версия библиотеки → `query-docs`** с коротким вопросом о публичной документации. Имена/аргументы — из schema, не догадка о prefix.
3. Проверьте полезный результат и завершение. URL, произвольный HTTP GET, server/tool listing и config validation сами по себе не live-вызов.
4. Network unavailable, auth required и rate limit — разные внешние результаты; default остаётся настроенным, независимая работа продолжается. Не заявляйте live PASS по конфигурации.

Этот путь нужен для решения, требующего актуальной внешней документации. При отказе используйте официальный первичный источник с нужной версией и указанием способа получения; опечатка/локальная ссылка не требуют сети.

## Дополнительные servers и диагностика

Локальные Brave/Fetch подключаются **отдельно**, только если нужны. Их версии/способ probes — в [external tools manifest](../../manifests/external-tools.lock.json). Binary availability не доказывает MCP handshake, auth или tools/call. Отсутствие локального Context7 CLI не является ошибкой remote readiness.

MCP commands исполняются с правами пользователя; remote tools могут иметь destructive/paid side effects. `inheritEnv: true` у stdio передаёт окружение child; `false` с explicit env уменьшает наследование, но не sandbox. Output guard может сохранить большой sensitive результат в private temp file. Это не разрешение на публикацию.

Adapter protocol trace — отдельный **opt-in metadata-only** канал: default caps `maxBytes: 262144`, `maxEvents: 10000`; не raw args/results/auth/URLs, не хранение по дням. `debug` stderr и `pi-trace-extension` — другие каналы. [Реальные ограничения хранения](../../instructions/SEC.public_repository.instructions.md#диагностика-и-хранение).

## Удаление и откат

Удаляйте только своё package/config изменение; shared `.mcp.json` может использоваться другими клиентами. После удаления adapter-а отдельно восстановите builtin, если он нужен. Credential cleanup и optional CLI uninstall — самостоятельные действия, не удаление всех shared серверов.

## Приёмка Context7 на Pi 1.4.0

Windows / Pi 1.4.0 / adapter 5.3.2: переиспользован один успешный public keyless MCP case через настоящий adapter — connect, discovery, describe обеих schemas, `context7_resolve-library-id`, `context7_query-docs`; получена документация React/useState. LLM не вызывалась. Отдельно real-loader configuration stage обоих installer-ов проверил fresh/repeat/custom override для Code и Task (15 config checks). Это **одна live chain**, не две профильные live-проверки; configuration-stage cases не выданы за полный package lifecycle install.

## Историческая приёмка Pi 1.3.0

### Почему Adapter остаётся владельцем

Pi 1.3.0 не предоставляет эквивалентный legacy SSE fallback; SSE внутри streamable HTTP не заменяет legacy SSE transport. Поэтому сохраняются единственный `/mcp`, `-builtin:mcp` в обоих профилях, `settings.scriptMode:false` в MCP template, existing shared configuration и direct-tool selection. Не включать builtin ради нового core и не переносить credentials/config автоматически.

В 5.3.2 межхостовые redirects отвергаются: используйте конечный URL сервера. На Windows `!command` при доступном Git Bash исполняется через него, поэтому синтаксис проверяется без вывода значений секретов. Старые OAuth credentials без issuer могут потребовать отдельной повторной авторизации; не назначайте issuer из недоверенной discovery и не экспортируйте keyring. Обновление SDK само по себе не доказывает безопасность всех старых credentials.

На actual installed Adapter5.3.2/coherent Pi1.3.0 в synthetic Code/Task проверены connect/discovery/search → describe с constraints → read-only proxy/direct calls. Выбранный tool доступен напрямую, другой остаётся proxy-only; scripting off. Exclusive fixture использует adapter-owned `mcp-adapter.json` (актуальный exclusive contract), не мигрирует working/shared MCP files. Server-only checks не заменяют этот runtime case; [команда и scope](../../tests/sdk/README.md). Последним техническим шагом independent reviewer проверил already-running WVM: Code-installed Adapter с explicit `httpTransport:"sse"`, Task-installed Adapter с explicit `httpTransport:"streamable-http"`; на обоих initialize/tools-list и discovered read-only `settings_schema` PASS. Это два owned SDK cases, не gateway и не полная матрица profile × transport; full-profile loading проверен отдельно. Schema bounded в памяти, HTTP resources probe освобождены после SDK shutdown; default output sizing/самостоятельный HTTP teardown и model/provider readiness не заявляются. Ни settings get/plan/apply/preview, ни запуск/остановка WVM не выполнялись. [Proof и limits](../releases/pi-1.3.0-build.1.md).


## Решение для кандидата Pi 0.99.1

**Текущий build.5:** adapter5.1.0 — единственный MCP owner, `-builtin:mcp` сохранён Both. Native actual installed Code/Task подключили shared WVM/Context7/Fetch/Brave без config migration. WVM `settings_schema` PASS Both; Code Context7 resolve, Fetch example.com и один Brave search PASS. WVM запускался через `run_debug.bat` и после smoke закрыт, port7558 closed. Историческая assessment ниже относится к2.36.0 и не описывает текущий статус.

`pi-mcp-adapter@2.36.0` ранее **сохранялся**. Последняя WVM assessment выполнена после private source-only query corrections, source review и doc/diff/safety gates: configured parent gateway connect33tools и read-only public `settings_schema` version1 PASS. Предыдущие `fetch failed` и прежние schema receipts сохранены как история; source/managed approval не открывает controlled native runner gate. Ни success, ни availability failure parent gateway не являются transport diagnosis кандидата. **Legacy SSE и streamable HTTP в отдельных candidate-конфигурациях NOT TESTED**: отдельно идентифицированные endpoints/configs не испытаны, working configs/credentials не копировались. Надпись gateway «legacy notification path» сама по себе не устанавливает MCP transport; public schema-call не доказывает builtin parity.

Для замены должны быть доказаны: единственный `/mcp`, lazy discovery/schema exposure, proxy/direct tools и `mcpScript`, auth без экспорта credentials, ошибки/output guard и реальные требуемые WVM tools на обоих transports. Паритет builtin по этим функциям **NOT TESTED**, эксперимент не запускался; два владельца `/mcp` не добавлялись. Официальная [документация 0.99.1](https://github.com/earendil-works/pi/blob/v0.99.1/packages/coding-agent/docs/mcp.md#configure-servers) описывает stdio/streamable HTTP, но не обещает legacy SSE. Это static contract, не наш runtime PASS.

Итог — **NO-GO для полного релиза/переключения**, bounded candidate branch может быть опубликована по отдельному разрешению владельца. Доказательства/риски: [доска](../plans/pi-0.99.1-execution-board.md), [матрица](../plans/pi-0.99.1-compat-matrix.md); сырые WVM результаты только в private evidence.
