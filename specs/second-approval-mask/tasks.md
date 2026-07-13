# Tasks: second-approval-mask

Task-Review-Status: Passed

## T-001 Delete Second Approval lines in the task-stage provenance normalization

Source Issue: docs/review-tickets/RT-20260712-003.yml

Approval: Approved (sudo 2026-07-12T10:55:10Z)

Status: Done

Risk: high

Risk Rationale: The change edits both workflow-state validator twins —
protected enforcement-chain gate scripts whose stale-hash rule guards every
registered feature's task plan. An over-broad mask would silently weaken
tamper evidence repo-wide; an under-scoped or twin-divergent one leaves the
critical two-person flow deadlocked (RT-20260712-003) or splits decisions
across platforms. The validators gate Done for all features, so a botched
apply blocks every quality gate.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: enabled

Requirements: REQ-001

Depends On: none

Planned Files:
- `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` (protected — human-copy)
- `plugins/sdd-quality-loop/scripts/check-workflow-state.ps1` (protected — human-copy)
- `tests/second-approval-mask.tests.sh` (new, agent-editable)
- `tests/run-all.sh` (agent-editable, one-line registration)

Data Migration: none

Breaking API: no; CLI, exit codes, and diagnostic format unchanged. Existing
task-review contract hashes are unaffected because no frozen tasks.md carries
a column-0 second-approval line (deletion is a no-op on them).

Rollback: human re-copies the prior `check-workflow-state.{sh,ps1}` from git
history; revert the test commit.

### Goal

A human recording the critical-tier second approval (the `Second Approval:`
field, set to its Approved value with a named id and ISO timestamp by a
distinct human, per REQ-001) after task-review must not trip
`task plan hash is stale`, while every other post-freeze edit to tasks.md
keeps tripping it, identically under the sh and ps1 twins.

### Must Read

- `specs/second-approval-mask/requirements.md`
- `specs/second-approval-mask/design.md`
- `specs/second-approval-mask/acceptance-tests.md`
- `specs/second-approval-mask/security-spec.md`
- `docs/review-tickets/RT-20260712-003.yml`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write TEST-001..TEST-004 first (fixture corpus per acceptance-tests.md),
  capturing RED against the pre-fix live twins.
- Add the deletion rule to `normalized_hash()` (sh sed `/^Second Approval:/d`)
  and `Get-NormalizedHash` (ps1 regex with terminator consumption), staged
  under `specs/second-approval-mask/human-copy/` with a SHA-256 MANIFEST.
- Register the suite in `tests/run-all.sh`.

### Done When

- [ ] A `Second Approval:` line recorded post-freeze (Approved value, named
  id, ISO timestamp — written by the test fixture, standing in for the human)
  validates `workflow-state: ok` under both twins (AC-001).
- [ ] Arbitrary-line and checkbox tampering still trip the stale-hash
  diagnostic under both twins (AC-002).
- [ ] LF and CRLF corpora behave identically with byte-identical normal
  forms (AC-003).
- [ ] sh/ps1 parity holds across the corpus and the suite is registered in
  tests/run-all.sh (AC-004).
- [ ] Gate evidence records live == staged SHA-256 for both applied twins
  (AC-005, gate phase).
- [ ] Red→Green evidence recorded in the implementation report.
- [ ] `bash tests/second-approval-mask.tests.sh` exits 0 (focused suite), the
  full-registry `check-workflow-state.sh` and `.ps1` runs print
  `workflow-state: ok`, and `tests/workflow-state-parity.tests.sh`,
  `tests/workflow-state-ci-integration.tests.sh`, and
  `tests/workflow-state-registry.tests.sh` all exit 0 (design.md Test
  Strategy steps 1-4).
- [ ] An independent quality-gate verdict records PASS with traceability and
  high-risk provenance.
- [ ] Cross-model verification consensus recorded (security-sensitive task).

### Out of Scope

- check-task-state, the hook guard, spec/impl-stage normalization, registry
  schema, retroactive contract re-hashing (requirements.md Non-goals).

### Blockers

None
