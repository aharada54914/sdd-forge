# Reviewer A launch failure — no verdict

The host allocated fresh read-only, network-disabled thread/session
`01a07ca9-2407-7be1-9596-385efdbca31b` with model `gpt-6-astra` (26a90c).
The canonical validator reserved its invocation successfully (f3639b):

```
REVIEW_CONTEXT_OK c2337ab773d6531ebbf23b7118e71c24d1af1fca1f6bb41e5a2773f43176496a sequence=961 previous_record_sha256=54fa8d6d0249ab01745e1231e2ea92655878847805b4b0e61191518f021e7957 pre_append_tip_sequence=960 identity_unique=yes
```

The first oversized JSON line was not accepted by the PTY; its pending input
was cleared before sending the shorter request. Exactly one model turn was
accepted (c0d01f): `01a07caa-b2f8-7080-a821-0cd6c50f3b0c`.
It ended `failed`, `willRetry: false` (3fa760), with HTTP 400:

> The 'gpt-6-astra' model requires a newer version of Codex. Please upgrade to the latest app or CLI and try again.

No reviewer output or substantive review was produced. The consumed reservation
and invocation remain intact; they must not be reused or called PASS. The CLI
was 0.147.0. The owning app-server was stopped (1a53b8). Next action is to locate
a compatible installed CLI, or arrange a supported update, then allocate a new
identity before retrying the same unchanged specification round.
