# This round replaced an earlier attempt-7 round-1. Read this first.

An earlier attempt 7 round 1 ran on 2026-08-25 and is **not** the review
recorded here. It is preserved in git:

- `3ccd7415` — the earlier round's artifacts and both reviewers' verdicts

Recover it with:

    git restore --source=3ccd7415 -- reports/spec-review/epic-195-a7-compatibility/attempt-7/round-1

## Why it was replaced, and why a reset rather than a round 2

The earlier round returned NEEDS_WORK on one Critical, found by both reviewers
independently: `investigation.md` cited an amendment commit in abbreviated
eight-character form where the calibration requires full hashes. That defect
was corrected in commit `544cfa33aa9d0b6c4a1b6ba9c1e4e04b3d97a17e`'s
predecessor chain and the record now carries both commits in full.

A round 2 was the intended next step and is refused, by
`plugins/sdd-review-loop/scripts/spec-review-precheck.sh:343-344`:

    [[ "$requirements_sha" != "$prior_requirements_sha" || "$acceptance_sha" != "$prior_acceptance_sha" ]] \
      || fail "reviewed inputs are unchanged from the prior round"

The round's only defect was in `investigation.md`. The remedy therefore touched
`investigation.md` and nothing else, leaving `requirements.md` and
`acceptance-tests.md` byte-identical — so the gate reads the inputs as
unchanged and refuses the round.

Opening attempt 8 instead is refused by the same script at line 354, because
attempt 7's last round holds `NEEDS_WORK`, which is not a terminal verdict, and
`NEEDS_WORK` can only become terminal by passing a later round that cannot be
opened.

Resetting attempt 7 is the one remaining legal transition: the reset inspects
attempt 6, whose round-3 contract is `BLOCKED` and therefore terminal. It
requires the round destination not to exist (line 138, "replay is forbidden"),
which is why the earlier artifacts were removed from the working tree after
being committed.

## The defect this exposes, stated as a defect

This is the second distinct dead end the spec-review state machine admits, and
it has the same shape as the first: **a round whose only defect lies in
`investigation.md` cannot be remedied and re-reviewed within its attempt.** The
round-advance gate tests only `requirements.md` and `acceptance-tests.md` for
change, while the Amendment Re-Review Context evidence bar — a spec-review-owned
gate that reviewers are instructed to judge, and which produced Critical
findings in three consecutive rounds — lives entirely in `investigation.md`.
A reviewer can therefore raise a Critical the workflow provides no legal way to
clear inside the attempt.

The only escape is a reset, which replaces the artifacts documenting how the
state was reached. Evidence legibility is preserved here only because the
superseded round was committed first and is named above.

## What this round reviews

`investigation.md` with both previously abbreviated commit citations superseded
by their full 40-character hashes, and with the Round-7 extension recording the
mechanical pre-commit checklist adopted in response to three consecutive rounds
failing on this record rather than on the specification.
