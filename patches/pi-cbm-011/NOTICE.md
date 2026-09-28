# Third-party source notice: `pi-cbm` 1.2.1

- Upstream package: `pi-cbm@1.2.1`
- Upstream repository: <https://github.com/alexykn/pi-cbm>
- Published npm tarball: <https://registry.npmjs.org/pi-cbm/-/pi-cbm-1.2.1.tgz>
- Published `gitHead`: `921a749d5cea74bda8f647542627ef9518fec272`
License evidence: the versioned tarball contains `package/LICENSE`, reproduced byte-for-text in [`LICENSE.upstream.txt`](LICENSE.upstream.txt); the repository source at the published `gitHead` contains the same `LICENSE` text.

## File-level provenance

| Repository file | Provenance | SHA-256 |
|---|---|---|
| `store/client.ts.orig-1.2.1` | Text-identical copy of tarball `package/src/cbm/client.ts`; repository copy uses CRLF on all 107 line endings, while the tarball uses LF | upstream bytes: `945e40279328769a8a303ac788b5cd5b641344db6a402d0f8efbe3f014bb93db`; repository bytes: `f9de16fc9e840f0cd7f914fdaadaa694b712b0a720daadcfb40071ce326324b4` |
| `apply.py` | Project-authored patcher under the root MIT license; it contains short matching anchors from the upstream MIT-licensed file, and its generated target is a modified derivative of that file | — |
| `README.md` | Project-authored documentation under the root MIT license | — |

`__pycache__/` is generated runtime output, is not source, and must not be distributed as part of the patch source bundle.

The pristine copy, quoted anchors, and generated patched `client.ts` remain subject to the upstream MIT terms. Local patcher code and modifications are licensed under the repository's MIT license; that does not replace the upstream notice.
