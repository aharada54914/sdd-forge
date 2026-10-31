# Bootstrap Review-Gate Repair Evidence

Feature: workflow-state-integrity
Recorded: 2026-06-27
Migration baseline: `0369c8c96de2eb3179868d1949d66644488f65aa`

## Trigger

During specification review, a valid predecessor contract created while the
canonical status was `Pending` became stale after the reviewed artifact changed
only its status header to `Passed`. Downstream prechecks also interpreted
repository-root absolute reviewer manifests inconsistently.

Observed failure:

```text
ERROR: spec-review-precheck: prior round contract is malformed or does not require work
```

## Root cause

- Review-contract hashes included the mutable stage-status header.
- Shell and PowerShell prechecks did not consistently canonicalize
  repository-root absolute artifact paths before applying their allowlists.

## Bootstrap exception

The precheck repair was made before task approval because the defect blocked
the mandatory review chain needed to approve this specification. The change is
restricted to status-neutral canonical hashing and repository-contained path
normalization. It does not relax reviewer identity, verdict, extra-artifact,
stale-content, traversal, or repository-escape validation.

## Verification

The regression coverage is retained in:

- `tests/spec-review-loop.tests.sh`
- `tests/downstream-review-precheck.tests.sh`
- `tests/downstream-review-precheck.tests.ps1`
- `tests/downstream-review-precheck-parity.tests.sh`

The repair is formally completed and independently reviewed under T-001.
