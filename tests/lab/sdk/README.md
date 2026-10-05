# Pi 1.0.0 core SDK fixture — source only

`baseline.mjs` prepares a provider-free core test for a **fresh Windows Sandbox guest**. It is not a host launcher, VM boundary proof, plugin/Trace test or default subagent acceptance test.

## Required order

1. Host prerequisites must be ready; a feature result with `RestartNeeded=true` does not authorize a VM launch before the manual reboot.
2. An approved bounded host controller must bind an owned VM ID, its deadline and instance-specific cleanup. Run the existing dummy root+descendant capsule first and obtain independent review of its actual raw boundary evidence.
3. Only then install exact Pi **1.0.0** and its frozen offline core material in a new guest prefix. The host must not install/import candidate Pi to try this fixture.
4. The guest runner checks real VM identity, prepared input/source identities, root ACL and a sanitized allowlisted environment before invoking `runSdkBaseline({guestRoot, sdkRoot, role})` for `root` and an actual OS descendant. This module does **not** spawn that descendant or prove its absence after cleanup.

`guestRoot` is the newly owned `C:\PiLabVM-<32-lowercase-hex-run-id>` subtree. `sdkRoot`, executable, cwd and environment paths must remain beneath it. Each role creates a new `sdk-root` or `sdk-child` directory; old/partial state is not repaired. `NODE_OPTIONS` is refused. SDK and AI-peer package identities must both be exact 1.0.0; redirected paths are refused.

## Exact-version API migration

Published 1.0.0 SDK documentation and declarations use `ModelRuntime.create()` and the `modelRuntime` factory option. Historical 0.99.1 `AuthStorage`/`ModelRegistry` fixture options are not reused as if accepted by 1.0.0. Model network refresh is explicitly disabled. The local provider returns `SDK_BASELINE_DONE`, with one request, no user tools, no discovered resources, in-memory settings/session and synthetic guest-only auth/model-store paths.

The report records actual SDK/peer paths, executable, PID/PPID, cwd, selected non-secret environment and lifecycle events. Its scope is deliberately only **core SDK local mock**. Caller watchdog, natural process exits, exact parent/child linkage, host VM cleanup, installed-state verifier, Both profiles, plugins, Trace-off/on/off and default acceptance remain separate mandatory gates. Cleanup errors are fatal; there is no `process.exit()`, `unref()` or forced-exit success.

## Current status

**SOURCE PREPARATION ONLY; candidate SDK/VM execution NOT TESTED.** The host/guest SDK provisioning and dispatch entry point is not yet accepted. A source syntax/host-refusal result does not prove runtime compatibility. Do not invoke this fixture to bypass the required dummy/raw-review gate.
