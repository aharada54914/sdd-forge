# This round replaced an earlier attempt-7 round-1. Read this first.

The earlier round is preserved in git at `3436ed22`, and in `3ccd7415` before
that. Recover with:

    git restore --source=3436ed22 -- reports/spec-review/epic-195-a7-compatibility/attempt-7/round-1

## Why a reset rather than a round 2, for the second time

The earlier round returned NEEDS_WORK on one Critical: three SHA-256 document
back-references in `investigation.md` were truncated to twelve characters plus
an ellipsis. The remedy touched `investigation.md` and nothing else.

`plugins/sdd-review-loop/scripts/spec-review-precheck.sh` advances a round only
when `requirements.md` or `acceptance-tests.md` changed, so it refused:

    ERROR: spec-review-precheck: reviewed inputs are unchanged from the prior round

Opening attempt 8 is refused too, because attempt 7's last round held
`NEEDS_WORK`, which is not terminal. Resetting attempt 7 is the one remaining
legal transition, and requires the round destination not to exist.

This is the same dead end recorded as a defect in `investigation.md`'s Round-8
extension, now demonstrated twice in consecutive rounds: a defect whose only
remedy lies in `investigation.md` cannot be cleared inside its own attempt.

## What this round reviews

Three truncated digests expanded to full values, appended rather than
rewritten, and a pre-commit audit widened to run over the entire Amendment
Re-Review Context section against all four evidence-bar elements. That audit
passes over the whole section.
