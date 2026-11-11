# Pi session stores — where the evidence lives

> Read before workflow step 4. Paths use `~` so they work for any user on Windows,
> macOS and Linux. Nothing here is machine-specific.

## Layout

```
~/.pi/agent/
  sessions/<munged-cwd>/<session-id>.jsonl          the conversation itself
  sessions/<munged-cwd>/<session-id>/
      <subagent-id>/run-0/session.jsonl             one file per subagent run
      subagent-artifacts/<id>_<role>_output.md      subagent reports
  sessions/<munged-cwd>/subagent-artifacts/         shared artifact outputs
  traces/<session-id>/events.jsonl                  tool calls and usage
  run-history.jsonl                                 launch history
  missions/<mission>/                               long-running goals, briefs
```

`<munged-cwd>` folds the working directory separators into dashes, for example
`--C--work-my-project--`. Key on the session id, never on the folder name alone.

## Three-tier discovery

1. **Semantic search** (`session_search`) when configured — query by artifact name,
   topic, or a distinctive term from the user's request. Batch independent terms.
2. **Plain session search** — `session_list` with project and date filters, then
   `session_read` on the candidates. This is the fallback when semantics are
   missing or return nothing.
3. **Raw files** — read the JSONL directly with bounded windows when you need exact
   quotes, timestamps, or tool receipts. Aggregate first, read bodies second.

## Linking subagents to the main session

Establish links from metadata and directory nesting, not from similar titles:

- nested `sessions/.../<session-id>/<subagent-id>/` directories belong to that
  session;
- `subagent-artifacts/<id>_<role>_output.md` names carry the subagent id and role;
- `traces/<session-id>/events.jsonl` records tool calls including delegation.

Cover every linked subagent that worked inside the period. An author's summary of
subagent work is a claim, not proof — read each accessible subagent's own file.

## What to extract per record

Timestamp and id, role, tool names and result presence, a short redacted preview.
Aggregate routine reads and repeated discovery instead of printing a row per call.
Exact IDs for decisive moments only.

## Traps

- **Compaction summaries are not user turns.** Context compaction rewrites history
  into summary blocks; never count them as requests or replies.
- **Harness noise looks like user messages.** Injected environment headers, tool
  lists and reminders must be filtered out of the chronology or the requirement
  list will be wrong.
- **Self-matches.** Semantic search can return the session you are running in;
  suppress self-matches when looking for earlier work.
- **Empty assistant rows are aborted turns**, not answers.
- **File mtime is not event time.** A session started one day continues later; use
  timestamps inside the records.
