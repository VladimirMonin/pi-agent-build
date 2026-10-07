# Pi 1.0.4 build.5 — MCP Adapter 5.1.0

Tag: `pi-v1.0.4-build.5`. Только `pi-mcp-adapter` **2.36.0 → 5.1.0** в Code/Task; Pi1.0.4 и остальные pins неизменны. Adapter — единственный MCP owner, `-builtin:mcp` сохранён. Existing shared config/keys не заменяются и не копируются в fixtures; config migration не потребовалась.

## Проверки и установка

- Candidate и actual installed fresh loading: **Code13/Task10, errors0/warnings0/fetch0**.
- Native actual installed5.1/Pi1.0.4, existing shared servers: **WVM/Context7/Fetch/Brave connect PASS** в Code/Task. WVM read-only `settings_schema` PASS Both. Code: Context7 resolve, Fetch `example.com`, один Brave web search PASS. Модельных calls нет; один внешний Brave search разрешён владельцем.
- WVM запущен именно `run_debug.bat`, после smoke собственное дерево процессов закрыто: **port7558 closed**. Код/данные WVM не менялись в рамках обновления.
- Штатный Pi lifecycle уже установил exact5.1 Both; настройки, shared config, другие package versions, models/Goal X settings и sampled patch bytes сохранены. Live smoke после установки выполнен до публикации по текущему порядку владельца.
- Repository verifier и safety/diff checks перед публикацией. Core-only и прежние неизменённые patch smokes не повторялись.

Полный visual MCP panel/OAuth flows, другие servers и transport variants **NOT TESTED**. Private receipts вне Git. Открытые пользовательские Pi-сессии требуют полного перезапуска владельцем; установка их не останавливает.
