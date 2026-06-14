# Tasks: cross-model-verification

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. **Humans approve tasks**
(`Approval: Draft -> Approved`); agents are blocked by `sdd-hook-guard` from
setting approvals. `implement-task` may set `In Progress`, `Blocked`, or
`Implementation Complete`. Only `quality-gate` may set `Done`. Critical tasks
also require a distinct `Second Approval`.

> All tasks below are authored `Approval: Draft`. The `Delegate:` line records the
> intended cost-aware build model (non-enforced hint); see design.md §7.

---

## T-001 Policy + verdict schema + matrix doc

Source Issue: requirements.md REQ-008; design.md §2, §4
Approval: Approved
Status: Done
Risk: medium
Risk Rationale: reference/doc + schema only; no gate logic, but foundational for all later tasks.
Required Workflow: acceptance-first
Requirements: REQ-002, REQ-004, REQ-008
Delegate: Haiku

### Goal
Author `plugins/sdd-quality-loop/references/cross-model-verification-policy.md`
(panelist selection, blind/parallel rule, aggregation/consensus, conflict
handling, consent, sanitization, fail-closed). Define the `cross-model-verdict/v1`
and `cross-model-aggregate/v1` schemas (mirror design.md §2). Do **not** edit
`risk-gate-matrix.md` here — the `cross-model-verification` row is added in T-003
together with the check-contract encoding so the matrix↔encoding parity test stays
green.

### Must Read
- specs/cross-model-verification/design.md (§2, §4, §6)
- plugins/sdd-quality-loop/references/evidence-signing-policy.md (policy format)
- plugins/sdd-quality-loop/references/risk-gate-matrix.md

### Scope
References + matrix doc. No gate/script behavior change.

### Done When
- [ ] cross-model-verification-policy.md authored (matches design.md §2-6)
- [ ] verdict + aggregate schemas documented in the policy (matrix row deferred to T-003)
- [ ] Presence/format tests added
- [ ] Implementation report created; quality gate passes; traceability updated

### Out of Scope
Any script change (T-002, T-003).

### Blockers
None

---

## T-002 check-cross-model deterministic gate + tests

Source Issue: requirements.md REQ-001..004; design.md §3
Approval: Approved
Status: Done
Risk: high
Risk Rationale: new fail-closed deterministic control other gates depend on; must be cross-runtime correct and not give a false PASS.
Required Workflow: tdd
Requirements: REQ-002, REQ-003, REQ-004
Delegate: Sonnet

### Goal
Add `check-cross-model.{sh,ps1}` (python-preferred inline, PowerShell fallback,
mirroring `check-risk` dispatch). Implement the consensus algorithm (design.md §3):
schema-validate verdicts, enforce diversity (≥2 vendors incl. ≥1 non-Anthropic),
consent presence, optional digest match, unanimous PASS / no Critical, optional
evaluator-divergence → NEEDS_HUMAN. Emit aggregate JSON. Exit 0/1/2.

### Must Read
- specs/cross-model-verification/design.md (§2, §3)
- plugins/sdd-quality-loop/scripts/check-risk.sh (dispatch pattern to mirror)
- plugins/sdd-quality-loop/scripts/check-task-state.sh (JSON-handling pattern)

### Scope
New gate scripts + `tests/cross-model.tests.{sh,ps1}` + fixtures (sample verdict
JSONs). **No network**; tests run offline.

### Done When
- [ ] Red→Green evidence captured (failing fixture first, then passing)
- [ ] check-cross-model.{sh,ps1} identical behavior (parity test)
- [ ] Fixtures cover AC-002..004 (diversity/consent/consensus/divergence)
- [ ] Independent review verdict recorded
- [ ] Regression suites still pass; report + quality gate + traceability updated

### Out of Scope
check-contract wiring (T-003); collection layer (T-004, T-005).

### Blockers
T-001

---

## T-003 Wire into check-contract + risk-gate-matrix + CI (governance)

Source Issue: requirements.md REQ-001, REQ-006, REQ-007; design.md §4, §5
Approval: Approved
Status: Done
Risk: high
Risk Rationale: modifies the core Default-FAIL gate engine; a regression weakens every adopter's assurance. Backward compatibility is load-bearing. Run in main session (Opus) + human review.
Required Workflow: tdd
Requirements: REQ-001, REQ-006, REQ-007
Delegate: Opus (main) + human

### Goal
Make `check-contract.{sh,ps1}` honor the `cross_model` descriptor: absent/`legacy`
⇒ no enforcement (backward compatible); `required` ⇒ `cross-model-verification`
present, `required:true`, `passes:true` + evidence; `waived` ⇒ `required:false` +
`waiver_reason`. Add the id to `RISK_TIERS["critical"]` guarded by the descriptor.
Add a gate-layer CI job in `.github/workflows/test.yml` (offline). Ensure the
aggregate flows into `generate-evidence-bundle` artifacts[].

### Must Read
- specs/cross-model-verification/design.md (§4, §5, §8)
- plugins/sdd-quality-loop/scripts/check-contract.sh (full — Pass 4 tier logic)
- .github/workflows/test.yml

### Scope
check-contract.{sh,ps1} + risk-gate-matrix.md encoding + test.yml job + tests.
A test asserts encoded tier-minimum equals the matrix doc.

### Done When
- [ ] Red→Green evidence captured
- [ ] ALL pre-feature check-contract fixtures still pass (regression — TEST-009)
- [ ] New fixtures: critical `cross_model:required` missing ⇒ fail; present ⇒ pass; `legacy` ⇒ unaffected; `waived` ⇒ pass
- [ ] CI job runs gate offline; no collection runner invoked (AC-007)
- [ ] Independent review recorded; report + quality gate + traceability updated

### Out of Scope
Collection layer (T-004, T-005).

### Blockers
T-002

---

## T-004 prepare-panelist-input (consent + sanitize)

Source Issue: requirements.md REQ-005; design.md §6
Approval: Approved
Status: Done
Risk: high
Risk Rationale: handles secrets and the external-send boundary; a bug could leak secrets to third-party LLMs.
Required Workflow: tdd
Requirements: REQ-005
Delegate: Sonnet

### Goal
Add `prepare-panelist-input.{sh,ps1}`: fail closed unless a `tasks.md`
`Cross-Model: enabled` flag OR valid `SDD_SUDO` exists; assemble the sanitized
input (approved spec + diff + relevant code), stripping `.env`/keys/absolute
paths/private URLs (reuse check-placeholders patterns); emit the bundle and its
sha256 (`input_digest`).

### Must Read
- specs/cross-model-verification/design.md (§6)
- plugins/sdd-quality-loop/scripts/check-placeholders.sh (secret patterns)
- plugins/sdd-quality-loop/references/sudo-mode-policy.md (consent/token)

### Done When
- [ ] Red→Green evidence captured
- [ ] Fixtures: no consent ⇒ fail closed; planted secret stripped (AC-005), both runtimes
- [ ] Independent review recorded; report + quality gate + traceability updated

### Out of Scope
Panelist runners (T-005); the gate (T-002).

### Blockers
T-001

---

## T-005 Collection layer: runners + skill + panelist agents

Source Issue: requirements.md REQ-002, REQ-003; design.md §1, §7
Approval: Approved
Status: Done
Risk: medium
Risk Rationale: orchestration + external CLI runners; never runs in CI and produces no gate verdict itself, so blast radius is contained. Ports the external fusion-fable pattern.
Required Workflow: acceptance-first
Requirements: REQ-002, REQ-003
Delegate: Sonnet (runners/skill) + Haiku (agent defs)

### Goal
Port `detect-panel`, `run-panelist-gpt`, `run-panelist-gemini` ({sh,ps1}) from the
fusion-fable pattern (blind, isolated scratch, graceful degrade). Add
`skills/cross-model-verify/SKILL.md` (orchestrates prepare → blind parallel
panelists incl. Claude via Agent tool → write verdict JSONs). Add read-only
panelist agent roles `agents/panelist-gpt.md`, `panelist-gemini.md` +
`.codex/agents/sdd-panelist-gpt.toml`, `sdd-panelist-gemini.toml` (with
`developer_instructions`, `disallowedTools: Write, Edit, NotebookEdit`).

### Must Read
- specs/cross-model-verification/design.md (§1, §6, §7)
- plugins/sdd-quality-loop/agents/evaluator.md (role format)
- .codex/agents/sdd-evaluator.toml (developer_instructions requirement)

### Done When
- [ ] Runners produce schema-valid verdict JSONs; absent CLI ⇒ graceful degrade
- [ ] SKILL.md keeps panelists blind (no evaluator context, no cross-talk)
- [ ] Agent toml carry developer_instructions (hook-guard passes)
- [ ] Presence/format tests; report + quality gate + traceability updated

### Out of Scope
Gate logic (T-002); contract wiring (T-003).

### Blockers
T-002, T-004

---

## T-006 Dogfood validation

Source Issue: requirements.md REQ-008; design.md §8
Approval: Approved
Status: Done
Risk: medium
Risk Rationale: produces self-evidence; low code surface but must actually pass the new gate to be meaningful.
Required Workflow: acceptance-first
Requirements: REQ-008
Delegate: Haiku + main

### Goal
Produce `specs/cross-model-verification/traceability.json`, run check-cross-model
(with fixture verdicts) against this feature's tasks, and store evidence under
`specs/cross-model-verification/verification/`. Confirm the self-spec passes
check-traceability and the gate-layer checks.

### Must Read
- specs/cross-model-verification/* (all)

### Done When
- [ ] traceability.json present and check-traceability passes
- [ ] check-cross-model self-run evidence stored; report + quality gate + traceability updated

### Blockers
T-002..T-005
