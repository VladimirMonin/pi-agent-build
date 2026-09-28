# Third-party source notice: `pi-trace-extension` 0.1.16

- Upstream package: `pi-trace-extension@0.1.16`
- Upstream repository: <https://github.com/npxcnency-ux/pi-trace-extension>
- Published npm tarball: <https://registry.npmjs.org/pi-trace-extension/-/pi-trace-extension-0.1.16.tgz>
- Published `gitHead`: `5441bcca041e3b3a203aee91c68e8ea809e6aa27`
License evidence: the versioned tarball contains `package/LICENSE`, reproduced byte-for-text in [`LICENSE.upstream.txt`](LICENSE.upstream.txt); the repository source at the published `gitHead` contains the same `LICENSE` text.

## File-level provenance

Every file under `payload/` is a modified derivative of the corresponding file under tarball `package/extensions/trace/`; stock and payload hashes are listed explicitly.

| Repository payload | Tarball source | Stock SHA-256 | Payload SHA-256 |
|---|---|---|---|
| `payload/index.ts` | `package/extensions/trace/index.ts` | `ac370c5fd06d3ae6fbb62a1fe807b49eef74c5e6d6bc71d81b1f4c2fd8bbb12b` | `822fa2a21e87a99b09940f1c9f59773b1558b761cd584d9dcf6c6a11f56b98a4` |
| `payload/trace_to_html.py` | `package/extensions/trace/trace_to_html.py` | `3684c5a787d416eb08d7cb6eae942e6a550b53a608086712e013fe093f09c2ba` | `1d464dcc269c3a2d3244416a0cbe11c7f5264f5bd53aea40c7ee1c7aed9ab290` |
| `payload/viewer/viewer.html` | `package/extensions/trace/viewer/viewer.html` | `243accc49e55b1f34a31d7022170e37f8eb058d567670d5db610ee06bd3e71e1` | `c5d3555f40478ce0236a4d67a55d393dc49fb3b883665050c91c0e0b06d1217b` |
| `payload/viewer/viewer.js` | `package/extensions/trace/viewer/viewer.js` | `363877fa05f6d7236e645ffaae7353d6d415282cea246d61a52f840ceef8ed19` | `079024ea369a772876ac3960d0834635c1a7c652951a5f905a86378b825fe2b1` |
| `payload/viewer/dashboard.html` | `package/extensions/trace/viewer/dashboard.html` | `144b110fc59352af02d9cea8a56b401800e054681339081ab0daaa80a30d90fa` | `03d3683628d5cd39dbade35de973852d71fbad7101760bedba9ad71a84d2d6a2` |
| `payload/viewer/dashboard.js` | `package/extensions/trace/viewer/dashboard.js` | `52ba28818a7c3f90e9309629aee9eafc9be1c3965eb5d46e03ab99b1d8c45cdd` | `5177eb2f49b58fc72ac7ac9b862147db94908f6cbb30e3ae3c3a438cff40a5e0` |
| `apply.py` | Project-authored patcher under the root MIT license; it copies the six derivatives above and invokes the upstream installed `viewer/build.py` | — | — |
| `README.md` | Project-authored documentation under the root MIT license | — | — |

`viewer/assets.json` is not vendored in this repository; the patcher rebuilds it from the installed package's `viewer/build.py`. `__pycache__/` is generated runtime output, is not source, and must not be distributed as part of the patch source bundle.

The six payload derivatives remain subject to the upstream MIT terms. Local modifications and patcher code are licensed under the repository's MIT license; that does not replace the upstream notice.
