# Manual Precheck Note: epic-195-a7-compatibility / attempt 2 / round 3

Date: 2026-07-23T09:10:48Z

## Deviation

The automated command
`spec-review-precheck.sh epic-195-a7-compatibility 2 3 --edit-summary="..."`
stops before creating the round with `"prior round contract is malformed or
does not require work"`. Root cause: round 2's own reviewer-a.json legally
carries 7 checks (its own role file's unconditional mandate, ending
`DOMAIN-CONFORMANCE`), but `spec-review-precheck.sh`'s own
`validate_reviewer_output` hardcodes exactly 6 expected IDs per role and
rejects the mismatch. This is a distinct defect from attempt-2/round-1's
hash-staleness issue (different mechanism, same "review-loop gate script
drift" class), tracked under the same general issue #61
(https://github.com/aharada54914/sdd-forge/issues/61); full reproduction
at reports/notes/repo-defect-spec-reviewer-domain-conformance-check-count-mismatch.md.
No gate finding is waived -- round 2's own NEEDS_WORK verdict and its 1
Major finding stand exactly as reviewed, and this round's remedy (commit
556034c) is being sent to fresh, independent reviewers exactly as the
automated path would.

## Human authorization

Record of the human's decision (not this orchestrator's own signature).
Date: 2026-07-23. Channel: this session's main chat, typed by the human
directly, relayed by the coordinator agent. This is a SEPARATE
authorization from the 2026-07-22 round-2 one (which was explicitly
scoped to that round only) -- the orchestrator escalated rather than
assuming round 2's approval extended here. Verbatim instruction (as
relayed by the coordinator, quoting the human): "判断2・5については認可
する" ("I authorize judgments 2 and 5"), with the coordinator's own
message identifying "判断2" as this exact candidate (the round-3
manual-precheck fallback for epic-195-a7-compatibility attempt-2). Scope:
"round 2 と同じくこのラウンド限定の認可であり standing exemption ではな
い" ("same as round 2, scoped to this round only, not a standing
exemption") -- this round's manual precheck only; no review finding is
waived (round 2's own NEEDS_WORK verdict and its 1 Major finding stand
exactly as reviewed; the remedy is sent to fresh independent reviewers,
not accepted on the strength of this precheck substitution).

## Manual checks performed

See `reports/notes/candidate-manual-precheck-round3.md` in this worktree
for the full step-by-step equivalence check against
`spec-review-precheck.sh`'s own pure-validation logic, performed by hand.
Summary: every check the automated script performs was independently
verified true except the single `validate_reviewer_output` check-ID-count
comparison, which fails solely due to the issue-#61-class drift described
above -- round 2's actual review content, reviewer identities, and merged
verdict were all independently re-verified consistent by this orchestrator
when round 2's evidence was persisted (commit 8faff89), not merely
assumed.

## Result

Manual precheck passed under the temporary issue-#61 fallback.
