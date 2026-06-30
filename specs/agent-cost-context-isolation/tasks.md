# Tasks: Agent Cost and Context Isolation

Task-Review-Status: Passed

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

## T-001 Define vendor-neutral capability tiers and role floors

Approval: Approved

Status: Implementation Complete

Risk: medium

Risk Policy Version: 1

Risk Impact: limited

Risk Reversibility: controlled

Risk Surface: behavioral

Risk Rationale: This changes routing declarations and agent model floors but is
fully reversible through checked-in policy, contract, and documentation files.

Required Workflow: acceptance-first

Requirements: REQ-001, REQ-002, REQ-003, AC-001

Planned Files: model capability contract, routing ADR, capability matrix, and
investigator/reviewer/evaluator model declarations.

Data Migration: None.

Breaking API: No; canonical tiers are provider-neutral.

Rollback: Restore the 1.4.0 model declarations and remove the additive
capability contract through the pinned rollback transaction.

### Goal

Define turn-first capability tiers and explicit Anthropic and Codex equivalents
for every workflow role.

### Must Read

- `specs/agent-cost-context-isolation/requirements.md`
- `specs/agent-cost-context-isolation/design.md`
- `specs/agent-cost-context-isolation/acceptance-tests.md`

### Scope

Implement the capability registry, human-readable matrix/ADR, and role model
floors. Do not implement selection or escalation state.

### Done When

- [ ] TEST-001 capability and role-floor assertions pass
- [ ] Expected attempts precede weakest sufficient tier and token price
- [ ] Haiku/Sonnet/Opus and explicit Codex model/effort equivalents are present
- [ ] Investigator is lightweight, reviewers are standard minimum, and evaluator is strong

### Out of Scope

Selection scripts, escalation, snapshots, isolation, reporting, and release.

### Blockers

None

## T-002 Implement deterministic routing and terminal resume

Approval: Approved

Status: Implementation Complete

Risk: high

Risk Policy Version: 1

Risk Impact: material

Risk Reversibility: difficult

Risk Surface: sensitive

Risk Rationale: This controls escalation and human-only resume of a blocked
workflow task; a fail-open defect could bypass an approval boundary.

Required Workflow: tdd

Requirements: REQ-004, REQ-010, AC-001

Planned Files: paired model selectors, paired terminal-resume validators,
delegation/orchestration policy, and routing tests.

Data Migration: None.

Breaking API: No; selectors and resume evidence are additive contracts.

Rollback: Restore the 1.4.0 routing policy and remove the additive paired
selectors and resume validators through the pinned rollback transaction.

### Goal

Apply the turn-first matrix deterministically, escalate only on repeated equal
failures, and keep terminal-tier recurrence blocked until human reapproval.

### Must Read

- `specs/agent-cost-context-isolation/requirements.md`
- `specs/agent-cost-context-isolation/design.md`
- `docs/agent-capability-matrix.md`

### Scope

Implement paired selection scripts, failure recurrence/escalation, and the
hash-bound terminal-resume guard.

### Done When

- [ ] Red→Green evidence is captured at `specs/agent-cost-context-isolation/verification/T-002/red.log` and `green.log`, with failing tests committed before implementation begins
- [ ] Same failure recurrence advances one tier; different failures do not accumulate
- [ ] Availability, cost/lexical tie-breaks, high-before-xhigh, and fail-closed runtime behavior pass in Bash and PowerShell
- [ ] Terminal resume rejects a missing diagnosis, unchanged/stale task contract, forged hash, or absent/mismatched human reapproval
- [ ] Independent reviewer `T-002-independent-reviewer` records PASS in `reports/implementation/agent-cost-context-isolation/T-002.md`
- [ ] An isolated rollback fixture restores selection/resume behavior and routing tests pass

### Out of Scope

Role declarations, task snapshots, review isolation, reporting, and release.

### Blockers

T-001

## T-003 Add the immutable task handoff contract

Approval: Approved

Status: Implementation Complete

Risk: high

Risk Policy Version: 1

Risk Impact: material

Risk Reversibility: difficult

Risk Surface: sensitive

Risk Rationale: This defines the trusted file boundary presented to an
implementation agent; a defect could expose mutable or unauthorized inputs.

Required Workflow: tdd

Requirements: REQ-007, REQ-010, AC-003, AC-004

Planned Files: task input JSON schema, paired snapshot builders, paired
manifest validators, and manifest-integrity fixtures.

Data Migration: None; the contract is new and versioned.

Breaking API: No; the task manifest is additive.

Rollback: Remove the additive schema, snapshot builders, validators, and
fixtures through the pinned rollback transaction.

### Goal

Create and validate immutable, canonical, hash-bound per-run task snapshots.

### Must Read

- `specs/agent-cost-context-isolation/requirements.md`
- `specs/agent-cost-context-isolation/design.md`
- `specs/agent-cost-context-isolation/security-spec.md`

### Scope

Implement the schema, paired atomic snapshot builders, and paired validators
for identity, model/cost provenance, paths, outputs, and hashes.

### Done When

- [ ] Red→Green evidence is captured at `specs/agent-cost-context-isolation/verification/T-003/red.log` and `green.log`, with failing tests committed before implementation begins
- [ ] TEST-003 passes in Bash and PowerShell for a valid immutable snapshot
- [ ] Traversal, symlink, mutation, task-ID, missing-field, output-root, chat-only, cost, and hash tampering fail closed
- [ ] Bash and PowerShell diagnostics use the same categories
- [ ] Independent reviewer `T-003-independent-reviewer` records PASS in `reports/implementation/agent-cost-context-isolation/T-003.md`
- [ ] An isolated rollback fixture removes the handoff contract and restores the baseline

### Out of Scope

Agent launch orchestration, reviewer/evaluator isolation, reports, and release.

### Blockers

T-001

## T-004 Orchestrate fresh implementation contexts

Approval: Approved

Status: Implementation Complete

Risk: high

Risk Policy Version: 1

Risk Impact: material

Risk Reversibility: difficult

Risk Surface: sensitive

Risk Rationale: This changes implementation-agent lifecycle and fallback
semantics; identity reuse could silently defeat task context isolation.

Required Workflow: tdd

Requirements: REQ-005, REQ-006, REQ-010, AC-002

Planned Files: `implement-tasks` orchestration, task delegation policy, and
three-task identity/fallback fixtures.

Data Migration: None; historical reports remain readable.

Breaking API: No; capable hosts gain stricter launch behavior.

Rollback: Restore the 1.4.0 `implement-tasks` loop and remove the new launch
identity/fallback requirements through the pinned rollback transaction.

### Goal

Launch one fresh implementation agent per task and allow only a recorded
file-reload fallback on hosts that cannot create subagents.

### Must Read

- `specs/agent-cost-context-isolation/requirements.md`
- `specs/agent-cost-context-isolation/design.md`
- `contracts/task-input-manifest.schema.json`

### Scope

Change `implement-tasks` into an orchestrator, enforce unique batch identities,
and specify the same-session file-reload fallback.

### Done When

- [x] Red→Green evidence is captured at `specs/agent-cost-context-isolation/verification/T-004/red.log` and `green.log`, with failing tests committed before implementation begins
- [x] TEST-002 capable-host fixtures reject adjacent and nonadjacent run/session/agent reuse
- [x] Fallback records unique task/run IDs, reused physical IDs, reason, and reload-evidence hash
- [x] Chat history or compaction-only handoff is rejected
- [x] Independent reviewer `T-004-independent-reviewer` records PASS in `reports/implementation/agent-cost-context-isolation/T-004.md`
- [x] An isolated rollback fixture restores the 1.4.0 implementation loop and identity tests pass

### Out of Scope

Manifest mechanics, reviewers/evaluator, reporting, and release metadata.

### Blockers

T-002, T-003

## T-005 Isolate reviewers and the Done evaluator

Approval: Approved

Status: Planned

Risk: high

Risk Policy Version: 1

Risk Impact: material

Risk Reversibility: difficult

Risk Surface: sensitive

Risk Rationale: This controls independent decision inputs; fail-open behavior
could allow shared context or unlisted evidence to influence approval.

Required Workflow: tdd

Requirements: REQ-005, REQ-010, AC-002

Planned Files: reviewer/evaluator prompts, quality-gate orchestration, and
review isolation fixtures.

Data Migration: None.

Breaking API: No; fresh manifest-bound sessions tighten existing gates.

Rollback: Restore the 1.4.0 reviewer/evaluator prompts and quality-gate
invocation rules through the pinned rollback transaction.

### Goal

Require six review roles and the Done evaluator to use distinct fresh,
read-only, hash-bound contexts with no fallback.

### Must Read

- `specs/agent-cost-context-isolation/requirements.md`
- `specs/agent-cost-context-isolation/design.md`
- `specs/agent-cost-context-isolation/security-spec.md`

### Scope

Bind reviewer/evaluator identity and manifests at gate boundaries, enforce
read-only fresh sessions, and prohibit fallback.

### Done When

- [ ] Red→Green evidence is captured at `specs/agent-cost-context-isolation/verification/T-005/red.log` and `green.log`, with failing tests committed before implementation begins
- [ ] TEST-002 reviewer/evaluator isolation fixtures pass
- [ ] Missing manifest, unlisted path, hash mismatch, chat-only input, and reused session fail closed
- [ ] All six reviewer roles and the evaluator expose distinct run/session identity
- [ ] Independent reviewer `T-005-independent-reviewer` records PASS in `reports/implementation/agent-cost-context-isolation/T-005.md`
- [ ] An isolated rollback fixture restores reviewer/evaluator boundaries and the isolation test passes

### Out of Scope

Implementation-agent launch, reports, retrospectives, and release metadata.

### Blockers

T-003

## T-006 Add file-backed handoff and iteration metrics

Approval: Approved

Status: Planned

Risk: medium

Risk Policy Version: 1

Risk Impact: limited

Risk Reversibility: controlled

Risk Surface: behavioral

Risk Rationale: This adds observable report and retrospective fields without
changing authorization or external interfaces.

Required Workflow: acceptance-first

Requirements: REQ-008, REQ-009, AC-005

Planned Files: implementation-report and retrospective templates,
retrospective skill, and workflow/retrospective tests.

Data Migration: None; legacy reports remain readable.

Breaking API: No; all current report fields are additive.

Rollback: Restore the 1.4.0 templates and retrospective guidance.

### Goal

Make outputs, tests, next action, attempts, review rounds, gate runs, and
escalations inspectable without chat history or token-price optimization.

### Must Read

- `specs/agent-cost-context-isolation/requirements.md`
- `specs/agent-cost-context-isolation/design.md`
- `specs/agent-cost-context-isolation/acceptance-tests.md`

### Scope

Update implementation reports, retrospectives, and their compatibility/error
fixtures.

### Done When

- [ ] TEST-004 validates every required output, test, identity, escalation, attempt, status, unresolved, and next-action field
- [ ] Legacy report fixtures remain accepted without fabricated new fields
- [ ] A current-schema report missing a required handoff field is rejected
- [ ] Retrospectives expose task attempts, review rounds, quality-gate runs, and model escalations

### Out of Scope

Routing, agent launch, review/evaluator gates, and release metadata.

### Blockers

T-004, T-005

## T-007 Synchronize the 1.5.0 release surfaces

Approval: Approved

Status: Planned

Risk: medium

Risk Policy Version: 1

Risk Impact: limited

Risk Reversibility: controlled

Risk Surface: behavioral

Risk Rationale: This synchronizes repository-only release metadata without
deploying a service or migrating data.

Required Workflow: acceptance-first

Requirements: REQ-011, AC-006

Planned Files: all plugin and marketplace manifests, README, CHANGELOG, and
version validators.

Data Migration: None.

Breaking API: No; 1.5.0 is a backward-compatible feature release.

Rollback: Restore all release surfaces to 1.4.0 with the T-008 transaction.

### Goal

Publish every Claude, Codex, Copilot, marketplace, documentation, and
validation surface consistently as 1.5.0.

### Must Read

- `specs/agent-cost-context-isolation/requirements.md`
- `specs/agent-cost-context-isolation/design.md`
- `specs/agent-cost-context-isolation/infra-spec.md`

### Scope

Synchronize manifests, marketplaces, README, CHANGELOG, and version validation.

### Done When

- [ ] TEST-005 passes
- [ ] Every declared release surface reports 1.5.0
- [ ] Bash and PowerShell repository validators agree
- [ ] No historical release entry is rewritten

### Out of Scope

Rollback execution, package-registry publication, and service deployment.

### Blockers

T-001, T-002, T-003, T-004, T-005, T-006

## T-008 Add the atomic 1.5.0 rollback transaction

Approval: Approved

Status: Planned

Risk: medium

Risk Policy Version: 1

Risk Impact: limited

Risk Reversibility: controlled

Risk Surface: behavioral

Risk Rationale: This adds a repository-local, validation-gated rollback
transaction whose failure path preserves the original worktree.

Required Workflow: acceptance-first

Requirements: REQ-011, AC-007

Planned Files: rollback hash inventory, paired rollback executables, and
isolated success/failure fixtures.

Data Migration: None.

Breaking API: No; rollback tooling is additive.

Rollback: Remove the additive rollback contract and scripts.

### Goal

Restore the enumerated 1.5.0 files to baseline `7df7318` atomically and leave
the original tree unchanged on any validation failure.

### Must Read

- `specs/agent-cost-context-isolation/requirements.md`
- `specs/agent-cost-context-isolation/design.md`
- `specs/agent-cost-context-isolation/infra-spec.md`

### Scope

Implement the baseline/new hash inventory, paired transaction executables, and
isolated success/failure fixtures.

### Done When

- [ ] TEST-006 passes
- [ ] Every inventory entry matches baseline and new SHA-256 values
- [ ] Successful rollback validates at 1.4.0
- [ ] Forced validation failure preserves the original tree byte-for-byte
- [ ] `tests/run-all.sh`, `tests/run-all.ps1`, and both repository validators pass

### Out of Scope

Release synchronization, publication, deployment, and historical edits.

### Blockers

T-007
