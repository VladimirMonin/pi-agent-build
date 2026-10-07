# SDK checks

## Memory1.6 native mock

`node tests/sdk/memory-smoke.mjs <SDK_ROOT> <SYNTHETIC_ROOT> code|task` uses the real installed Pi SDK and an exact Memory1.6 package in synthetic `code`/`task` profiles. All fixture writes stay outside Git; working profiles are rejected. It tests automatic provider/RRF recall, scoped aliases, ephemeral tool continuation and history/consolidation exclusion, ordered turns, real session ID and a Windows Node child with a synthetic CLI. No paid model/provider requests. Real Polza evidence is separate in [build.6](../../docs/releases/pi-1.0.4-build.6.md).

## Core SDK smoke

Minimal local mock for the exact version in `manifests/runtime.lock.json`. Use an explicit installed SDK path and a **fresh synthetic output directory outside Git**:

```powershell
& '<NODE_EXE>' tests/sdk/core-smoke.mjs '<SDK_ROOT>' '<FRESH_SYNTHETIC_DATA_DIR>'
```

The test imports the installed SDK and its same-version AI peer using their ESM entry points, disables discovery and model-network refresh, uses in-memory settings/session state and a synthetic local provider, then waits for `agent_settled` and natural process exit. `report.json` records identity, events, calls and cleanup failures. Existing output is not overwritten; no `process.exit()` or forced-exit success.

This proves only core SDK/local mock behavior. It does not prove profile extensions, real credentials, provider transport, memory embeddings, descendant acceptance or OS containment. Profile checks and current results are in the [readiness board](../../docs/plans/lab-readiness-board.md). Historical VM-only fixtures are not required for this smoke.
