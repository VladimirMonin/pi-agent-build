# Third-party source notice: `@bacnh85/pi-serena` 0.9.16

- Upstream package: `@bacnh85/pi-serena@0.9.16`
- Upstream repository/subdirectory: <https://github.com/bacnh85/pi-extensions>, path `pi-serena/`
- Published npm tarball: <https://registry.npmjs.org/@bacnh85/pi-serena/-/pi-serena-0.9.16.tgz>
- Published `gitHead`: `b5330ac3d014f92dff97a2b90cd9ebdbf0de22fd`
License evidence: tarball `package/package.json` and repository path `pi-serena/package.json` at the published `gitHead` both declare `"license": "MIT"`.

The published tarball's `files` list omits a LICENSE file, and the repository tree at the published commit has no LICENSE for `pi-serena`. [`LICENSE.upstream.txt`](LICENSE.upstream.txt) records this limitation and reproduces the standard SPDX MIT terms without inventing a missing copyright notice.

## File-level provenance

| Repository file | Provenance | SHA-256 |
|---|---|---|
| `store/index.ts.orig-0.9.16` | Exact byte copy of tarball `package/extensions/index.ts` | `aff70771cbefb6cbb9d69da14ada262b1e175df57976f8335bc315f9d0a71edc` |
| `apply.py` | Project-authored patcher under the root MIT license; its generated target is a modified derivative of the upstream MIT-declared file | — |
| `README.md` | Project-authored documentation under the root MIT license | — |

`__pycache__/` is generated runtime output, is not source, and must not be distributed as part of the patch source bundle.

The pristine copy and generated patched `extensions/index.ts` remain subject to the upstream MIT declaration. Local patcher code and modifications are licensed under the repository's MIT license; that does not replace the upstream declaration.
