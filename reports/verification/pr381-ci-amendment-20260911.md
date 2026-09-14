# PR #381 CI amendment — 2026-09-11

This is the current change record for the user-approved RT-20260909-001
amendment. The user subsequently directed this repository improvement to
proceed directly from Issues and PRs, without SDD procedural review rounds.
That direction does not waive protection hooks, existing CI checks, or truthful
test results. No new SDD review PASS is asserted here.

The historical `specs/epic-136-phase3/requirements.md` is restored byte-for-byte
to its pre-amendment version from `1f449df6^`. Its Passed status describes the
historical review only. That specification and its historical evidence are not
the approval or verification evidence for the amendment below.

## Current requirements (supersede historical dependency equality)

Preserve every existing mandatory dependency and check, and additionally
require successful completion of the full POSIX inventory. Preserve all jobs,
steps, commands, result assertions, platforms, timeouts and dependency pins.
Dependency-list byte equality is not required: adding mandatory coverage is
required. This supersedes the old dependency-equality language in REQ-004,
AC-017, OQ-5, preventive restructuring, Edge Cases and Risks. The historical
investigation's BL-001 and INV-019..023 are baseline evidence, not a current
job inventory. AC-016 step preservation and AC-018 optional-workflow isolation
remain required.

`required-checks` must depend on `posix-regression` and assert its result equals
`success`, while retaining every existing dependency and success assertion.
It must run with `if: always()`. Failure, cancellation, skipped, missing and
unknown results must fail closed. Tests must execute the actual aggregator
body with synthetic results, detect independent deletion of the POSIX
dependency and assertion, and test every existing dependency's non-success
results independently. Preserve historical step-prefix coverage and all four
suite registrations. Designed-red and SKIP are not successful execution
evidence. Optional sibling workflows remain isolated.

Recheck the live dependency graph and GitHub required contexts immediately
before integration against the pre-change baseline. At commit `067d4b23`,
`.github/workflows/test.yml:1165` lists eight dependencies but omits the
POSIX job defined at line 24; the aggregator body likewise omits its result.
This is an outstanding implementation defect, not a passed condition.

## Completion evidence still required

- Apply and verify the aggregator change, preserving existing coverage.
- Pass the full POSIX inventory and mandatory native CI.
- Confirm the exact PR head is green before merging. No merge is authorized
  on the strength of this document or historical SDD statuses alone.
