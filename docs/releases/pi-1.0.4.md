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

Checks are pending at preparation time. Prior 1.0.2 plugin evidence is historical, not fresh 1.0.4 acceptance. Terminal rendering requires a supported inline-image protocol; image settings do not add vision capability to a text-only model. Full plugin/live-provider/WVM transport acceptance is outside this focused update.
