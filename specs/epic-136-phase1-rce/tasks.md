# Tasks: epic-136-phase1-rce

Task-Review-Status: Passed

Source: Issue #108 / requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## T-001 Correct the SDD_SUDO HMAC data boundary and regression coverage

Source Issue: https://github.com/aharada54914/sdd-forge/issues/108

Approval: Approved (sudo 2026-07-10T11:45:00Z)

Status: Done

Risk: high

Risk Rationale: This task changes the authorization boundary that grants
SDD_SUDO consent and handles restricted HMAC key material. A fail-open or
source-injection regression could authorize an external panelist path or expose
secret-derived data (REQ-001 through REQ-005; security-spec.md B1/B2).

Required Workflow: tdd

Requirements: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005

Planned Files:
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh`
- `tests/prepare-panelist.tests.sh`
- `tests/prepare-panelist.tests.ps1`

Data Migration: none

Breaking API: no; preserve the SDD_SUDO token format, canonical message order,
exit codes, consent labels, and sanitized bundle contract.

Rollback: revert this task's implementation commit; the previous behavior is
restored only as an emergency rollback and must not be treated as an accepted
security state.

### Goal

Replace token/key interpolation into the shell verifier's Python source with a
quoted heredoc and explicitly named environment reads, while retaining valid
consent only for a complete valid token. Add isolated real-HMAC, tamper,
invalid-condition, hostile-input, and PowerShell-parity regressions.

### Must Read

- `specs/epic-136-phase1-rce/requirements.md`
- `specs/epic-136-phase1-rce/design.md`
- `specs/epic-136-phase1-rce/acceptance-tests.md`
- `specs/epic-136-phase1-rce/security-spec.md`
- `specs/epic-136-phase1-rce/traceability.md`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write focused tests first for TEST-001 through TEST-007, preserving fixture
  isolation and avoiding real credentials, network calls, and repository
  SDD_SUDO state.
- Capture failing Red evidence before the shell correction, including a valid
  real-HMAC case and at least one hostile source-construction payload.
- Change only `prepare-panelist-input.sh`'s HMAC verifier boundary: use a
  quoted Python heredoc, pass named operands through the process environment,
  construct the existing canonical message, and compare with constant time.
- Extend Bash and PowerShell focused suites to prove AC-002 through AC-007,
  including correctly signed invalid nonce, TTL, and repository-binding cases.
- Keep the PowerShell implementation behavior aligned; do not create an
  alternate consent rule or change the token contract.

### Done When

- [ ] TEST-001 proves no token/key operand is rendered into executable Python
  source, and AC-001 passes.
- [ ] TEST-002 and TEST-003 prove real-HMAC acceptance and altered-field denial
  with the expected bundle/no-bundle outcomes (AC-002, AC-003).
- [ ] TEST-004 and TEST-006 prove hostile operands and independently invalid,
  correctly signed nonce/TTL/repository cases cannot create consent or a bundle
  (AC-004, AC-006).
- [ ] TEST-005 proves PowerShell real-HMAC acceptance and tampered-field denial
  against the existing .NET byte-array verifier (AC-005).
- [ ] TEST-007 proves fixture isolation, no real secret, and no network access
  (AC-007).
- [ ] Red-to-Green evidence is recorded in the implementation report before and
  after the correction; the high-risk preflight records each persisted evidence
  field, counterpart, and a failing mismatch test.
- [ ] The focused Bash and PowerShell regression suites and the relevant
  repository gate pass.
- [ ] An independent quality-gate verdict records PASS with linked verification
  evidence and high-risk provenance.

### Out of Scope

- Token format, nonce/TTL/repository policy, and `SDD_SUDO_SKIP_SIG=1`
  scaffolding policy.
- Panelist execution, sanitization, evidence contracts, UI, network services,
  or persistent storage.

### Blockers

None
