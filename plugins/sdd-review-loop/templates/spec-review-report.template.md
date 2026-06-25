# Specification Review Report: <feature>

- Attempt: <attempt>
- Round: <round>
- Input hashes: requirements `<sha256>`, acceptance tests `<sha256>`
- Reviewer A: run `<fresh-run-id>`, host session `<unique-session-id>`, allowed input manifest `<path-and-hash-list>`
- Reviewer B: run `<fresh-run-id>`, host session `<unique-session-id>`, allowed input manifest `<path-and-hash-list>`
- Verdict: `<PASS|NEEDS_WORK|BLOCKED>`
- Warning count: `<number>`

## Integrated Summary

Only check IDs, severities, and counts belong here. Do not copy reviewer raw
findings into a reviewer input.

`integrated-verdict.json` is derived from both validated reviewer outputs. A
Critical or Major finding produces `NEEDS_WORK` before round three and
`BLOCKED` in round three. A round-three Minor-only result produces `PASS` with
the Minor count in `warningCount`.

## Transition

The orchestrator records the validated contract and is the sole writer of
`Spec-Review-Status`.
