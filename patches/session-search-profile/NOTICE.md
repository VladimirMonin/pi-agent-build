# Third-party source notice: `pi-session-search` 1.6.0 and 1.6.1

- Package: `pi-session-search@1.6.0` (retained store), current `pi-session-search@1.6.1`
- Repository: <https://github.com/samfoy/pi-session-search>
- Tarballs: <https://registry.npmjs.org/pi-session-search/-/pi-session-search-1.6.0.tgz>, <https://registry.npmjs.org/pi-session-search/-/pi-session-search-1.6.1.tgz>
- Published `gitHead`: 1.6.0 `5a910e7c3a238d347e90020147815227b567b85e`; 1.6.1 `727d18d246fb7f4c47103be6f41e796cb85392b2`
- MIT license: exact 1.6.0 tarball `package/LICENSE` reproduced in [LICENSE.upstream.txt](LICENSE.upstream.txt). The 1.6.1 tarball ships the same license text (byte difference limited to CRLF vs LF line endings).

## File-level provenance

| Repository file | Exact tarball path | SHA-256 |
|---|---|---|
| `store/1.6.0/src/config.ts` | `package/src/config.ts` | `e6103a7010615e059a01a3954d3135092b46e197cec6ce878ae84271c9211427` |
| `store/1.6.0/src/parser.ts` | `package/src/parser.ts` | `2f67818bc768a3f7e89aa2f8135cf8fb70611b148dfbd7ef41e8cf7d3dd1746a` |
| `store/1.6.0/src/index.ts` | `package/src/index.ts` | `e2e36ee96ca972d8e98bc9dec857ca1ac883c1063f8f8ca11786713d3f1574bc` |
| `store/1.6.0/dist/index.js` | `package/dist/index.js` | `9d011f994d6de8bb873ba242a9b705ab560046a4eae3c66c75068c98aa29090b` |
| `store/1.6.0/src/utils.ts` | `package/src/utils.ts` | `fd8cff09d6557df8b1dd4b55770aa4fdbdd37546a0da454bb25596055926bf5e` |
| `store/1.6.0/src/session-index.ts` | `package/src/session-index.ts` | `4c0fa27ae77ff037fe393f24efda51fb7ca2b995143b0560d5b09902f82a8622` |
| `store/1.6.0/src/fts-index.ts` | `package/src/fts-index.ts` | `9f01a4fe3cf51ad1db8663be34603b9d71cee5ead30fbd18d0e7d590bb92316f` |
| `store/1.6.0/src/index-service.ts` | `package/src/index-service.ts` | `369d4d64531f82fcaae93f1354813328db73aead72488263f5e7d0f928d93d58` |
| `store/1.6.0/src/embedder.ts` | `package/src/embedder.ts` | `0aa80d061c9973993c85b4df85c6f342f2180351003966afab94ae507008e5be` |
| `store/1.6.0/dist/index-worker.js` | `package/dist/index-worker.js` | `7901989942a790c549d328a3d49e491090f514c0b5a650a4547dad9b73a99b57` |

## File-level provenance: 1.6.1 (current guard target)

| Repository file | Exact tarball path | SHA-256 |
|---|---|---|
| `store/1.6.1/src/config.ts` | `package/src/config.ts` | `e6103a7010615e059a01a3954d3135092b46e197cec6ce878ae84271c9211427` |
| `store/1.6.1/src/parser.ts` | `package/src/parser.ts` | `2f67818bc768a3f7e89aa2f8135cf8fb70611b148dfbd7ef41e8cf7d3dd1746a` |
| `store/1.6.1/src/index.ts` | `package/src/index.ts` | `9e05ff3528fa99a63bad71cab270fc53f1405248467767d2e08f294f4b1d2fb7` |
| `store/1.6.1/dist/index.js` | `package/dist/index.js` | `881f34e61cfe74ac415757bee51c7c07537b90bad62ec69b46dfdcf13324e63c` |
| `store/1.6.1/src/utils.ts` | `package/src/utils.ts` | `fd8cff09d6557df8b1dd4b55770aa4fdbdd37546a0da454bb25596055926bf5e` |
| `store/1.6.1/src/session-index.ts` | `package/src/session-index.ts` | `4c0fa27ae77ff037fe393f24efda51fb7ca2b995143b0560d5b09902f82a8622` |
| `store/1.6.1/src/fts-index.ts` | `package/src/fts-index.ts` | `9f01a4fe3cf51ad1db8663be34603b9d71cee5ead30fbd18d0e7d590bb92316f` |
| `store/1.6.1/src/index-service.ts` | `package/src/index-service.ts` | `369d4d64531f82fcaae93f1354813328db73aead72488263f5e7d0f928d93d58` |
| `store/1.6.1/src/embedder.ts` | `package/src/embedder.ts` | `0aa80d061c9973993c85b4df85c6f342f2180351003966afab94ae507008e5be` |
| `store/1.6.1/dist/index-worker.js` | `package/dist/index-worker.js` | `7901989942a790c549d328a3d49e491090f514c0b5a650a4547dad9b73a99b57` |

`store/1.6.0/` is retained byte-exact as the rollback reference for the pre-port line (guard 1.6.0 is no longer accepted: rollback = reinstall 1.6.0 and restore from the store).

`apply.py` and README are project-authored under the root MIT license; generated patched files are modified derivatives of the upstream MIT source. Pristine copies and generated targets remain subject to upstream terms. All ten pristine inputs come from the pinned npm 1.6.0 tarball. Both bundled main and worker are patched reproducibly for profile roots, display, preservation and model-prefix/search behavior; the immutable store retains the exact upstream bytes. Runtime backups, raw receipts and generated `__pycache__` are not distributed as patch source.
