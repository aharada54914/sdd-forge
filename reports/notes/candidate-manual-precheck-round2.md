Candidate B: manual precheck deviation for epic-195-a7-compatibility, attempt 2, round 2
==========================================================================================

STATUS: candidate only. NOT applied to the live path. If a human selects this
option, the two blocks below become, verbatim: (1) the round's own
`reports/spec-review/epic-195-a7-compatibility/attempt-2/round-2/precheck-result.json`,
and (2) that same directory's `manual-precheck-note.md`, per AGENTS.md's
"Review gate precheck fallback" (issue #61) procedure, which this repository
already uses in precedent (e.g.
`reports/spec-review/epic-136-phase2-gates/attempt-2/round-1/manual-precheck-note.md`).
This candidate mirrors that precedent's exact structure and schema.

## Why this candidate exists

`spec-review-precheck.sh epic-195-a7-compatibility 2 2 --edit-summary=...`
fails with `"prior round contract is malformed or does not require work"`
because attempt-2/round-1's own `precheck-result.json` recorded a
`requirements_sha256` from BEFORE that round's `--reset` sed mutation
(stale), which can never equal round-1's own `spec-review-contract.json`
value (correctly live) -- see
`reports/notes/repo-defect-spec-review-precheck-reset-hash-staleness.md`
for the full empirical writeup, and issue #61
(https://github.com/aharada54914/sdd-forge/issues/61) for the general
upstream precheck-defect tracking this repository's AGENTS.md already
names as the fallback's own trigger condition.

Unlike candidate A (the script patch), this candidate does not touch
`plugins/**` at all -- it manually performs round 2's own precheck
validation and records the result, exactly as AGENTS.md's fallback already
authorizes for exactly this class of situation ("a review gate ... whose
launch precheck cannot be satisfied").

## AGENTS.md's four fallback conditions (issue #61), addressed in order

1. **"Run the precheck steps manually and record the results in a
   `manual-precheck-note.md` inside the affected round directory."** — see
   the Manual Checks Performed section below, and the precheck-result.json
   content block (this is the record).
2. **"Obtain explicit human approval of the deviation and record it in the
   note."** — NOT YET OBTAINED. The note template below has an explicit
   blank for this; a human must fill in their authorization before this
   candidate is promoted to the real file.
3. **"Reserve reviewer identities in the identity ledger exactly as the
   automated path would."** — unaffected by this defect (ledger reservation
   goes through `validate-review-context-set.sh` independently of
   `spec-review-precheck.sh`); this orchestrator already reserves identities
   this way for every reviewer launch this session and will continue to for
   round 2's reviewers once round 2 itself is authorized.
4. **"Reference issue #61 in the note."** — done, throughout this file and
   in the note template below.

## Manual precheck steps performed (equivalent to `spec-review-precheck.sh
epic-195-a7-compatibility 2 2 --edit-summary="..."`'s own pure-validation
checks, run by hand against the live repository state)

- Feature slug `epic-195-a7-compatibility` matches `^[a-z0-9][a-z0-9-]*$`;
  attempt `2` and round `2` are positive integers, round <= 3. OK.
- `--edit-summary` is non-empty (required for round > 1). OK.
- Not `--reset` (round > 1, not a new attempt). OK.
- `specs/epic-195-a7-compatibility/` exists, is a real directory, not a
  symlink, and canonicalizes inside the repository. OK (unchanged since
  round 1).
- `requirements.md`/`acceptance-tests.md` exist, are regular non-symlink
  files. OK.
- `plugins/sdd-review-loop/references/spec-review-calibration.md` exists,
  regular non-symlink file. OK.
- `reports/` root exists, canonicalizes correctly; `reports/spec-review/`
  exists, is a real directory, not a symlink. OK.
- `jq` is available. OK.
- `Spec-Review-Status` in `requirements.md` reads `Pending` (set by round
  1's own automated `--reset` transition, commit `ad67b5c`; unaffected by
  this defect). OK -- satisfies the non-reset "`Pending`" requirement.
- `reports/spec-review/epic-195-a7-compatibility/attempt-2/round-2/` does
  not yet exist (replay is not being attempted). OK.
- **Round > 1 check (the one step the automated script cannot complete):**
  the automated script's own `validate_contract` call against round 1's
  `spec-review-contract.json` fails solely on the single stale-vs-live
  `requirements_sha256` field described above -- every OTHER structural
  and cross-artifact check that function performs was independently
  verified true by this orchestrator when round 1's evidence was built and
  persisted (commit `c67bb80`): both reviewers' fixed outputs were
  hash-verified byte-for-byte against the values relayed by the coordinator
  before being persisted; the contract's `reviewers[].allowed_input_manifest`
  entries were diffed against each reviewer's own actual
  `allowed_input_manifest` and found to match exactly (sorted-by-path,
  verified with `jq`/`diff`, see the round-1 finalization work); the merged
  verdict (`NEEDS_WORK`, 0 Critical / 3 Major / 0 Minor) was computed by the
  same formula `validate_contract` itself uses, not asserted by hand.
  Round 1's own `precheck-result.json.requirements_sha256` (`0314f09c0...`)
  is confirmed stale (predates the same invocation's own `--reset` sed);
  round 1's own `spec-review-contract.json.requirements_sha256`
  (`b93bb798...`) is confirmed live-correct (matches both reviewers' own
  `allowed_input_manifest` entries and the file's actual sha256 at the time
  reviewers ran). This is the ONLY finding this manual check substitutes
  for the automated one, and it is a hash-provenance-bookkeeping defect in
  the precheck script itself, not a defect in round 1's own review content
  or verdict.
- Reviewed inputs changed from the prior round: round 1's
  `requirements.md` sha256 was `b93bb7985d757c6ef1674a89e16d7e499ea8ac46222d77fe1d94053d94ab5938`;
  the current, remedied file (commit `d1dae1b`: AC-007 track clarification,
  AC-043 for F5/F6, AC-034 enumeration update) sha256 is
  `5a2c278d8d9583a2b8d7f7b8096e38b02fc66d56f48849a80bcc7a18a8deef42`
  -- different, satisfying "reviewed inputs are unchanged from the prior
  round" must NOT hold (i.e. they must differ, and they do).

## The precheck-result.json this candidate would persist (verbatim, if authorized)

```json
{
  "schema": "spec-review-precheck/v1",
  "stage": "spec",
  "feature": "epic-195-a7-compatibility",
  "attempt": 2,
  "round": 2,
  "spec_review_status_field": "Pending",
  "requirements_sha256": "5a2c278d8d9583a2b8d7f7b8096e38b02fc66d56f48849a80bcc7a18a8deef42",
  "acceptance_sha256": "7b62c3391ddc58131cf1d1a16644e116b3030562e47a15fcd66ee4ef3c8aa24d",
  "calibration_sha256": "1ddd4ed250e30c0eb78a3d644adfefd21d0af5ea311444b526c8d840fc0649b8",
  "input_sha256": "9c1d3cc2e3ab8560fad2f0c27d0da1ba235a8998bc83eb3b3fa99ccb4b47c40c",
  "edit_summary": "Remedy round-1 reviewer-b findings (AMBIGUITY: AC-007 track ambiguity; EDGE-CASE-COVERAGE/DOWNSTREAM-READINESS: F5/F6 REQ-002 structural gap) via AC-007 F4 clarification and new AC-043/TEST-043 (commit d1dae1b); manual precheck fallback per AGENTS.md issue #61, working around the reset-hash-staleness defect this attempt's own round 1 surfaced (see reports/notes/repo-defect-spec-review-precheck-reset-hash-staleness.md)",
  "reset": false,
  "generated_at": "<fill in at authorization time, UTC>"
}
```

All four hashes above were independently computed against the live,
currently-committed files at authorship time (`shasum -a 256`), not copied
from any script output (there is none for this round, by construction of
the defect).

## Manual-precheck-note.md this candidate would persist (verbatim, if authorized)

```markdown
# Manual Precheck Note: epic-195-a7-compatibility / attempt 2 / round 2

Date: <fill in at authorization time, UTC>

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

<TO BE FILLED IN BY THE HUMAN APPROVER -- who, when, and the exact scope of
what is authorized (this round's manual precheck only; not a standing
exemption; not a waiver of any finding).>

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
```

## What remains after this candidate, if authorized

Reserve spec-reviewer-a's identity for attempt-2/round-2 (ledger sequence
331) exactly as rounds 1's reviewers were reserved, write the launch
prompt, and proceed through the same independent two-reviewer sequence
already used this session -- no change to the actual review process, only
to how this one round's own precheck evidence was produced.
