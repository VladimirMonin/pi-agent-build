# Third-party source notice: `pi-session-search` 1.4.3

- Upstream package: `pi-session-search@1.4.3`
- Upstream repository: <https://github.com/samfoy/pi-session-search>
- Published npm tarball: <https://registry.npmjs.org/pi-session-search/-/pi-session-search-1.4.3.tgz>
- Published `gitHead`: `4808ac2a12ed3b6fc0100e4242bfdd84148ee358`
License evidence: the versioned tarball contains `package/LICENSE`, reproduced byte-for-text in [`LICENSE.upstream.txt`](LICENSE.upstream.txt); the repository source at the published `gitHead` contains the same `LICENSE` text.

## File-level provenance

| Repository file | Provenance | SHA-256 |
|---|---|---|
| `store/1.4.3/src/config.ts` | Exact byte copy of tarball `package/src/config.ts` | `625fdbefd346e8b2b820be6319eea8bd66779bced277dca81a2fa3974355b912` |
| `store/1.4.3/src/parser.ts` | Exact byte copy of tarball `package/src/parser.ts` | `2f67818bc768a3f7e89aa2f8135cf8fb70611b148dfbd7ef41e8cf7d3dd1746a` |
| `store/1.4.3/dist/index.js` | Exact byte copy of tarball `package/dist/index.js` | `e89d2d9d69380559ed735c378fdab2d43a3d8e546bfcab941ee69c0895b6f545` |
| `apply.py` | Project-authored patcher under the root MIT license; its `*_OLD` anchors quote upstream MIT-licensed source and its generated targets are modified derivatives | — |
| `README.md` | Project-authored documentation under the root MIT license | — |

`__pycache__/` is generated runtime output, is not source, and must not be distributed as part of the patch source bundle.

The pristine copies, quoted anchors, and generated patched files remain subject to the upstream MIT terms. Local patcher code and modifications are licensed under the repository's MIT license; that does not replace the upstream notice.
