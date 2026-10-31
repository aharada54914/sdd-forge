# Attempt 18 reviewer A first-turn permission failure

Recorded: 2026-10-05
Feature: epic-195-a7-compatibility
Host session and Run ID: fa97e307-7faa-4e4a-aa31-8d3ea359467d
Reservation: sequence 1205, record c2ccc240892d5f4aa43d2e01c53163025ecbd8a304fccb8afae41a2e45144a7b

The normal attempt-18 round-1 precheck succeeded against the formal fresh-review contract. The non-TTY preflight returned `PREFLIGHT_OK`, and the ordinary review-context validator returned `REVIEW_CONTEXT_OK` before the single fresh Sonnet first turn. The prompt file exactly matched the helper's complete template (988 bytes, SHA-256 `845f0c4d06153767fbebfa6ec6b4c158539ba43a9797bf028f9ece98bdff9f85`). The native transcript's sole human user text has the same hash. The native transcript remains local with SHA-256 `855e8eed389dc432ed0b604e716ef73dfa198c9abe32464f2eeaccf580acf25f`; raw bytes are not copied here.

The CLI JSON result reported matching session ID, `is_error: false`, and Claude Sonnet 5.5, but two Bash permission denials. The denied commands were `rtk proxy sha256sum -- /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/review-context/epic-195-a7-compatibility-spec-a18r1-a-invocation.json` and `rtk proxy sha256sum -- reports/review-context/epic-195-a7-compatibility-spec-a18r1-a-invocation.json specs/epic-195-a7-compatibility/requirements.md specs/epic-195-a7-compatibility/acceptance-tests.md specs/epic-195-a7-compatibility/investigation.md plugins/sdd-review-loop/references/spec-review-calibration.md reports/spec-review/epic-195-a7-compatibility/attempt-18/round-1/precheck-result.json`. The reviewer returned prose saying admission was incomplete, no substantive review input had been read, and there was no verdict or checks array. This is a launch failure, not a spec finding or formal result. The CLI wrapper was observed in tool output but was not persisted as a regular file; no native postflight is claimed.

Reviewer B was not allocated or reserved. The A identity remains consumed. Do not retry in this session, relabel this output, or use it for B. A later attempt needs a separately admitted recovery contract and fresh identities after the exact read-only hash permission issue is repaired and verified without disabling guards or `dontAsk`.
