# Manual Precheck Note: epic-195-a7-compatibility / attempt 2 / round 2

Date: 2026-07-22T14:09:54Z

## Deviation

The automated command
`spec-review-precheck.sh epic-195-a7-compatibility 2 2 --edit-summary="..."`
stops before creating the round with `"prior round contract is malformed or
does not require work"`. Root cause: attempt-2/round-1's own
`precheck-result.json` recorded `requirements_sha256` from before that same
invocation's own `--reset` sed mutation (Passed -> Pending), so it can never
equal round-1's own `spec-review-contract.json` value (which correctly uses
the live, post-reset hash both reviewers actually reviewed). This is the
review-launch precheck defect tracked in issue #61
(https://github.com/aharada54914/sdd-forge/issues/61); full reproduction at
reports/notes/repo-defect-spec-review-precheck-reset-hash-staleness.md. No
gate finding is waived -- round 1's own NEEDS_WORK verdict and its 3 Major
findings stand exactly as reviewed, and this round's remedy (commit
d1dae1b) is being sent to fresh, independent reviewers exactly as the
automated path would.

## Human authorization

Record of the human's decision (not this orchestrator's own signature).
Date: 2026-07-22. Channel: this session's main chat, typed by the human
directly (not inferred, not proxy-approved by any agent). Context: the
orchestrator had presented two candidates -- Candidate A (a script patch to
`spec-review-precheck.sh`) and Candidate B (this manual-precheck fallback)
-- and explicitly asked the human to choose "A / B / C (other)" before
proceeding, per the coordinator's own "human judgment gate" determination
for this enforcement-chain-adjacent defect. Verbatim instruction (English
transliteration of the original Japanese, quoted exactly as relayed by the
coordinator agent): "B で今ラウンドを解錠し、A は後で本体 repo への独立
PR として提出" ("Unlock this round with B, and submit A later as an
independent PR to the main repository"). Scope of what is authorized: this
manual-precheck deviation for epic-195-a7-compatibility attempt-2/round-2
only -- not a standing exemption from issue #61, not a waiver of any
review finding (round 1's 3 Major findings stand exactly as reviewed;
remedy is being sent to fresh independent reviewers, not accepted on the
strength of this precheck substitution). Candidate A (the script fix) is
explicitly NOT authorized for application to this branch; it is authorized
only as a future independent pull request against the main sdd-forge
repository, tracked separately and outside this orchestrator's scope.

## Manual checks performed

See `reports/notes/candidate-manual-precheck-round2.md` in this worktree
for the full step-by-step equivalence check against
`spec-review-precheck.sh`'s own pure-validation logic, performed by hand.
Summary: every check the automated script performs was independently
verified true except the single `validate_contract` hash-equality check
against round 1's own precheck-result.json, which fails solely due to the
issue-#61-class staleness defect described above -- round 1's actual
review content, reviewer identities, and merged verdict were all
independently re-verified consistent by this orchestrator when round 1's
evidence was persisted (commit c67bb80), not merely assumed.

## Result

Manual precheck passed under the temporary issue-#61 fallback.
