# Work Log — memory-ops

Mutation journal: the only trace of memory operations across sessions. The
`<memory>` block is rebuilt every turn, but it is a relevance slice, not an
operation history; a chat report dies with the chat.

## What to write

One line per mutation (create, delete, compress, update):

```
YYYY-MM-DD · mode · old-id → new-id · counters · facts preserved N/N
```

- Ids, modes, counters only. Entry content is NOT logged — the journal must
  not become garbage itself.
- Cleanup without recreation:
  `YYYY-MM-DD · 💀 · deleted: key1, key2 · no facts lost`.
- A series of operations in one session may be one summary line: id pairs
  separated by semicolons.
- Facts are addressed by dotted `key`; lessons by uuid.
- **Skill maintenance counts too.** A pass that fixes defects found in
  `defect-log.md` gets one line with mode 🛠 and the defect labels it closed —
  no memory ids, since nothing in the store changed. This keeps the two
  journals linked: every defect moved to Resolved has a matching work-log line.

```
YYYY-MM-DD · 🛠 · closed defects: <short labels> · memory untouched
```

---

## Entries

<!-- Add new entries below, newest last. -->

<!-- В публичном издании сборки журналы поставляются пустыми: записи реальных
     прогонов — приватные данные владельца и живут только в локальной копии навыка. -->
