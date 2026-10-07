# Third-party source notices

This file covers third-party source code stored in `patches/`. Installed packages, external tools, and optional MCP servers are catalogued separately in [`THIRD_PARTY.md`](THIRD_PARTY.md).

The root [`LICENSE`](LICENSE) applies to original repository material and to locally authored modifications. It does **not** relicense upstream source. Exact upstream copies, quoted source anchors, modified derivatives, and generated patched outputs retain the upstream terms identified below.

## Vendored and derivative files

| Patch | Upstream artifact | Files covered | License evidence and exact provenance |
|---|---|---|---|
| `memory-windows-runtime` | `@samfp/pi-memory@1.6.0`, npm `gitHead` `65dd9b5e89c0c9c9374614be5990073545c87ab7` | `stock-index.js`; upstream excerpts in `apply.py`; generated patched `dist/index.js` | [notice](patches/memory-windows-runtime/NOTICE.md), [upstream license](patches/memory-windows-runtime/LICENSE.upstream.txt) |
| `pi-cbm-011` | `pi-cbm@1.2.1`, npm `gitHead` `921a749d5cea74bda8f647542627ef9518fec272` | `store/client.ts.orig-1.2.1`; matching anchors in `apply.py`; generated patched `client.ts` | [notice](patches/pi-cbm-011/NOTICE.md), [upstream license](patches/pi-cbm-011/LICENSE.upstream.txt) |
| `serena-tools` | `@bacnh85/pi-serena@0.9.20`, npm `gitHead` `5388a5f1987873fe1355064f72021452c4347c72` | `store/{index,guidance}.ts.orig-0.9.20`; generated patched `extensions/index.ts` and `extensions/lib/guidance.ts` | [notice](patches/serena-tools/NOTICE.md), [upstream license declaration](patches/serena-tools/LICENSE.upstream.txt) |
| `session-search-profile` | `pi-session-search@1.6.0`, npm `gitHead` `5a910e7c3a238d347e90020147815227b567b85e` | four files under `store/1.6.0/`; generated patched files; worker unchanged | [notice](patches/session-search-profile/NOTICE.md), [upstream license](patches/session-search-profile/LICENSE.upstream.txt) |
| `trace-ru-windows-profile` | `pi-trace-extension@0.1.16`, npm `gitHead` `5441bcca041e3b3a203aee91c68e8ea809e6aa27` | all six files under `payload/`; patched installed copies and rebuilt `viewer/assets.json` | [notice](patches/trace-ru-windows-profile/NOTICE.md), [upstream license](patches/trace-ru-windows-profile/LICENSE.upstream.txt) |

Each linked notice maps every source-bearing repository file to the exact npm tarball path and records its SHA-256. Four upstream tarballs include an MIT license file, reproduced locally. `@bacnh85/pi-serena@0.9.20` instead declares `"license": "MIT"` in both the published tarball metadata and immutable source `package.json`, but publishes no package LICENSE file or copyright notice; its notice records that limitation without inventing attribution.

Project-authored patchers, tests, and documentation are identified file by file in those notices. Generated `__pycache__/` files are not source artifacts and should not be included in a release archive.

## Redistribution rule

When redistributing this repository or a source/binary bundle produced from it:

1. keep the root `LICENSE` for original project material;
2. keep this file, `THIRD_PARTY.md`, and every linked patch `NOTICE.md`/`LICENSE.upstream.txt`;
3. preserve package-level notices supplied by installed dependencies and regenerate notices for transitive dependencies included in the bundle;
4. do not treat the root MIT license as permission for external services, model weights, user data, or dependencies under other terms.
