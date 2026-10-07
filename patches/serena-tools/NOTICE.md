# Third-party source notice: `@bacnh85/pi-serena` 0.9.20

- Upstream package: `@bacnh85/pi-serena@0.9.20`
- Upstream repository/subdirectory: <https://github.com/bacnh85/pi-extensions>, path `pi-serena/`
- Published npm tarball: <https://registry.npmjs.org/@bacnh85/pi-serena/-/pi-serena-0.9.20.tgz>
- Published `gitHead`: `5388a5f1987873fe1355064f72021452c4347c72`

License evidence: tarball `package/package.json` declares `"license": "MIT"`. The published tarball omits a LICENSE file; the repository directory at the published commit also has no package LICENSE. [`LICENSE.upstream.txt`](LICENSE.upstream.txt) records this limitation and reproduces the standard SPDX MIT terms without inventing a missing copyright notice.

## File-level provenance

| Repository file | Provenance | SHA-256 |
|---|---|---|
| `store/index.ts.orig-0.9.20` | Exact byte copy of tarball `package/extensions/index.ts` | `4680073ba2af587ca370b0ba6c229e42825e8ed8a2727b9ead45427c25e33343` |
| `store/guidance.ts.orig-0.9.20` | Exact byte copy of tarball `package/extensions/lib/guidance.ts` | `767cacb7f3110dc797998d70f2b6d825e761aa6c3bd4ad9014dcd009b7d0a148` |
| `apply.py` | Project-authored patcher under the root MIT license; generated targets are modified derivatives of the upstream MIT-declared files | — |
| `README.md` | Project-authored documentation under the root MIT license | — |

`__pycache__/` is generated runtime output, is not source, and must not be distributed as part of the patch source bundle.

Pristine copies and generated patched files remain subject to the upstream MIT declaration. Local patcher code and modifications are licensed under the repository's MIT license; that does not replace the upstream declaration.
