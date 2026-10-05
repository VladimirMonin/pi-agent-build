# Pi 1.0.2 build.1 — Windows release scope

Последняя stable **1.0.2** повторно подтверждена официальными npm и GitHub перед выпуском; manifest exact, без `latest` install. Два профиля: **Code / Task**. Обычная установка, без VM/native isolation frameworks. Выпуск и обновление рабочего runtime выполняются отдельно после final gates.

## Изменения

- Pi/AI **1.0.2**, прежние exact 15/12 profile packages и guarded patches.
- [Goal X](../goal-autonomy.md) сразу в сборке: **unlimited**, implicit continuation, tasks depth 2, независимый Auditor и read-only Oracle — `openai-codex/gpt-6.1-sol`/`high`. Auth не поставляется. По прямому запросу владельца такой же preset применён в живой Windows.
- [Trace](../trace.md) установлен/patched, **default-off**; проверенный одноразовый `pi -e` opt-in и возврат off без правки filters.
- Serena использует managed **Python 3.12.10**, исключая наблюдавшуюся PyYAML build failure на Python 3.14. PowerShell module cache перенесён в private TEMP.
- Репозиторий содержит core SDK synthetic smoke; private данные/receipts не публикуются.

## Actual acceptance

| Проверка | Результат / граница |
|---|---|
| Windows script regressions | **24/24 PASS** |
| Installer / installed-state fixtures | **17/17**, **8/8 PASS** |
| Core SDK | Pi/AI1.0.2, local mock, zero fetch, natural cleanup **PASS** |
| Code/Task loading | 13/10 default extensions, без load/lifecycle errors **PASS** |
| Functional tools обоих profiles | Todo CRUD, `get_goal`, synthetic memory remember/search **FTS**, subagent management **PASS** |
| Actual CLI/RPC descendants | Exact Pi/AI1.0.2, get_state/prompt/get_goal roundtrip, natural EOF exit0 **PASS** |
| Trace обоих profiles | 6 SDK + 6 CLI off→on→off, JSONL/HTML, natural exit **PASS** |
| Payloads / patches / repeat Apply | Both15/12 exact identities, canonical patches, real verified **NO-OP PASS** |
| Code tools | CBM17 / Serena29 stdio initialize+tools/list **PASS**, полный LSP/indexing NT |
| Independent review | **OK with notes**: read-only focused source+receipts, no concrete blocker in this scope |

Fresh published payload patch lifecycle также проверен source-only: Code5/Task3 contexts, 96 actions, guards/refusals/restore; это не заменяет runtime checks. Родитель проверил полные functional/RPC receipts; независимому reviewer часть больших JSON была доступна только в truncated view, поэтому он не подтвердил каждый detail самостоятельно.

## Ограничения и безопасность

- **NOT TESTED:** semantic embeddings (cold HF download blocked, FTS fallback), real paid providers, полное native subagent execution, browser/dashboard UI, native Linux/macOS, machine-B portability и OS containment. Ничего из этого не заявлено PASS.
- `pi-mcp-adapter` **KEEP**. Candidate WVM SSE / HTTP оцениваются отдельно последним техническим этапом; parent gateway не protocol proof. Результат будет записан до публикации.
- npm bulk advisory по 117 установленным core packages: critical не найден. В общей profile closure найден `protobufjs6.11.6` / [GHSA-xq3m-2v4x-88gg](https://github.com/advisories/GHSA-xq3m-2v4x-88gg): codegen при **untrusted schema/JSON descriptor**. Наблюдаемый consumer — `onnx-proto`, importing `protobufjs/minimal` и trusted compiled schema, не reflection descriptor loader. Advisory прямо исключает trusted-schema message decoding; этот precondition в проверенном embedding route не найден. Не загружайте untrusted protobuf schemas; dependency не заменялась принудительным override/bypass. Известный transitive advisory не скрыт.
- Личные auth, memory/DB и sessions не являются fixtures и не копируются. Live Core update разрешён последующим прямым запросом владельца, с executable backup и отдельной проверкой; Goal preset уже применён независимо от него.
