# Сторонние компоненты

Репозиторий не вендорит установленные `node_modules`, Python environments, external binaries или модели. Ниже перечислены прямые top-level dependencies; источником версий являются `manifests/*.lock.json`, кроме отдельно отмеченного manual install target для Fetch. Это **не** transitive software bill of materials и не доказательство bit-reproducibility: перед распространением собранного bundle нужно зафиксировать полный dependency graph, сохранить все применимые license texts/notices и проверить hashes включённых artifacts.

Сторонний исходный код, который действительно хранится в `patches/`, документирован отдельно в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Pi runtime

| Компонент | Версия | Лицензия | Источник |
|---|---:|---|---|
| `@earendil-works/pi-coding-agent` | 0.87.0 | MIT | <https://github.com/earendil-works/pi> |

Лицензия и repository подтверждены metadata опубликованного npm package `0.87.0` (`gitHead` `16787ad5b2dc748047f314ca1bfe7708f30f54f3`).

## 15 Pi-пакетов

`common` содержит 12 пакетов, `codeOnly` — ещё 3; Code получает ровно 15, Task — 12.

| № | Компонент | Версия | Лицензия | Источник |
|---:|---|---:|---|---|
| 1 | `pi-ollama-cloud` | 0.12.1 | MIT¹ | <https://github.com/fgrehm/pi-ollama-cloud> |
| 2 | `pi-trace-extension` | 0.1.16 | MIT | <https://github.com/npxcnency-ux/pi-trace-extension> |
| 3 | `pi-context-inspector` | 1.3.0 | MIT | <https://github.com/yuriteixeira/pi-context-inspector> |
| 4 | `@juicesharp/rpiv-todo` | 2.10.1 | MIT | <https://github.com/juicesharp/rpiv-mono/tree/main/packages/rpiv-todo> |
| 5 | `pi-polza` | 0.2.1 | MIT | <https://github.com/VladimirMonin/pi-polza> |
| 6 | `pi-subagents` | 0.76.1 | MIT | <https://github.com/nicobailon/pi-subagents> |
| 7 | `pi-intercom` | 0.16.1 | MIT | <https://www.npmjs.com/package/pi-intercom/v/0.16.1> |
| 8 | `pi-background-tasks` | 2.6.2 | ISC | <https://github.com/ismailsaleekh/pi-background-tasks> |
| 9 | `pi-session-search` | 1.6.0 | MIT | <https://github.com/samfoy/pi-session-search> |
| 10 | `@samfp/pi-memory` | 1.6.0 | MIT | <https://github.com/samfoy/pi-memory> |
| 11 | `pi-mcp-adapter` | 5.1.0 | MIT | <https://github.com/nicobailon/pi-mcp-adapter> |
| 12 | `pi-goal-x` | 0.32.3 | MIT | <https://github.com/tmonk/pi-goal-x> |
| 13 | `@nicknisi/pi-ast-grep` | 0.2.0 | MIT² | <https://github.com/nicknisi/pi-extensions/tree/main/packages/ast-grep> |
| 14 | `@bacnh85/pi-serena` | 0.9.20 | MIT³ | <https://github.com/bacnh85/pi-extensions/tree/main/pi-serena> |
| 15 | `pi-cbm` | 1.2.1 | MIT | <https://github.com/alexykn/pi-cbm> |

¹ npm metadata `pi-ollama-cloud@0.12.1` не содержит поля `license`, но опубликованный tarball содержит MIT License; repository metadata указывает commit `81ba9009b68534e14ef6d16027765c8a14007ebe`.

² Metadata `@nicknisi/pi-ast-grep@0.2.0` декларирует MIT. Package также содержит notice для адаптированного кода `dannote/dot-pi`; этот notice нужно сохранять при redistribution самого package.

³ И npm tarball metadata, и immutable source `pi-serena/package.json` в опубликованном `gitHead` `b5330ac3d014f92dff97a2b90cd9ebdbf0de22fd` декларируют MIT. Tarball не содержит standalone LICENSE и не публикует copyright notice. Репозиторий фиксирует этот факт, не выдумывая attribution, в [`patches/serena-tools/LICENSE.upstream.txt`](patches/serena-tools/LICENSE.upstream.txt).

Для Git-пакета `pi-polza` release `v0.2.1` имеет annotated tag object `a93589ecd0075d3f4c34eb1f13bda891c5983d8c`, который peels to commit `cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139`; source `package.json` и `LICENSE` декларируют MIT. Manifest/installer закрепляет peeled commit `cbc8…`, а `tagObject`, `releaseTag` и version `0.2.1` остаются отдельной проверяемой release metadata.

## Внешние инструменты

| Компонент | Версия | Лицензия | Источник |
|---|---:|---|---|
| `@ast-grep/cli` | 0.45.3 | MIT | <https://github.com/ast-grep/ast-grep> |
| `serena-agent` | 1.7.0 | MIT | <https://github.com/oraios/serena> |
| `codebase-memory-mcp` | 0.11.0 | MIT | <https://github.com/DeusData/codebase-memory-mcp> |

License identifiers подтверждены npm metadata для `@ast-grep/cli@0.45.3` и `codebase-memory-mcp@0.11.0` (CBM npm `gitHead` `8972ea69c6ad94b1ef1d4ffbf0a92d78d2db1798`) и metadata/classifiers точного PyPI release `serena-agent==1.7.0`.

Git, Node.js, npm, Python, `uv`, PowerShell и Windows являются prerequisites среды и распространяются по собственным лицензиям поставщиков; этот репозиторий их не включает.

## Опциональные MCP servers

| Компонент | Версия | Лицензия | Источник |
|---|---:|---|---|
| `@upstash/context7-mcp` | 3.2.2 | MIT | <https://github.com/upstash/context7> |
| `@brave/brave-search-mcp-server` | 2.0.85 | MIT | <https://github.com/brave/brave-search-mcp-server> |
| `mcp-server-fetch` | 2025.4.7 | MIT | <https://pypi.org/project/mcp-server-fetch/2025.4.7/> |

License identifiers подтверждены metadata соответствующих npm/PyPI releases. `mcp-server-fetch==2025.4.7` требует Python `>=3.10`. Эти servers не обязательны; отсутствие optional command является warning при verification, если пользователь не запросил/не настроил server. Для Fetch verifier проверяет наличие команды, а не запускает server ради версии; точная установленная версия подтверждается metadata среды `uv tool`/Python package manager. Их запуск может передавать запросы внешним сервисам и подчиняется условиям соответствующих API отдельно от open-source license.

## Сервисы и модели

Polza AI, Ollama Cloud, OpenRouter enrichment, Brave Search и модели, доступные через providers, являются внешними сервисами. Наличие open-source client не предоставляет права на model weights, API content или third-party outputs. Пользователь отдельно проверяет условия сервиса, privacy, data retention, тарифы и допустимость отправки исходного кода/сессий.

`qwen/qwen3-embedding-8b` и `deepseek/deepseek-v4.1-flash` указаны как удалённые API identifiers; веса не включены, и этот репозиторий не переопределяет model licenses.

## Локальные исправления

Собственные patchers/tests/docs лицензируются корневой MIT license. Но pristine copies, source excerpts, modified payloads и сгенерированные patched package files сохраняют upstream terms. Точное file-level происхождение, npm tarball paths, опубликованные `gitHead`, SHA-256 и license texts приведены в [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) и пяти patch-local `NOTICE.md`/`LICENSE.upstream.txt` pairs.

Runtime backups, созданные patchers, могут содержать upstream source и пользовательские пути; их нельзя публиковать как часть репозитория или отдельно без privacy review и соблюдения upstream license.
