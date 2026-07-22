Candidate: manual precheck deviation for epic-195-a7-compatibility, attempt 2, round 3
========================================================================================

STATUS: candidate only. NOT applied to the live path. **Human authorization
NOT yet obtained for this round** -- the 2026-07-22 authorization for round
2's fallback was explicit and scoped to "attempt-2/round-2 only ... not a
standing exemption from issue #61" (see
`reports/spec-review/epic-195-a7-compatibility/attempt-2/round-2/manual-precheck-note.md`).
This orchestrator judged that authorization does not extend to round 3,
which is blocked by a *different* defect, and is escalating for a fresh
decision rather than self-applying this candidate. If a human authorizes
it, the two blocks below become, verbatim: (1)
`reports/spec-review/epic-195-a7-compatibility/attempt-2/round-3/precheck-result.json`,
and (2) that same directory's `manual-precheck-note.md`, per AGENTS.md's
"Review gate precheck fallback" (issue #61) procedure.

## Why this candidate exists

`spec-review-precheck.sh epic-195-a7-compatibility 2 3
--edit-summary="..."` fails with `"prior round contract is malformed or
does not require work"`. Root cause (precisely isolated, not assumed):
`validate_contract`'s call to `validate_reviewer_output` on round 2's own
`reviewer-a.json` compares its 7 check IDs (ending `DOMAIN-CONFORMANCE`,
per `spec-reviewer-a.md`'s own unconditional role-file mandate) against
`spec-review-precheck.sh`'s own hardcoded 6-ID `expected_ids` string,
which does not include `DOMAIN-CONFORMANCE`. Exact-string-equality fails.
Full analysis:
`reports/notes/repo-defect-spec-reviewer-domain-conformance-check-count-mismatch.md`
("Update (2026-07-23)" section). Issue #61
(https://github.com/aharada54914/sdd-forge/issues/61) is the same general
upstream precheck-defect tracking AGENTS.md's fallback names as its own
trigger condition -- this is a different specific defect than round 2's
(hash staleness), but the same class (review-loop gate script drift) and
the same repository-provided remedy mechanism.

## Manual precheck steps performed (equivalent to `spec-review-precheck.sh
epic-195-a7-compatibility 2 3 --edit-summary="..."`'s own pure-validation
checks, run by hand against the live repository state, 2026-07-23)

- Feature slug, attempt `2`, round `3` (<= 3, the attempt's final round)
  all valid. `--edit-summary` non-empty. Not `--reset`. OK.
- `specs/epic-195-a7-compatibility/` and its two spec files exist, regular,
  non-symlink, canonical. OK (unchanged since round 2).
- Calibration reference, reports root/base exist and canonicalize
  correctly. `jq` available. OK.
- `Spec-Review-Status` reads `Pending`. OK.
- `reports/spec-review/epic-195-a7-compatibility/attempt-2/round-3/` does
  not yet exist. OK.
- **The one step the automated script cannot complete:** `validate_contract`
  against round 2's own `spec-review-contract.json` fails solely on the
  `validate_reviewer_output` 6-vs-7 check-ID comparison described above.
  Every other structural and cross-artifact check that function performs
  was independently verified true when round 2's evidence was built and
  persisted (commit `8faff89`): both reviewers' outputs were hash-verified
  byte-for-byte against host-relayed values before persisting; the
  contract's `reviewers[].allowed_input_manifest` entries match each
  reviewer's own actual manifest exactly; the merged verdict (`NEEDS_WORK`,
  0 Critical / 1 Major / 0 Minor) was computed by the same formula
  `validate_contract` itself uses.
- Reviewed inputs changed from the prior round: round 2's `requirements.md`
  sha256 was `5a2c278d8d9583a2b8d7f7b8096e38b02fc66d56f48849a80bcc7a18a8deef42`;
  the current, remedied file (commit `556034c`: AC-034 enumeration adds
  AC-036/AC-037) sha256 is
  `be0cd28571cc64784c89d687c5c38b8ccbe14bd7dfab0a5ba4c73c8a26311ac9` --
  different, as required. `acceptance-tests.md` is unchanged this round
  (`7b62c3391ddc58131cf1d1a16644e116b3030562e47a15fcd66ee4ef3c8aa24d`,
  same as round 2 -- the remedy was requirements.md-only; the "unchanged
  from prior round" guard only requires *either* hash to differ, and
  requirements.md's does).

## The precheck-result.json this candidate would persist (verbatim, if authorized)

```json
{
  "schema": "spec-review-precheck/v1",
  "stage": "spec",
  "feature": "epic-195-a7-compatibility",
  "attempt": 2,
  "round": 3,
  "spec_review_status_field": "Pending",
  "requirements_sha256": "be0cd28571cc64784c89d687c5c38b8ccbe14bd7dfab0a5ba4c73c8a26311ac9",
  "acceptance_sha256": "7b62c3391ddc58131cf1d1a16644e116b3030562e47a15fcd66ee4ef3c8aa24d",
  "calibration_sha256": "1ddd4ed250e30c0eb78a3d644adfefd21d0af5ea311444b526c8d840fc0649b8",
  "input_sha256": "ec04eaf120afa74664acebf2a65ae3d0688a0befe19fe2c37e46ec0a1a9daddc",
  "edit_summary": "Remedy round-2 reviewer-b DOWNSTREAM-READINESS finding: AC-034's own SKIP-candidate enumeration now lists AC-036 and AC-037 (commit 556034c); manual precheck fallback per AGENTS.md issue #61, working around the check-ID-count (6-vs-7 DOMAIN-CONFORMANCE) defect this attempt's own round 2 evidence surfaced (see reports/notes/repo-defect-spec-reviewer-domain-conformance-check-count-mismatch.md)",
  "reset": false,
  "generated_at": "<fill in at authorization time, UTC>"
}
```

## Manual-precheck-note.md this candidate would persist (verbatim, if authorized)

```markdown
# Manual Precheck Note: epic-195-a7-compatibility / attempt 2 / round 3

Date: <fill in at authorization time, UTC>

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

<TO BE FILLED IN BY THE HUMAN APPROVER -- this is a SEPARATE authorization
from the 2026-07-22 round-2 one, which was explicitly scoped to that round
only. Who, when, and the exact scope of what is authorized (this round's
manual precheck only; not a standing exemption; not a waiver of any
finding).>

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
```

## What remains after this candidate, if authorized

Reserve spec-reviewer-a's identity for attempt-2/round-3 (next ledger
sequence) exactly as prior rounds' reviewers were reserved, write the
launch prompt (quoting the role file's own 7-check Output Format verbatim,
same discipline as round 2's corrected reviewer-b prompt), and proceed
through the same independent two-reviewer sequence. Round 3 is this
attempt's own final round per SKILL.md's state-transition table: a clean
pass reaches `Spec-Review-Status: Passed`; any surviving Critical/Major
finding produces `BLOCKED`.
