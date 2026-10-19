# SDK checks

All commands require an explicit installed SDK and owned synthetic roots outside Git. Set the existing allowlisted child environment **before imports**: private HOME/USERPROFILE/appdata/TEMP, npm/uv/cache, profile/session/archive/Goal/Trace/Intercom/MCP routes. Do not inherit provider credentials or NODE_OPTIONS. These are local mocks, not OS containment or paid-provider acceptance. Fresh case directories are never repaired/reused as successful runs.

## Core and connected qualifications

```text
node tests/sdk/core-smoke.mjs <SDK_ROOT> <FRESH_CASE_ROOT>
node tests/sdk/core-smoke.mjs <SDK_ROOT> <FRESH_CASE_ROOT> <INSTALLED_SYNTHETIC_PROFILE> coordination
node tests/sdk/core-smoke.mjs <SDK_ROOT> <FRESH_CASE_ROOT> <INSTALLED_SYNTHETIC_PROFILE> goal
node tests/sdk/core-smoke.mjs <SDK_ROOT> <FRESH_CASE_ROOT> <INSTALLED_SYNTHETIC_PROFILE> polza
node tests/sdk/core-smoke.mjs <SDK_ROOT> <FRESH_CASE_ROOT> <INSTALLED_SYNTHETIC_PROFILE> profiles
node tests/sdk/core-smoke.mjs <SDK_ROOT> <FRESH_CASE_ROOT> <INSTALLED_SYNTHETIC_PROFILE> cli
```

The original core fixture verifies the manifest version, every installed internal dependency edge (including telemetry), real SDK import, one deterministic model turn, `agent_settled` and cleanup. Internal Pi dependencies must be exact and coherent; CLI version alone missed the former1.0.4/caret graph failure. The third/fourth arguments extend this same fixture through focused helpers, not another runner:

- **coordination:** installed Subagents0.79.1 → Goal0.32.3 → Intercom0.17.1; actual detached native child asks supervisor and returns useful output. Intercom send/receipt shares one parent wake with that supervisor exchange. The child holds its authorized final response until the joint supervisor/message exchange has injected Intercom content and the parent is idle. Only then is the joint wake count checked. Completion is released in a separate phase; its actual notice/run ID and idle wake are recorded independently. Counts come from phase-tagged event records, not a presumed completion slot or subtraction. A foreign SDK session cannot resume the live run. The same check also runs in a genuinely separate Node/Pi SDK process: internal `ownership` qualification of this same `core-smoke.mjs`, same saved session UUID, byte-copy of synthetic context (not two writers of one session file), explicit live-run refusal, PID/PPID/SDK/exit receipts. Original child subsequently completes and resumes normally. Ask/reply, new output on resume with prior bytes intact, client/extension restart state and no live-owner transfer are asserted. Both initial/resumed child receipts measure PID/PPID, real process entrypoint path/hash, SDK entry/package path/version/hash and identity of the active SessionManager constructor against the imported candidate SDK class. An env host echo alone cannot satisfy these assertions; wrong-class/hash negative controls are rejected. Process exit is measured. RPC uses a synthetic no-op UI context to model an idle long-lived parent; it is not visual TUI evidence. `PI_PACKAGE_DIR` and `PI_SUBAGENTS_PI_CODING_AGENT_PACKAGE_ROOT` must point to the candidate SDK. The child provider is deterministic and never calls a model service.
- **goal:** real installed Goal core through its upstream debug hook, normal user turn, rejected stale custom checkpoint, native authorized continuation after resume, provider abort versus genuine Stop, and durable completion through an explicitly injected offline auditor. No Goal setting changes and no paid auditor. Do not fabricate a generation/dispatch to authorize completion.
- **polza:** pinned production Polza stream and actual Pi1.3 AI compat transport; synthetic SSE reasoning/tool JSON/usage, `[DONE]` before delayed EOF, RUB accounting exactly once and never in USD. This adapts the old upstream `tests/stream-native.test.ts` locator, not production provider code.
- **profiles:** full installed Code/Task combination, Session Search actual workers over owned synthetic source/config/index, default Code/Task config/index root assertions, configured own/archive/extra session search/read and outside-path rejection; Trace off → explicit opt-in → off, JSONL/HTML and canonical settings unchanged. Set `PI_TRACE_PYTHON` to an explicit installed Python executable. Memory consolidation in this full-profile fixture uses an owned synthetic CLI, never a model-service child. Worker error/exit is observed; upstream service disposal uses `worker.terminate()`, whose exit1 is not a crash or a forced test-success exit.
- **cli:** actual bundled candidate CLI children with an explicit allowlisted environment. Terminal output-limit stimulus uses `maxTokens:128`, `usage.output:128`, `totalTokens:129`, `contextWindow:65536` and balanced stream events. Bare `-p`, explicit text and resumed terminal turns assert only the current partial, a real truncation warning and exit1, with no timeout/signal or stale `activeTools` JSON. JSON asserts one current length response, no context edits/recovery/compaction/retry and normal settlement; its exit0 is the JSON contract, not text-mode failure evidence. Normal/persisted-tools resume remains separately asserted. This corrected terminal discriminator PASS does not accept the older early-length recovery observation: output2 below max128 selected recovery/omission, not terminal output-limit behavior; those old FAIL receipts remain unchanged. Both production print implementations remain stock; whole-campaign/release acceptance is separate.

Independent Pi 1.3.0 release acceptance reran Memory Both, nine pre-import profile guard negatives, gated coordination with actual initial/resumed SDK identities and all six stock bundled CLI cases. Unchanged Goal/Polza/Adapter/full-profile receipts retain their original scope. Final WVM qualification used the installed Code Adapter via explicit legacy SSE and the installed Task Adapter via streamable HTTP, discovering tools before a schema-only call. These were two owned SDK probes, not a four-cell matrix or live-provider proof; bounded schema handling and probe-owned HTTP teardown do not qualify default output sizing or standalone HTTP shutdown. See [release scope](../../docs/releases/pi-1.3.0-build.1.md).

Reports and raw failures stay in the fresh case roots. Sessions shut down explicitly; no test calls `process.exit()` to manufacture success. WVM/live auth/model calls and browser UI are separate gates.

## Profile loading and synthetic MCP seam

```text
node tests/sdk/profile-loading.mjs <SDK_ROOT> <SYNTHETIC_PROFILE>
node tests/sdk/profile-loading.mjs <SDK_ROOT> <SYNTHETIC_PROFILE> <FRESH_MCP_FIXTURE_ROOT>
```

Default mode retains the no-model full-profile loading check. Optional mode loads only the installed Adapter5.3.2 into a new synthetic profile, not a second factory instance after canonical loading. Use `PI_MCP_CONFIG_MODE=exclusive`: in5.3.2 this mode reads the adapter-owned **mcp-adapter.json**, not shared mcp.json. Working/shared configs and credentials are not migrated.

`fixtures/mcp-server.mjs` is a dependency-free actual stdio child. A deterministic model drives connect → search → describe (including argument constraints) → read-only proxy call → selected direct-tool call. An unselected tool stays proxy-only, scripting stays off; semantic proxy errors are failures even if the Pi wrapper says `isError:false`. `report.json` records reached stage/results/cleanup. Server-only checks are not Adapter runtime acceptance; this is not WVM transport proof.

## Memory1.6.1 native mock

```text
node tests/sdk/memory-smoke.mjs <SDK_ROOT> <FRESH_SYNTHETIC_ROOT> code <INSTALLED_SYNTHETIC_CODE_PROFILE>
node tests/sdk/memory-smoke.mjs <SDK_ROOT> <FRESH_SYNTHETIC_ROOT> task <INSTALLED_SYNTHETIC_TASK_PROFILE>
```

The optional fourth argument selects the installed synthetic profile; otherwise the fixture uses `<root>/code|task`. Before SDK/Memory imports or settings I/O, the Windows fixture validates the actual profile and case against the SDK's owned lab root, reusing `Assert-PrivateLabRoot` and `Assert-StandAncestors` (metadata only), including ancestors/Git/reparse policy and settings-file type/link checks. A valid installed profile may be a sibling of the case tree, not its child. Sacrificial external/working/Git/traversal/junction controls must refuse before imports/settings access; actual installed Code/Task must pass and restore settings bytes. It temporarily supplies synthetic embedding settings and restores the original bytes. It tests automatic local-provider/RRF recall, scoped aliases, whole records, ordered consolidation/real session ID and a Windows Node child with a synthetic CLI. The connected lifecycle is user recall → same block in tool continuation → custom without search/block → empty prompt and real SQLite search failure without stale block → fresh user recall → session-switch reset. Error injection renames/restores a table only in the DB this case created. No working DB, model/dimensions migration, paid requests or personal reindex. Historical live-provider evidence remains separately scoped in [build.6](../../docs/releases/pi-1.0.4-build.6.md).
