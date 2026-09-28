# Third-party source notice: `@samfp/pi-memory` 1.5.0

- Upstream package: `@samfp/pi-memory@1.5.0`
- Upstream repository: <https://github.com/samfoy/pi-memory>
- Published npm tarball: <https://registry.npmjs.org/@samfp/pi-memory/-/pi-memory-1.5.0.tgz>
- Published `gitHead`: `9b163d53b45c5f1e082bbae57828ba7fb1325fc8`
License evidence: the versioned tarball contains `package/LICENSE`, reproduced byte-for-text in [`LICENSE.upstream.txt`](LICENSE.upstream.txt); the repository source at the published `gitHead` contains the same `LICENSE` text.

## File-level provenance

| Repository file | Provenance | SHA-256 |
|---|---|---|
| `stock-index.js` | Exact byte copy of tarball `package/dist/index.js` | `b8d68f90bcdf4fa40b9a573c67f8ed19853d90e889e8c9ed2cf4021f50c6ce58` |
| `apply.py` | Project-authored patcher under the root MIT license; its `*_FROM` string constants quote portions of the upstream MIT-licensed `dist/index.js`, and its generated target is a modified derivative of that file | — |
| `README.md` | Project-authored documentation under the root MIT license | — |
| `tests/test-memory-pairing.mjs` | Project-authored test under the root MIT license | — |
| `tests/test-memory-pushturn.mjs` | Project-authored test under the root MIT license | — |
| `tests/test-memory-runtime-scope.mjs` | Project-authored test under the root MIT license | — |
| `tests/test-memory-settings-path.mjs` | Project-authored profile-settings regression test under the root MIT license | — |

`__pycache__/` is generated runtime output, is not source, and must not be distributed as part of the patch source bundle.

The vendored copy, quoted upstream fragments, and generated patched `dist/index.js` remain subject to the upstream MIT terms. Local patcher code and modifications are licensed under the repository's MIT license; that does not replace the upstream notice.
