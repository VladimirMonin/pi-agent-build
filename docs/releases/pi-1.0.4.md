# Pi 1.0.4 — core-only update

## Scope and target

Owner requested a minimal Pi-only update and image support in both build profiles and the installed profiles. Official npm `latest` metadata and the installed package both identify exact Pi **1.0.4** (MIT). Source baseline: `e630a5c`; candidate branch: `update/pi-1.0.4`.

No plugin, external-tool, Node/npm or Goal X setting updates. No reinstall of the already updated working Pi, no auth/session/memory migration, no paid provider requests, no publication or release tag.

## Delta → check

| Delta | Focused check |
|---|---|
| Pi pin 1.0.2 → 1.0.4 | Manifest/template agreement, repository verifier, core SDK local mock with actual installed 1.0.4 |
| Images sent to model | Explicit `images.blockImages: false`, `images.autoResize: true` in Code/Task |
| Terminal previews | Explicit `terminal.showImages: true`, `imageWidthCells: 60`, `images: "auto"`; preserve terminal progress |
| Existing plugin configuration | Package manifests, template package arrays and filters unchanged |
| Installed settings | Change only image-related fields, preserve other settings; restart/reload for running sessions |

## Results

- `scripts/verify.ps1 -RepositoryOnly -RepoRoot <REPO>`: PASS, failures 0 / warnings 0; schemas, exact Pi pin, Code/Task package arrays and disabled filters.
- `node tests/sdk/core-smoke.mjs <INSTALLED_SDK_ROOT> <FRESH_PRIVATE_OUTPUT>`: PASS on actual Pi/AI 1.0.4; one local mock response, `agent_settled`, network attempts 0, cleanup errors 0, natural exit 0.
- Image field assertions on both templates and both installed settings: PASS. Template package arrays/filters and all non-image template preferences unchanged except `lastChangelogVersion`; package/external-tool locks and Goal X preset unchanged.
- Public safety scan and `git diff --check`: PASS. Initial safety invocation without explicit `-Root` failed on Windows PowerShell parameter-default evaluation; corrected invocation with explicit repository root passed without script changes.

Prior 1.0.2 plugin evidence is historical, not fresh 1.0.4 acceptance. Terminal rendering requires a supported inline-image protocol; image settings do not add vision capability to a text-only model. Full plugin/live-provider/WVM transport acceptance is outside this focused update.
