# pi-memory 1.6.1: runtime, lifecycle и автоматический scoped recall

Целевой patch — `@samfp/pi-memory@1.6.1`, pristine SHA-256 `9517f79582b2ff71e510289c0e6d912744b3dc8a867aaa52758df371bd41891f` и canonical output. Распознавание установленного прежнего состояния перед replacement отделено от применения target patch: принимаются лишь конкретные известные hashes прежних опубликованных bundles. Неизвестные версии, mixed/marker-shaped изменения не перезаписываются.

## Что меняет patch

- Windows: child запускается текущим Node через настоящий Pi `cli.js` выбранного `PI_AGENT_BUILD_NPM_PREFIX`, не через `.cmd` shim.
- Session-local `pendingTurns`/`pushTurn`: консолидация сопоставляет реальные User/Assistant turns; helper остаётся в lexical scope pending arrays.
- Settings выбранного `PI_CODING_AGENT_DIR`, включая upstream `embedding` и `injectionMode`; DeepSeek-консолидация не меняется.
- Session ID из `ctx.sessionManager.getSessionId()`; source сессии получают lessons (facts upstream сохраняет как `consolidation`).
- Facts/lessons scope, приватные `memory.factProjectAliases`, section quotas и бюджет 8000 символов из целых записей.
- Один `projectFactScope()` определяет automatic recall, `memory_remember`, применение consolidation и допустимый префикс в consolidation prompt. `project.<current-scope>.<fact>` проверяется точно; дефис и подчёркивание не становятся alias автоматически. Чужая область отвергается с ожидаемым префиксом. Глобальные `pref.*`, `user.*`, `tool.*` сохраняют глобальность.
- Automatic injection вызывает upstream `searchMemory`: configurable embedder, hybrid/RRF, diagnostics и dimension-aware backfill. Stock1.6 automatic injection использует только FTS; patch возвращает vector recall.

Upstream ephemeral `context` hook сохранён: память доступна в tool continuation, но не добавляется в system prompt, session history или consolidation transcript.

Для Pi user/custom lifecycle block сбрасывается **в начале каждого нового run**, до проверки store/settings/prompt и до поиска; также сбрасывается на session start/before-switch. Только непустой `messageType:user` запускает свежий recall. Custom, пустой prompt и ошибка поиска не наследуют предыдущий block; `systemPrompt` не используется как search query. Внутри одного user-run block сохраняется между context/tool продолжениями. В служебных Goal/Intercom продолжениях при необходимости вызывайте явный `memory_search`. Это политика сборки, не универсальное требование SDK.

Upstream1.6.1 добавляет диагностику AWS credential_process; внешние embeddings уже были доступны в1.6.0. Rebase не меняет provider/model/dimensions и не разрешает backfill/reindex рабочих данных. Старый Xenova backend и его timeout patch удалены.

## Применение

Перед package replacement installer вызывает `--prepare-replace`, не target-only check. Для ручной read-only диагностики сначала используйте `--inspect-installed`:

```sh
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>" --inspect-installed
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>" --prepare-replace
```

Принимаются ровно пять version/hash состояний:

| Package/state | SHA-256 `dist/index.js` |
|---|---|
| 1.5.0 published stock | `b8d68f90bcdf4fa40b9a573c67f8ed19853d90e889e8c9ed2cf4021f50c6ce58` |
| 1.5.0 published patched (build.5) | `e3cf2b202f12c8053a769d23dd8f6e21e6088937d4bcbe83f44328401ee66ad2` |
| 1.6.1 stock | `9517f79582b2ff71e510289c0e6d912744b3dc8a867aaa52758df371bd41891f` |
| 1.6.1 previous canonical | `d05d1b54a59a69da08458d6a896be36fbc19286360642d1a0672169211c7d5a9` |
| 1.6.1 current canonical | `c4ba7cfd1a6bcbb5270092e4deb400b5ab32dc4f92840e428ce7cdcbf04d2fcd` |

`--inspect-installed` не пишет; `--prepare-replace` сохраняет проверенный bundle, package metadata и receipt с version/hash в `<PROFILE_DIR>/.pi-agent-build-backups/memory-windows-runtime/`, не патчит старую версию. Для 1.5.0 затем требуется штатный package replacement на 1.6.1 и target apply. Unknown version/hash отказывает **exit 2** без перезаписи.

```powershell
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>" --check
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>"
python patches/memory-windows-runtime/apply.py --agent-dir "<PROFILE_DIR>" --restore
```

Без явного mode выполняется apply. Target apply/check/restore требуют ровно 1.6.1: `--check` возвращает 0 для current canonical, 1 для known stock/previous canonical, 2 для unknown/fatal. Apply переводит stock/previous в current; current — no-op без нового backup. Installer распознаёт и сохраняет прежний bundle **до package writes**, затем проверяет target. Не применяйте target patch к произвольной старой версии и не обходите отказ полным reinstall. Backup bundle создаётся внутри выбранного профиля; restore возвращает byte-exact stock1.6.1, **не откатывает SQLite или настройки**. Для прежней версии сохранённая receipt связывает её metadata/hash с исходным bundle; rollback данных — отдельно.

## Backend и данные

В личных Code/Task выбран Polza `qwen/qwen3-embedding-8b`,1024d через upstream `memory.embedding`. Консолидация остаётся `polza-memory/deepseek/deepseek-v4.1-flash`. Без embedding config работает keyword fallback, не полноценный русский vector recall.

До смены живых vectors нужна согласованная SQLite backup API-копия вне Git. Старые384d и новые1024d **не сравниваются**; upstream backfill постепенно обновляет missing/wrong-dimension vectors. Одинаковая размерность не доказывает одинаковое embedding space: при такой смене нужен отдельный rebuild. Не удаляйте facts/lessons/events и не копируйте keys в public fixtures. Patcher сам SQLite/settings не изменяет. Полностью перезапустите старые Pi-сессии перед использованием новой версии.

## Проверки

Текущий ремонт требует fresh, known previous, current no-op и unknown refusal, а также scope cases (точный ключ, дефис/подчёркивание, чужой проект, явный alias, глобальные факты). Новая консолидация проверяется уникальным synthetic фактом без `memory_remember`: новая запись/source/scope и automatic recall в подходящей сессии, исключение в чужом проекте. Старые факты/повтор без новой записи этот case не закрывают. Фактический результат текущего запуска указывается в release evidence; исторический mock/canary ниже не переименовывается в новый live PASS.

Structural: `test-memory-{pushturn,pairing,embedder,sessionid,injection,settings-path}.mjs <patched-dist>`; lifecycle/drift: `python patches/session-search-profile/tests/test_runtime.py` и Windows script regressions.

В Pi 1.4.0 на Windows авторский `tests/sdk/memory-project-scope.mjs` подтвердил новый факт через обычный shutdown consolidation hook, source=`consolidation`, точный scope, recall своего/alias и исключение чужого проекта на **искусственной SQLite + synthetic HTTP**. Это не live paid proof. Все пять predecessor states и marker-preserving unknown refusal проверены native CLI. Restore возвращает target stock 1.6.1; старый backup 1.5.0 можно возвращать только после восстановления соответствующей версии package по receipt. Atomic install не обещается.

Native SDK с synthetic SQLite и local mock embedder (без платной LLM):

```text
node tests/sdk/memory-smoke.mjs <sdk-root> <fresh-synthetic-root> code <synthetic-code-profile>
node tests/sdk/memory-smoke.mjs <sdk-root> <fresh-synthetic-root> task <synthetic-task-profile>
```

Четвёртый аргумент задаёт уже установленный synthetic profile; без него fixture использует `<root>/code|task`. Windows fixture до imports/settings I/O проверяет фактический profile/case и ancestors существующими private-root/Git/reparse guards. Девять sacrificial controls отказывают без product imports/settings access; independent valid Code/Task runs восстановили settings byte-exact. Это не OS sandbox и не native POSIX proof. Runtime case directory должен быть fresh. Native sequence проверяет user recall → тот же block в tool continuation → custom без поиска/block → пустой prompt и реальный SQLite search failure без старого block → свежий user recall → session-switch reset. Рабочие профили не fixtures. Native smoke проверяет automatic recall, aliases/scope, ephemeral hook, ordered consolidation и настоящий Windows Node child со synthetic CLI, не DeepSeek provider. Real Polza Russian paraphrase canary описан в [build.6](../../docs/releases/pi-1.0.4-build.6.md).
