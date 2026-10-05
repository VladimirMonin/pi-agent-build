# Core SDK smoke

Minimal local mock for the exact version in `manifests/runtime.lock.json`. Use an explicit installed SDK path and a **fresh synthetic output directory outside Git**:

```powershell
& '<NODE_EXE>' tests/sdk/core-smoke.mjs '<SDK_ROOT>' '<FRESH_SYNTHETIC_DATA_DIR>'
```

The test imports the installed SDK and its same-version AI peer using their ESM entry points, disables discovery and model-network refresh, uses in-memory settings/session state and a synthetic local provider, then waits for `agent_settled` and natural process exit. `report.json` records identity, events, calls and cleanup failures. Existing output is not overwritten; no `process.exit()` or forced-exit success.

This proves only core SDK/local mock behavior. It does not prove profile extensions, real credentials, provider transport, memory embeddings, descendant acceptance or OS containment. Profile checks and current results are in the [readiness board](../../docs/plans/lab-readiness-board.md). Historical VM-only fixtures are not required for this smoke.
