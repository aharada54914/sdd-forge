# T-006 quality-gate evidence

Task: T-006  
Feature: epic-136-phase2-gates  
Risk: critical  
Evidence basis: implementation report `reports/implementation/epic-136-phase2-gates/T-006.md`

## Deterministic checks

- RED baseline: `tests/phase2-guard-invariants.tests.ps1` exited 1 with 55
  passed and 13 expected TEST-013 contract failures against the former
  path-based runner (`verification/T-006/red.log`).
- GREEN: PowerShell focused suite passed 68/68.
- GREEN: Bash focused suite passed 33/33.
- GREEN: `generate-guard-invariants.py --check` passed without writing.
- GREEN: `check-workflow-state.ps1 --feature epic-136-phase2-gates` returned
  `workflow-state: ok`.
- The green suite covers anchored no-follow root/canonical/manifest/source
  reads, retained-handle hashing and copying, held destination parents,
  same-parent temporary verification and cleanup, hard-link alias safety,
  injected preparation failure, fixed-index rename-prefix semantics,
  complete rollback, native API denial, and the post-install R-10 workflow
  guard (`verification/T-006/green.log`).
- The security review found no credential, token, or API-key literals in the
  staged candidate (`verification/T-006/security-review.md`).

## Contract and traceability

- All required contract checks are green in
  `verification/T-006.contract.json`.
- The implementation report records the critical preflight mismatch tests,
  RED/GREEN evidence, ADR 0011 decision, and output hashes.
- Cross-model implementation review passed with two distinct blind vendors
  over input digest `cd3c5d65606f0c809a6616ef91ac785d4e2eba00bb4464ae54210567a0c3afe6`:
  `verification/T-006.cross-model.json`.

## Downstream critical gate status

This report records implementation verification only. The signed clean-tree
evidence bundle and distinct second-human approval remain downstream
requirements for a critical-risk task; until those are independently present,
the task must remain `Implementation Complete` rather than `Done`.
