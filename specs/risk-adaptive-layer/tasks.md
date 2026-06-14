# Tasks: risk-adaptive-layer

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

> Note: the `Risk:` / `Required Workflow:` / `Requirements:` / `Second Approval:`
> fields below are the very fields this feature introduces (REQ-001, REQ-007).
> This file is authored in the target format to dogfood it. Tasks are phased so
> each gate change lands tests-first (design.md "Migration"). Sequence: A→F.

---

## T-001 Risk descriptor + policy docs + ID rules

Source Issue: investigation.md INV-001, INV-004
Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: template/reference/doc changes only; no gate logic yet, but foundational for all later tasks.
Required Workflow: acceptance-first
Requirements: REQ-001, REQ-004

### Goal
Add `Risk` / `Risk Rationale` / `Required Workflow` / `Requirements` fields to
`tasks.template.md` and `ai-task.template.md`; add `risk` / `required_workflow` /
`spec_revision` / per-check `requirement_ids` / `red_evidence` / `green_evidence`
to `verification-contract.template.json` and `evidence-bundle.template.json`
(schema only, optional); add `AC-NNN` and `TEST-NNN` prefixes + cross-ref rules to
`spec-id-rules.md`; add `Requirement`/`Test ID` columns to
`acceptance-tests.template.md` and `traceability.template.md`; author
`references/risk-classification-policy.md` and `references/risk-gate-matrix.md`.

### Must Read
- specs/risk-adaptive-layer/requirements.md
- specs/risk-adaptive-layer/design.md  (§Data Plan 1–4)
- specs/risk-adaptive-layer/acceptance-tests.md
- specs/risk-adaptive-layer/traceability.md

### Scope
Templates, references, ID rules. No script/gate behavior change (those are T-002+).

### Done When
- [ ] Templates and references updated per design.md §Data Plan
- [ ] risk-classification-policy.md + risk-gate-matrix.md authored (matrix matches design.md §3)
- [ ] Required tests added or updated (presence/format assertions)
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated

### Out of Scope
Any change to gate scripts.

### Blockers
None

---

## T-002 check-risk deterministic gate

Source Issue: investigation.md INV-001
Approval: Draft
Status: Planned
Risk: high
Risk Rationale: introduces a new fail-closed deterministic control that other gates depend on; must be cross-runtime correct and unforgeable.
Required Workflow: tdd
Requirements: REQ-001

### Goal
Add `check-risk.sh` + `check-risk.ps1` (python-preferred inline, PowerShell
fallback, matching existing dispatch). Exit 1 when a task's `Risk` is missing,
not in {low,medium,high,critical}, or has an empty `Risk Rationale`; exit 0 otherwise.

### Must Read
- specs/risk-adaptive-layer/design.md  (§API/Contract, §Migration)
- plugins/sdd-quality-loop/scripts/check-contract.sh  (dispatch pattern to mirror)

### Scope
New gate scripts + their tests in `tests/gates.tests.sh` and `tests/scripts.tests.ps1`.

### Done When
- [ ] Red→Green evidence captured (failing fixture first, then passing)
- [ ] check-risk.{sh,ps1} implemented with identical behavior (parity test)
- [ ] Independent review verdict recorded
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated

### Out of Scope
check-contract changes.

### Blockers
T-001

---

## T-003 Risk-aware check-contract (tier-minimum superset)

Source Issue: investigation.md INV-002
Approval: Draft
Status: Planned
Risk: high
Risk Rationale: modifies the core Default-FAIL gate; a regression here weakens every adopter's assurance. Backward compatibility is load-bearing.
Required Workflow: tdd
Requirements: REQ-002

### Goal
Make `check-contract.{sh,ps1}` read `risk` and enforce that the contract's
`required:true` set is a superset of the risk tier's minimum (design.md §3),
failing closed otherwise. `risk` absent ⇒ medium-baseline (today's behavior).
Keep every existing rule (duplicate ids, evidence path safety, waiver, baseline protection).

### Must Read
- specs/risk-adaptive-layer/design.md (§3 matrix, §Migration)
- plugins/sdd-quality-loop/scripts/check-contract.sh (full)
- plugins/sdd-quality-loop/references/risk-gate-matrix.md (from T-001)

### Scope
check-contract.{sh,ps1} + tests. A test asserts the encoded tier-minimums equal the matrix doc.

### Done When
- [ ] Red→Green evidence captured
- [ ] All pre-feature check-contract fixtures still pass (regression)
- [ ] New tier-superset fixtures (fail + pass) for each tier, both runtimes
- [ ] Independent review verdict recorded
- [ ] Implementation report + quality gate + traceability updated

### Out of Scope
red/green enforcement (T-004), traceability gate (T-005).

### Blockers
T-001, T-002

---

## T-004 Red→Green evidence enforcement

Source Issue: investigation.md INV-003
Approval: Draft
Status: Planned
Risk: high
Risk Rationale: enforces TDD proof for high/critical; incorrect logic would either block valid work or admit fake TDD.
Required Workflow: tdd
Requirements: REQ-003

### Goal
In `check-contract.{sh,ps1}`, when `required_workflow == tdd`, require test-type
checks to carry non-empty `red_evidence` and `green_evidence` (both existing,
non-empty, path-safe). Document red-evidence-for-refactor case (differential baseline).

### Must Read
- specs/risk-adaptive-layer/design.md (§2, §3, §Edge Cases)
- plugins/sdd-quality-loop/references/differential-test-policy.md

### Done When
- [ ] Red→Green evidence captured
- [ ] Fixtures: tdd without red ⇒ fail; with red+green ⇒ pass (both runtimes)
- [ ] Regression green; independent review recorded; report + quality gate + traceability updated

### Out of Scope
Bundle provenance (T-006).

### Blockers
T-003

---

## T-005 check-traceability gate + machine-readable links

Source Issue: investigation.md INV-004
Approval: Draft
Status: Planned
Risk: high
Risk Rationale: a new control that auditors rely on for requirement coverage; must be deterministic and not give false PASS.
Required Workflow: tdd
Requirements: REQ-004

### Goal
Add `check-traceability.{sh,ps1}` validating `specs/<feature>/traceability.json`
(every REQ→AC, AC→TEST; high/critical TEST→existing evidence). Update
`acceptance-tests.template.md` / `traceability.template.md` consumers.

### Must Read
- specs/risk-adaptive-layer/design.md (§4)
- plugins/sdd-quality-loop/scripts/check-task-state.sh (JSON-handling pattern)

### Done When
- [ ] Red→Green evidence captured
- [ ] Fixtures: broken chain ⇒ fail; complete ⇒ pass (both runtimes)
- [ ] Regression green; independent review recorded; report + quality gate + traceability updated

### Blockers
T-001

---

## T-006 Evidence bundle provenance + spec_revision

Source Issue: investigation.md INV-005, INV-006
Approval: Draft
Status: Planned
Risk: high
Risk Rationale: extends the tamper-evident evidence chain; bugs here corrupt audit trust. Must keep generator-only authoring (STR-003).
Required Workflow: tdd
Requirements: REQ-005, REQ-006

### Goal
Extend `generate-evidence-bundle.{sh,ps1}` to compute and emit `risk`,
`required_workflow`, `spec_revision` (sha256 of requirements+design+acceptance),
`build_env`, `builder`, per-check `command`/`exit_code`/timestamps, and
`review_verdict`. Extend `check-evidence-bundle.{sh,ps1}` to validate these for
high/critical. Keep existing hash + git-ancestry checks.

### Must Read
- specs/risk-adaptive-layer/design.md (§5)
- plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh (full)
- plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh (full)

### Done When
- [ ] Red→Green evidence captured
- [ ] Fixtures: high bundle missing provenance ⇒ fail; complete ⇒ pass (both runtimes)
- [ ] Pre-feature bundle fixtures still pass (regression)
- [ ] Independent review recorded; report + quality gate + traceability updated

### Blockers
T-003

---

## T-007 Evidence signing + two-person approval (Critical controls)

Source Issue: investigation.md INV-006, INV-007
Approval: Draft
Second Approval: (required — Risk: critical; see design.md §7. For bootstrap, the
sole maintainer records both with rationale until a second approver exists.)
Status: Planned
Risk: critical
Risk Rationale: introduces cryptographic signing of evidence AND a new approval control; the highest-trust surface in the feature. Demonstrates the Critical workflow on itself.
Required Workflow: tdd
Requirements: REQ-006, REQ-007

### Goal
Add HMAC-SHA256 local bundle signing (external key, sudo-key pattern) +
verification in `check-evidence-bundle`; wire sigstore path in CI. Extend
`check-task-state.{sh,ps1}` to require a distinct `Second Approval` for critical
Done; extend `sdd-hook-guard.{py,sh,ps1,js}` so agents cannot write `Second
Approval` and sudo cannot auto-pass it.

### Must Read
- specs/risk-adaptive-layer/design.md (§6, §7)
- plugins/sdd-quality-loop/scripts/sdd-hook-guard.py (approval/WFI guard logic)
- plugins/sdd-quality-loop/references/sudo-mode-policy.md

### Done When
- [ ] Red→Green evidence captured
- [ ] Fixtures: bad signature ⇒ fail; valid ⇒ pass; critical Done without 2nd approver ⇒ fail; agent-write of 2nd approval blocked; sudo cannot bypass
- [ ] Regression green (existing guard tests intact)
- [ ] Independent review recorded; second approver recorded; bundle signed; report + quality gate + traceability updated

### Blockers
T-006

---

## T-008 CI/branch-protection codification + merge queue

Source Issue: investigation.md INV-008
Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: governance config; misconfig is visible and reversible, but affects merge safety.
Required Workflow: acceptance-first
Requirements: REQ-008

### Goal
Add `.github/rulesets/main.json`, root `CODEOWNERS`, `merge_group` trigger +
required-checks summary job in `test.yml`, gate `release.yml` on CI success, route
`self-improvement.yml` PRs through required checks, and `scripts/apply-branch-protection.sh`
(gh API with free-tier manual fallback). Document in workflow-guide.

### Must Read
- specs/risk-adaptive-layer/design.md (§Deployment/CI)
- .github/workflows/test.yml, release.yml, self-improvement.yml

### Done When
- [ ] rulesets/CODEOWNERS parse-valid; merge_group present; release gated
- [ ] apply script runs (or documents manual steps) without error
- [ ] Tests/lint for config; report + quality gate + traceability updated

### Blockers
None (parallelizable with B–D)

---

## T-009 Threat model + capability matrix + model routing

Source Issue: investigation.md INV-009, INV-010
Approval: Draft
Status: Planned
Risk: low
Risk Rationale: documentation + agent config; no executable control surface.
Required Workflow: test-after
Requirements: REQ-009, REQ-010

### Goal
Author `docs/THREAT-MODEL.md` (consolidate sudo/kill-switch/install/risk-layer
threats, trust assumptions, mitigations) and `docs/agent-capability-matrix.md`
(per-agent tool scopes). Add `model` / reasoning routing to `.codex/agents/sdd-investigator.toml`
and `sdd-evaluator.toml` (cost-aware: cheap for investigate, stronger for evaluate).

### Must Read
- specs/risk-adaptive-layer/design.md (§Security)
- plugins/sdd-quality-loop/references/sudo-mode-policy.md

### Done When
- [ ] THREAT-MODEL.md + capability matrix enumerate all controls/agents
- [ ] Codex agents declare model without breaking developer_instructions guard
- [ ] Presence/format tests; report + quality gate + traceability updated

### Blockers
None

---

## T-010 Wire risk layer into skills + policies

Source Issue: investigation.md INV-001..007 (integration)
Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: changes operator-facing workflow; wrong wiring could skip a gate. Behavioral but not cryptographic.
Required Workflow: acceptance-first
Requirements: REQ-001, REQ-002, REQ-003, REQ-004, REQ-006, REQ-007

### Goal
Update `sdd-bootstrap-interviewer` (interview asks risk + proposes tier),
`phase-quality-gates.md` (Specification/Task gates check risk), `quality-gate/SKILL.md`
(run check-risk + risk-aware contract + check-traceability; record review_verdict;
critical two-person + signature), `implement-task/SKILL.md` (capture red/green),
and policy docs (`test-policy.md`, `deterministic-check-policy.md`,
`verification-policy.md`). Update `docs/workflow-guide.md`.

### Must Read
- specs/risk-adaptive-layer/design.md (full)
- plugins/sdd-quality-loop/skills/quality-gate/SKILL.md

### Done When
- [ ] Skills/policies reference the new gates in the correct order
- [ ] eval.tests.sh extended to cover a risk-tiered end-to-end scenario
- [ ] report + quality gate + traceability updated

### Blockers
T-002..T-007

---

## T-011 Dogfood validation

Source Issue: investigation.md INV-011
Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: produces the self-evidence; low code surface but must actually pass the new gates to be meaningful.
Required Workflow: acceptance-first
Requirements: REQ-011

### Goal
Produce `specs/risk-adaptive-layer/traceability.json`, run the new gates against
this feature's own tasks, and store evidence under
`specs/risk-adaptive-layer/verification/`. Confirm self-spec passes check-risk,
check-traceability, and (for high/critical tasks) provenance.

### Must Read
- specs/risk-adaptive-layer/* (all)

### Done When
- [ ] traceability.json present and check-traceability passes
- [ ] Per-task evidence bundles generated and validated
- [ ] report + quality gate + traceability updated

### Blockers
T-002..T-007

## T-012 Stack descriptor for non-compiled repos

Source Issue: reports/implementation/T-011.md Finding 1
Approval: Draft
Status: Planned
Risk: high
Risk Rationale: changes check-contract Pass 4 (the gate engine); must keep all existing contract tests green and stay backward compatible.
Required Workflow: tdd
Requirements: REQ-002

### Goal
Let check-contract honor an optional `stack` contract field so compile-oriented
checks (lint/typecheck/build) are waivable (required:false + waiver_reason) on a
non-code stack (shell/docs/spec), while every test/trace/placeholder/task-state
check stays mandatory at its tier. Absent/empty stack == code == legacy behavior.

### Must Read
- plugins/sdd-quality-loop/references/risk-gate-matrix.md (Stack descriptor section)
- specs/risk-adaptive-layer/verification/T-012.red.log, T-012.green.log

### Done When
- [ ] check-contract.{sh,ps1} honor `stack`; compile checks waivable on non-code stacks ONLY
- [ ] tests both runtimes (gates.tests.sh T-012.1-7; scripts.tests.ps1) with Red->Green evidence
- [ ] risk-gate-matrix.md documents the stack descriptor; backward compatible (absent == code)

### Blockers
T-003
