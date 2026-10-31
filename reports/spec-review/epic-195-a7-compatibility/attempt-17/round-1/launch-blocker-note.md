# Attempt 17 reviewer A first-turn transport failure

Recorded: 2026-10-05
Feature: epic-195-a7-compatibility
Host session: 291d069a-b4e7-451a-bc5b-f35bd3d7388d
Run ID: 291d069a
Reservation sequence: 1204
Reservation record: c5027df892647a19c18d60351c20fcecceb9646fe3d1e81db526cefb7ffa1e99

The normal attempt-17 round-1 precheck and the one ordinary reviewer-A reservation succeeded. The host was a fresh idle native Claude Sonnet context using the repaired inline `sdd-review-loop:spec-reviewer-a` role, read-only tools, active hooks and deny rules, and exact SHA-256 command allowances. The first turn was submitted through the attached TTY.

The TTY paste delivered only the tail of the intended prompt. The retained private host transcript has SHA-256 `c97147d1fe1e80faa39bfb63f4ae9fa086beed641e48ca927175d1a0bc783381`; its actual user message began with `aw reports, or old attempt outputs.` and omitted the invocation path, host identities, and `REVIEW_CONTEXT_OK` receipt. The full intended prompt was therefore never received by the reviewer. The private transcript path and raw bytes are retained locally, not copied into this report.

The reviewer did not read any admitted substantive input or run a hash command. It returned a `BLOCKED` diagnostic with blank identity fields and `FAIL` placeholders for checks it explicitly said were unevaluated. This output is not a valid formal review verdict or a specification finding; its raw host transcript remains diagnostic-only. Reviewer B was not allocated or reserved. Sequence 1204 is consumed and the host session must not be reused for a later review turn.

Before any new reservation, validate a non-TTY prompt delivery route in a separate unreserved context, including exact delivered length/hash and tail. Preserve this failed attempt and use only a separately admitted next attempt; do not replay or reset attempt 17.
