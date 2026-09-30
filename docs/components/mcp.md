# MCP

## `pi-mcp-adapter` 2.36.0

### Назначение

Подключает MCP servers через один discovery/proxy tool вместо постоянного добавления всех schemas в context. Connections lazy по умолчанию; отдельные tools можно сделать direct.

### Установка

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi install npm:pi-mcp-adapter@2.36.0
```

Peer metadata package старше Pi `0.87.0`, поэтому совместимость подтверждается реальным MCP tool call, а не только startup banner.

### Опциональные server executables

Manifest объявляет три optional servers; adapter работает и без них. Все три версии закреплены точно. Для Fetch verifier проверяет наличие команды, но не запускает server ради неподдерживаемого `--version`; точную установленную версию подтверждайте через `uv tool list` или metadata Python-пакета. Ручная установка:

```bash
npm install -g @upstash/context7-mcp@3.2.2
npm install -g @brave/brave-search-mcp-server@2.0.85
uv tool install "mcp-server-fetch==2025.4.7"
```

`mcp-server-fetch==2025.4.7` требует Python `>=3.10`; `uv tool` может выбрать/установить совместимый managed runtime. Установка executable сама по себе не включает server: добавьте осознанную запись в MCP config. Пример сборки использует удалённый URL Context7, локальные commands для Fetch и Brave и placeholder Brave key; удалите неиспользуемые entries и никогда не оставляйте placeholder как будто это credential.

### Конфигурация и данные

Рекомендуемые sources по возрастанию приоритета: `~/.config/mcp/mcp.json`, `~/.agents/mcp*.json`, `<PROFILE_DIR>/mcp.json`, project `.mcp.json`, project `.pi/mcp.json`. Host-specific configs не загружаются при default `hostConfigDiscovery: "off"`.

OAuth хранится в OS credential store. Plaintext config credentials не публикуют. Output guard может сохранить большой text result во временный private file; этот файл всё равно содержит sensitive payload. Metadata-only protocol trace opt-in пишет `.pi/mcp-traces/` без raw args/results/URLs.

### Команды, tools и skills

- proxy tool `mcp`: search, describe, call, status, connect, install/auth actions;
- `mcpScript` — bounded JavaScript orchestration только MCP calls;
- optional per-server wrappers/direct tools;
- commands `/mcp`, `/mcp setup`, `/mcp-auth <server>`, `/mcp-trace` и generated MCP prompt commands;
- manual skill `mcp-scripting`.

### Риски

MCP server commands исполняются локально с правами пользователя; remote tools могут иметь destructive/paid side effects. `inheritEnv: true` передаёт child полный environment. Используйте `inheritEnv: false` и explicit env там, где возможно, но это не sandbox. Включайте `approveTools` для destructive/high-cost patterns. `mcpScript` тоже не isolation boundary.

### Проверка

1. `/mcp status` показывает configured servers без принудительного запуска lazy servers.
2. `mcp({search:"<capability>"})` возвращает cached/discovered tool.
3. Выполните один read-only вызов и проверьте result.
4. После disable/enable выполните `/reload` и подтвердите tool surface.

Repository verification трактует отсутствие optional command как warning. Context7 поддерживает `--version`; для Brave `--version` **не работает без API key** и пытается запустить server, поэтому verifier проверяет наличие команды и exact версию в глобальном npm `package.json`, не запускает сервер и не запрашивает ключ. Неверная версия установленного пакета является failure. Для `mcp-server-fetch` verifier проверяет только command resolution и не запускает server, поэтому не подтверждает exact installed version. Ни один probe не подтверждает MCP handshake, сеть, авторизацию, права API или корректность ответа; functional criterion остаётся реальный read-only tool call из пункта 3.

### Удаление/откат

```bash
PI_CODING_AGENT_DIR="<PROFILE_DIR>" pi remove npm:pi-mcp-adapter
```

Затем удалите только Pi-specific config/overrides и OAuth credentials для нужных servers. Shared `.mcp.json` может использоваться другими clients и не должен удаляться автоматически. Optional MCP server binaries удаляются отдельно.

```bash
npm uninstall -g @upstash/context7-mcp
npm uninstall -g @brave/brave-search-mcp-server
uv tool uninstall mcp-server-fetch
```

## Решение для кандидата Pi 0.99.1

`pi-mcp-adapter@2.36.0` **сохранён**. После остальных Windows/private gates последний WVM availability check configured gateway отказал `fetch failed`; это проверка parent harness, не протокольный диагноз кандидата. **Legacy SSE и streamable HTTP в отдельных candidate-конфигурациях NOT TESTED**: live endpoints не подтверждены, working configs/credentials не копировались. Cached 33 schemas не подтверждают handshake или tool result.

Для замены должны быть доказаны: единственный `/mcp`, lazy discovery/schema exposure, proxy/direct tools и `mcpScript`, auth без экспорта credentials, ошибки/output guard и реальные требуемые WVM tools на обоих transports. Паритет builtin по этим функциям **NOT TESTED**, эксперимент не запускался; два владельца `/mcp` не добавлялись. Официальная [документация 0.99.1](https://github.com/earendil-works/pi/blob/v0.99.1/packages/coding-agent/docs/mcp.md#configure-servers) описывает stdio/streamable HTTP, но не обещает legacy SSE. Это static contract, не наш runtime PASS.

Итог — **NO-GO для полного релиза/переключения**, bounded candidate branch может быть опубликована по отдельному разрешению владельца. Доказательства/риски: [доска](../plans/pi-0.99.1-execution-board.md), [матрица](../plans/pi-0.99.1-compat-matrix.md); сырые WVM результаты только в private evidence.
