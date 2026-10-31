# Targeted native session-file recovery search

Date: 2026-10-05
Target thread: 01a107c3-2a6f-75b3-8704-56d694e60af4
Scope: filenames only, read-only; no native retry, refused-command execution, or protected modification.

Command (login=false):

```text
rtk proxy rg --files --hidden --no-ignore -g '*01a107c3-2a6f-75b3-8704-56d694e60af4*' /Users/jrmag/.codex/sessions /Users/jrmag/.codex/archived_sessions
```

Result: exit 1, empty stdout/stderr; no matching file found. The preceding equivalent search without --no-ignore likewise returned exit 1 with empty output. `rtk proxy ls -ld` confirmed that both requested directories exist (exit 0). No broad JSONL content scan was performed.

The saved allocation-receipt.json records `thread/start` with `ephemeral: true`. The earlier native thread/read request with includeTurns=true returned `ephemeral threads do not support includeTurns`. The process has already ended. These observations are consistent with nonpersistent ephemeral execution, but the filename search alone does not prove absence from every possible nonstandard store or differently named file.

No original session JSONL was located in the two standard session stores. Therefore no exact refused tool-call argv or raw refusal event could be recovered; those fields remain explicitly unobserved. Worker final-message quotation and the previously recorded hashes are not promoted into an original event receipt. No secrets or unrelated session contents were read or saved.
