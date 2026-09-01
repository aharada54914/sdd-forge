# Tasks: epic-197-a9-dogfood

Task-Review-Status: Pending
Human-Spec-Approval: Pending
Source: full local Issue #197 body / parent tracking Issue #187 /
requirements.md / design.md

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`.
Humans approve tasks. Only `quality-gate` may set Done. This first draft stops
before every review and approval gate.

## Global Constraints

- Implement one task at a time in dependency order.
- T-001 re-verifies A1–A8 and all mutable shared surfaces before live edits.
- OQ-001–OQ-004 and OQ-006 require dated human rulings before dependent task
  approval; OQ-005 is resolved by `issue-197-full-body.md:17`.
- Protected live targets use the human-copy procedure; never edit them directly.
- No task self-approves a Context, Pack, promotion, rollback, WFI, or task.
- High-risk tasks record the persisted-field/sibling/mismatch-test preflight in
  their implementation report before production changes.

## T-001 Re-verify A1–A8 and mutable shared contracts

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: Read-only compatibility/preflight work can block later tasks but
does not itself alter policy.
Required-Workflow: acceptance-first
Security-Sensitive: yes
Depends-On: none
Requirements: REQ-011, REQ-014 (AC-020, AC-021, AC-026)
Tests: TEST-020, TEST-021, TEST-026
Planned-Files: `specs/epic-197-a9-dogfood/verification/T-001/**`;
`reports/implementation/T-001.md`

### Goal

At implementation HEAD, prove that A1–A8 contracts are merged/usable and capture
fresh Registry, guard, component, Active Spec, WFI-number, protected-target, and
A5 entry-point inventories. Record Issue #197 as A9 under parent #187.

### Must Read

`requirements.md` REQ-011/REQ-014; `investigation.md` INV-017–INV-020 and
INV-024; all A1–A8 current specs/reports and live contract surfaces; local Issue
#197/#187 captures.

### Scope

Read-only probes plus failing dependency/mismatch fixtures and saved preflight
evidence. Do not copy contracts from another feature ref.

### Done When

- TEST-020 first fails with one required surface deliberately absent/incompatible,
  then passes against the live dependency set and names the failure deterministically.
- TEST-021 records all six shared-state inventory classes with current revision/hash.
- TEST-026 proves every A1-A8 dependency is usable and records #197 under #187.
- Evidence identifies exact merged A5 entry points or blocks dependent tasks.
- Implementation report includes run identity and acceptance-first red/green logs.

### Out of Scope

Live Context, Registry, promotion, rollback, or WFI changes.

### Blockers

None.

## T-002 Publish the approved Phase-1 sdd-forge Project Context

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Establishes protected repository-wide ownership and policy input.
Required-Workflow: tdd
Security-Sensitive: yes
Depends-On: T-001
Requirements: REQ-001, REQ-002, REQ-003, REQ-004, REQ-013
(AC-001–AC-007, AC-025)
Tests: TEST-001–TEST-007, TEST-025
Planned-Files: `sdd/project-context.yaml`;
`specs/epic-197-a9-dogfood/human-copy/sdd/project-context.approval.json`;
`specs/epic-197-a9-dogfood/human-copy/MANIFEST.sha256`; existing ownership and
Context test surfaces discovered by T-001; verification/report artifacts

### Goal

Create and human-publish the exact OQ-001/OQ-002 component, characteristic, and
ownership decision in Phase-1 advisory mode, with growing paths registered
cross-cutting from bootstrap.

### Must Read

OQ-001/OQ-002 dated human rulings; T-001 evidence; Project Context schema;
ADR-0019; A1/A3 current contracts.

### Scope

Schema-valid live YAML, protected approval candidate, component/characteristic
oracle, ownership positive and negative fixtures, A3 cross-cutting bootstrap
fixture, and parity evidence.

### Done When

- High-risk persisted-field preflight maps every Context/approval/ownership field
  to its sibling contract and a failing mismatch test before the first live edit.
- TEST-001–TEST-007 and TEST-025 have saved TDD red/green evidence.
- Component and path rules equal the human rulings; zero unexplained overlap and
  unowned paths are reported.
- `specs/` and every approved growing path resolve as cross-cutting from the
  initial live Context bootstrap.
- Protected approval candidate is staged for human application; no agent approval
  or direct protected write occurs.
- Independent review and quality-gate evidence are present; spec revision is recorded.

### Out of Scope

Pack content, required enforcement, promotion, rollback application.

### Blockers

T-001; unresolved OQ-001 or OQ-002.

## T-003 Implement the approved developer-tooling / cli-library Pack

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Changes the Registry policy that selects facets and gates.
Required-Workflow: tdd
Security-Sensitive: yes
Depends-On: T-001, T-002
Requirements: REQ-005 (AC-008, AC-009)
Tests: TEST-008, TEST-009
Planned-Files: `contracts/capability-registry.json`; existing Registry
projection/parity/test surfaces discovered by T-001; verification/report artifacts

### Goal

Encode only the human-approved first Pack and prove representative trigger and
non-scope behavior without changing existing capability semantics.

### Must Read

OQ-005 issue-backed resolution and OQ-006 dated human ruling; T-001 evidence; A2
Registry schema/design; current Registry; Phase-1 Context.

### Scope

Registry additions, required projection regeneration, Pack trigger fixtures,
later-Pack absence and existing-entry regression tests.

### Done When

- High-risk preflight maps every persisted capability/gate field to resolver/
  projection counterparts and failing mismatch tests.
- TEST-008 first fails without the Pack and passes with the approved Pack.
- TEST-009 proves no later Pack was introduced and existing durable-workflow
  semantics remain unchanged.
- Cross-runtime parity/projection evidence and independent quality-gate pass are saved.

### Out of Scope

Desktop, cloud-service, or new durable-workflow Pack; required promotion.

### Blockers

T-001; T-002; unresolved OQ-006.

## T-004 Run advisory dogfood and capture promotion evidence

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: Exercises policy in non-blocking mode and records evidence; it
does not weaken or promote enforcement.
Required-Workflow: acceptance-first
Security-Sensitive: no
Depends-On: T-002, T-003
Requirements: REQ-006, REQ-007 (AC-010–AC-013, AC-027)
Tests: TEST-010–TEST-013, TEST-027
Planned-Files: dogfood fixtures in existing A5/A7/A8 test surfaces discovered by
T-001; `specs/epic-197-a9-dogfood/verification/T-004/**`;
`reports/implementation/T-004.md`

### Goal

Exercise representative plugin, MCP, installer, CI/release, and cross-cutting
changes in advisory mode, then prove every sdd-forge PR passed the advisory Gate
for one complete release cycle and assemble the reviewable promotion evidence set.

### Must Read

OQ-003 dated ruling; T-001–T-003 evidence; merged A5/A7/A8 contracts.

### Scope

Representative fixtures, bound outputs, advisory non-blocking check, unchanged
existing-blocker regression, exhaustive bounded-release-cycle PR evidence, and
promotion completeness/staleness evaluator.

### Done When

- TEST-010–TEST-013 and TEST-027 have acceptance-first red/green evidence.
- Each representative surface has affected-component and Pack disposition output.
- Evidence names the cycle's start/end releases and proves every PR in the cycle
  passed the advisory capability-mode Gate; any missing/failing PR blocks completion.
- Unmet threshold and stale evidence independently reject promotion.
- Promotion evidence is presented for human decision; this task does not approve it.

### Out of Scope

Changing the live workflow tuple or applying rollback.

### Blockers

T-002; T-003; unresolved OQ-003.

## T-005 Promote atomically and verify governed rollback

Approval: Draft
Status: Planned
Risk: critical
Risk Rationale: Activates required policy and validates a policy-weakening rollback
across protected approval and release-affecting boundaries.
Required-Workflow: tdd + independent-security-review + two-approver-task-approval
Security-Sensitive: yes
Depends-On: T-004
Requirements: REQ-008, REQ-009, REQ-012
(AC-014–AC-018, AC-022–AC-024, AC-028)
Tests: TEST-014–TEST-018, TEST-022–TEST-024, TEST-028
Planned-Files: `sdd/project-context.yaml`;
`specs/epic-197-a9-dogfood/human-copy/sdd/project-context.approval.json`;
`specs/epic-197-a9-dogfood/human-copy/MANIFEST.sha256`; existing parity/CI/
installer/release tests discovered by T-001; verification/report/evidence bundle

### Goal

After explicit human promotion approval, publish the atomic Phase-2 tuple and
prove both ADR-0019 rollback branches fail closed and remain operable, then save
evidence that at least one real feature completes end-to-end under required
`facet-hybrid` mode.

### Must Read

OQ-003/OQ-004 rulings; promotion evidence; ADR-0019; current approver registry,
weakening detector, validator, guard inventory, and A7/A8 regression contracts.

### Scope

Atomic promotion candidate, partial-transition negatives, rollback cardinality/
cooldown/invalid-sidecar fixtures, shell/PowerShell/three-OS/install/release tests,
and one real post-promotion feature workflow.

### Done When

- Critical-task approval includes two distinct task approvers before implementation.
- Persisted-field preflight covers tuple, binding, approver cardinality, identities,
  `effective_at`, HMAC verdict, and their sibling/mismatch tests.
- TEST-014–TEST-018, TEST-022–TEST-024, and TEST-028 have saved TDD red/green evidence.
- Partial promotion, early cooldown, unsigned, self-approved, duplicate, and
  unbound cases fail; authorized branches pass.
- Independent security review, signed critical evidence bundle, clean-tree proof,
  and quality-gate pass are present.
- At least one real feature has saved specification-through-quality completion
  evidence under the promoted `facet-hybrid`/`required` tuple.
- Protected candidates await human application; no release is published by the gate.

### Out of Scope

Automatic human approval, fabricated second identity, new CI topology.

### Blockers

T-004; unresolved OQ-003 or OQ-004; missing human promotion approval.

## T-006 Record reproducible dogfood friction as Draft WFI

Approval: Draft
Status: Planned
Risk: low
Risk Rationale: Documentation-only record with human-controlled approval.
Required-Workflow: test-after
Security-Sensitive: no
Depends-On: T-004, T-005
Requirements: REQ-010 (AC-019, AC-029)
Tests: TEST-019, TEST-029
Planned-Files: next-free `docs/workflow-improvements/WFI-NNN.md` only when
friction evidence exists; verification/report artifacts always record the cycle
result

### Goal

Turn reproducible path-ownership, staleness, or approval-flow friction found
during T-004/T-005 into evidence-led Draft WFI records without self-approval or
speculative complaints; record `none` when the cycle has zero friction.

### Must Read

Current WFI guide/templates, current WFI namespace, captured dogfood evidence.

### Scope

Fresh identifier sweep, Draft WFI authoring, structural validation, and an
unconditional terminal friction-result record. If no reproducible friction exists,
record the literal result `none` in the implementation report.

### Done When

- TEST-019 validates all required WFI sections and Draft status for each record.
- TEST-029 validates WFI references when friction exists and the literal result
  `none` when zero, with path ownership, staleness, and approval flow assessed.
- Every WFI claim links reproducible evidence and reaches a controllable root-cause
  hypothesis; numbering was re-verified immediately before creation.
- No WFI is marked Approved and no issue is created unless the WFI category/rules
  and a human explicitly require it.

### Out of Scope

Approving, applying, auditing, or verifying a WFI.

### Blockers

T-004; T-005. Zero friction is a valid `none` outcome, not a blocker.
