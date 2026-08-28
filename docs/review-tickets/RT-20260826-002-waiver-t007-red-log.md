# Waiver — risk-adaptive-layer T-007 has no original red log

Status: Recorded (maintainer decision, 2026-08-26)
Task: `specs/risk-adaptive-layer/tasks.md` T-007 — Evidence signing + two-person
approval (Critical controls)
Risk: critical · Required Workflow: tdd

## What is being waived

T-007's `Required Workflow: tdd` obliges a preserved red→green differential
from implementation time. None exists, and none can be produced, because the
work predates the per-task SDD cycle: T-007 was implemented and merged on
2026-06-14 (PR #16, merge `4a215ed`) by three commits — `7b59a1b4` (HMAC sign
and verify critical bundles), `f6a6470f` (two-person approval for critical
Done), `1b558f95` (the Second Approval hook guard). The implementation report
states this in its own words: "The per-task cycle was not run in real-time;
this records the shipped deliverable."

This waiver covers the ORIGINAL red log only. It does not waive the
requirement that the delivered enforcement be demonstrably real; that
obligation is met by the compensating control below. Same shape and same
reasoning as `RT-20260821-005-waiver-red-log.md`, which the maintainer
approved for T-006 of this feature on 2026-08-23.

## Compensating control (captured 2026-08-26, this branch)

A present-day differential proving each of the three delivered controls is
load-bearing on every runtime that implements it.

- `specs/risk-adaptive-layer/verification/T-007.red-compensating-20260826.log`
  (sha256 `5d5d75b66ce1ad92ab662c244371fcfa785d076e4ecc5bf476f5fe2425843c0a`):
  THREE mutations in a `git clone --no-hardlinks` scratch tree, each applied
  to every runtime twin of the control at once.
  - **Mutation A (signing)** — the HMAC comparison guard neutered in
    `check-evidence-bundle.sh` and `.ps1`. sh: exit 1, PASS 160 / FAIL 1,
    failing `T-007a.3`. ps1: exit 1, throw at `scripts.tests.ps1:2203`, raised
    by the same assertion `T-007a.3`.
  - **Mutation B (two-person approval)** — the distinct-approver guard
    neutered in `check-task-state.sh` and `.ps1`. sh: exit 1, PASS 160 /
    FAIL 1, failing `T-007b.3`. ps1: exit 1, throw at
    `scripts.tests.ps1:2500`, raised by the same assertion `T-007b.3`.
  - **Mutation C (Second Approval hook guard)** -- added 2026-08-28, see the
    correction below. Detection neutered in all THREE guard twins at once
    (`sdd-hook-guard.py`, `sdd-hook-guard.js`, and all three inline pattern
    literals in `sdd-hook-guard.ps1` -- it carries literals rather than one
    constant, so changing fewer than three would have left a detection path
    alive). `tests/guards.tests.sh`: exit 1, 3 failures, every one a Second
    Approval assertion, across the sh, py and node twins.
    `tests/hooks.tests.ps1`: exit 1, 1 failure. All four are on the SUDO path,
    which is precisely the property the guard exists for -- a valid sudo token
    must not bypass the mark.
- `specs/risk-adaptive-layer/verification/T-007.green-compensating-20260826.log`
  (sha256 `5b02069102ed2e132b4c869787db02da9f5aad78b29eb56e467e2c69c573af0d`):
  pristine tree — sh exit 0, PASS 161 / FAIL 0 over 21 distinct T-007
  assertion ids; ps1 exit 0 over 20.

Mutations A and B each redden exactly ONE assertion, the SAME id on both
runtimes. All three were reverted between phases and the tree re-run to exit 0,
so no red is a residue of another.

## Correction, 2026-08-28 -- the original claim was an overclaim

As first filed, this waiver said the compensating control was "a present-day
differential proving **each delivered control** is load-bearing on BOTH
runtimes", and named three delivery commits including `1b558f95`, the Second
Approval hook guard. It was not. Both captures ran only `tests/gates.tests.sh`
and `tests/scripts.tests.ps1`; the hook guard is asserted in
`tests/guards.tests.sh` and `tests/hooks.tests.ps1`, which neither capture
executed. That control had no red and no green anywhere in the evidence, while
this waiver's own sentence claimed otherwise.

Found by the Anthropic panelist during cross-model verification, not by me.
Recorded rather than quietly fixed, because the failure mode is the point: a
differential can be rigorous about the mutations it does perform and still fail
to cover what its summary sentence claims, and the sentence is what a reader
carries away. The gap is closed by Mutation C above, and the claim is true as
written for the first time.

## Method note — a first attempt was rejected as unsound

The differential was first taken by mutating only the sh masters. The ps1
suite stayed GREEN, because it exercises the ps1 implementations, which were
untouched. Had that capture been filed, it would have carried a header
claiming a two-control differential while proving nothing about half the
delivery — the exact failure mode this feature's gates have repeatedly charged
as a "half-width" defect. The capture was redone with both twins mutated
together. Recorded here because the discarded attempt is the part most likely
to be repeated.

## Why the compensating form is acceptable here

The original red would have proved that the tests preceded the code. The
compensating red proves something narrower but still load-bearing: that the
tests shipped alongside the code are not vacuous, and that removing the
enforcement they describe makes them fail. For a task whose deliverable is
already merged and in service, the second property is the one that still has
consequences. What is genuinely lost — evidence of test-first sequencing — is
lost permanently and is not recoverable by any means; this waiver records that
rather than papering over it.

## Scope and limits

- Applies to T-007 of `risk-adaptive-layer` only.
- Does NOT waive: the two-person approval marks (recorded separately by the
  maintainer in tasks.md), cross-model verification, the evidence bundle, the
  verification contract, or the quality gate itself.
- The compensating logs are declared in T-007's implementation report
  `## Outputs` table with the digests above. If either log is re-captured,
  this waiver's digests go stale and must be updated in the SAME change — the
  binding IS the control, and letting it drift is what broke the equivalent
  waiver for T-006 twice.
