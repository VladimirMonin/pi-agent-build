# Third-party source notice: `@bacnh85/pi-serena` 0.9.20 and 0.10.1

- Upstream package: `@bacnh85/pi-serena@0.9.20` (retained store), current `@bacnh85/pi-serena@0.10.1`
- Upstream repository/subdirectory: <https://github.com/bacnh85/pi-extensions>, path `pi-serena/`
- Published npm tarballs: <https://registry.npmjs.org/@bacnh85/pi-serena/-/pi-serena-0.9.20.tgz>, <https://registry.npmjs.org/@bacnh85/pi-serena/-/pi-serena-0.10.1.tgz>
- Published `gitHead`: 0.9.20 `5388a5f1987873fe1355064f72021452c4347c72`; 0.10.1 `da6dbcc9e784ac1cba4608b40cab4cb61177ce73`

License evidence: tarball `package/package.json` declares `"license": "MIT"` (both versions). The published tarballs omit a LICENSE file; the repository directory at the published commits also has no package LICENSE. [`LICENSE.upstream.txt`](LICENSE.upstream.txt) records this limitation and reproduces the standard SPDX MIT terms without inventing a missing copyright notice.

## File-level provenance

| Repository file | Provenance | SHA-256 |
|---|---|---|
| `store/index.ts.orig-0.9.20` | Exact byte copy of 0.9.20 tarball `package/extensions/index.ts` | `4680073ba2af587ca370b0ba6c229e42825e8ed8a2727b9ead45427c25e33343` |
| `store/guidance.ts.orig-0.9.20` | Exact byte copy of 0.9.20 tarball `package/extensions/lib/guidance.ts` | `767cacb7f3110dc797998d70f2b6d825e761aa6c3bd4ad9014dcd009b7d0a148` |
| `store/index.ts.orig-0.10.1` | Exact byte copy of 0.10.1 tarball `package/extensions/index.ts` | `8593347a873083d403ea0207b624e9ff5d78448c03cbde9b352671f3b0366684` |
| `store/guidance.ts.orig-0.10.1` | Exact byte copy of 0.10.1 tarball `package/extensions/lib/guidance.ts` | `9e22607d4ff8e2d5024b0f9eaacbf0cbe3a0e83c373280aba891f0cc97e1ad2e` |
| `apply.py` | Project-authored patcher under the root MIT license; generated targets are modified derivatives of the upstream MIT-declared files | — |
| `README.md` | Project-authored documentation under the root MIT license | — |

`__pycache__/` is generated runtime output, is not source, and must not be distributed as part of the patch source bundle. The `store/*.orig-0.9.20` pair is retained as the byte-exact rollback reference after the 2026-11-11 port to 0.10.1.

Pristine copies and generated patched files remain subject to the upstream MIT declaration. Local patcher code and modifications are licensed under the repository's MIT license; that does not replace the upstream declaration.
