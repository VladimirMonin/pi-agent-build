# Pi 1.0.4 build.1 — core-only mini-release

## Scope and target

Owner requested a minimal Pi-only update and image support in both build profiles and the installed profiles. Official npm `latest` metadata and the installed package both identify exact Pi **1.0.4** (MIT). Source baseline: `e630a5c`; candidate branch: `update/pi-1.0.4`.

No plugin, external-tool, Node/npm or Goal X setting updates. No reinstall of the already updated working Pi, no auth/session/memory migration, no paid provider requests. Owner subsequently authorized commit/push and a repository mini-release: `pi-v1.0.4-build.1`.

## Delta → check

| Delta | Focused check |
|---|---|
| Pi pin 1.0.2 → 1.0.4 | Manifest/template agreement, repository verifier, core SDK local mock with actual installed 1.0.4 |
| Images sent to model | Explicit `images.blockImages: false`, `images.autoResize: true` in Code/Task |
| Terminal previews | Explicit `terminal.showImages: true`, `imageWidthCells: 60`, `images: "auto"`; preserve terminal progress |
| Existing plugin configuration | Package manifests, template package arrays and filters unchanged |
| Installed settings | Change only image-related fields, preserve other settings; restart/reload for running sessions |

## Release and update

Repository mini-release `pi-v1.0.4-build.1` contains only the core version pin, image settings and corresponding documentation. Use [setup](../setup.md) for a new installation. Existing settings are preserved by the installer: merge the image fields from the templates into your settings rather than replacing the whole file. Publishing this source does not upgrade someone else's installed Pi or plugins.

The owner's installed Pi was already 1.0.4; both installed profiles received the image settings in the preceding local update. Existing sessions/subagents should reload or restart. Inline terminal rendering was not visually tested.

## Results

- `scripts/verify.ps1 -RepositoryOnly -RepoRoot <REPO>`: PASS, failures 0 / warnings 0; schemas, exact Pi pin, Code/Task package arrays and disabled filters.
- `node tests/sdk/core-smoke.mjs <INSTALLED_SDK_ROOT> <FRESH_PRIVATE_OUTPUT>`: PASS on actual Pi/AI 1.0.4; one local mock response, `agent_settled`, network attempts 0, cleanup errors 0, natural exit 0.
- Image field assertions on both templates and both installed settings: PASS. Template package arrays/filters and all non-image template preferences unchanged except `lastChangelogVersion`; package/external-tool locks and Goal X preset unchanged.
- Public safety scan and `git diff --check`: PASS. Initial safety invocation without explicit `-Root` failed on Windows PowerShell parameter-default evaluation; corrected invocation with explicit repository root passed without script changes.

Prior 1.0.2 plugin evidence is historical, not fresh 1.0.4 acceptance. Terminal rendering requires a supported inline-image protocol; image settings do not add vision capability to a text-only model. Full plugin/live-provider/WVM transport acceptance is outside this focused update.
