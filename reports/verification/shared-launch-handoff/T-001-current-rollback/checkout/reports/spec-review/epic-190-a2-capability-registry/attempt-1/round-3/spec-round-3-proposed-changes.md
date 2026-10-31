# Proposed Changes: epic-190-a2-capability-registry spec review attempt 1 round 3 (BLOCKED)

## Change 1 — Cover registry_digest's CLI selector edge cases (Major, EDGE-CASE-COVERAGE)

REQ-004 states the `registry_digest` generator's fragment-selection input is
`--capability-ids`, `--gate-ids`, or both (at least one required, or
`--whole` for the entire Registry). Add to AC-024/TEST-024 (or a new AC/TEST
row) two fixtures:

1. Invoking the script with none of `--capability-ids`/`--gate-ids`/
   `--whole` supplied is a hard failure with a named diagnostic (not a
   silent default to `--whole` or to an empty fragment).
2. Invoking the script with both `--capability-ids` and `--gate-ids`
   supplied together (the explicitly permitted "or both" case) produces the
   union fragment (both ID sets' entries, still deduped/stable-sorted per
   the existing AC-024 rule).

## Disposition

This is the only remaining Major finding after three rounds; attempt 1 is
now `BLOCKED` per the state-transition table's round-3 rule (Major/Critical
FAIL at round 3 -> `BLOCKED`, not `NEEDS_WORK`). `Spec-Review-Status` stays
`Pending`. Per SKILL.md, resuming requires `scripts/spec-review-precheck.sh
epic-190-a2-capability-registry 2 1 --reset` (preserving this attempt's
evidence) once Change 1 above is applied and committed as
`docs(spec): ...`, followed by a fresh reviewer-A/reviewer-B pair for
attempt 2 round 1. The orchestrator has not taken this step; it requires the
human's go-ahead given attempt 1's round budget is exhausted.
