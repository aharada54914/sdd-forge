# Task Review Report: workflow-state-integrity — Round 1 / Attempt 3

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | workflow-state-integrity |
| Round | 1 of 3 |
| Attempt | 3 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-06-27T06:18:29Z |

## Reviewer-A Findings

None.

## Reviewer-B Findings

1. `T002-VERIFICATION-PATH` (Major): T-002 promises executable schema and
   invalid-fixture validation but does not name a test harness in Planned Files.
2. `PLANNED-FILE-PRECISION` (Major): T-004 through T-006 use grouped file
   descriptions rather than exact paths.

## Proposed Changes

- Add `tests/workflow-state-registry.tests.sh`,
  `tests/workflow-state-registry.tests.ps1`, and the parity test to T-002.
- Enumerate exact repository/CI integration test and workflow paths in T-004.
- Enumerate exact downstream suites and workflow documentation in T-005.
- Enumerate all six plugin manifests, both marketplace manifests,
  `tests/validate-repository.ps1`, and `CHANGELOG.md` in T-006.

## Next Steps

Human approval is required before editing `tasks.md`. Re-run attempt 3 round 2
with an edit summary after the changes.
