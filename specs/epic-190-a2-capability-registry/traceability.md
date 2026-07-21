# Traceability: epic-190-a2-capability-registry

Every Layer Spec cell contains a reasoned cross-layer N/A: Epic A2 has no UX,
frontend, or infrastructure-provisioning layer (design.md Layer
Specifications, Design System Compliance).

This document cross-references requirements.md's REQ/AC, design.md's
components, acceptance-tests.md's TEST IDs, tasks.md's T-00N tasks, and
investigation.md's OQ-00N open questions. It is authored in the same commit
as the rest of the spec package (Epic A2 has a single source issue, #190,
rather than the multi-issue Phase 1/Phase 2 split that motivates deferring
`tasks.md`/`traceability.md` authorship in some other specs in this
repository).

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-002, INV-003, INV-007, INV-010, OQ-001, OQ-002, OQ-003 | N/A (no UX/frontend/infra layer) | design.md#api--contract-plan (Registry schema); design.md#design-decisions-resolving-open-questions | `contracts/capability-registry.schema.json` (draft-07); `contracts/capability-registry.json` — schema `capability-registry/v1` | contracts/capability-registry.schema.json; contracts/capability-registry.json; tests/capability-registry-schema.tests.sh; tests/capability-registry-schema.tests.ps1 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005 | tests/capability-registry-schema.tests.sh; tests/capability-registry-schema.tests.ps1 | reports/quality-gate/ for T-001; specs/epic-190-a2-capability-registry/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-004 | N/A | design.md#api--contract-plan (Predicate DSL evaluator contract); design.md#global-constraints; design.md#security-boundaries (B2) | Evaluator I/O: `{"result": bool, "evidence": [...]}`; `PREDICATE_SCHEMA_ERROR` for allowlist/grammar violations | plugins/sdd-capability/scripts/evaluate-predicate.py; evaluate-predicate.sh; evaluate-predicate.ps1; tests/evaluate-predicate.tests.sh; tests/evaluate-predicate.tests.ps1 | TEST-006, TEST-007, TEST-008, TEST-009, TEST-010 | tests/evaluate-predicate.tests.sh; tests/evaluate-predicate.tests.ps1 | reports/quality-gate/ for T-002; specs/epic-190-a2-capability-registry/verification/T-002/ | Planned |
| REQ-003 | investigation.md INV-002, INV-008 | N/A | design.md#api--contract-plan (Registry validator contract); design.md#security-boundaries (B1) | Diagnostic line format `registry: <check-id>: <detail>`; `provider-terms.json` allowlist | plugins/sdd-capability/scripts/validate-capability-registry.py; validate-capability-registry.sh; validate-capability-registry.ps1; plugins/sdd-capability/references/provider-terms.json; tests/validate-capability-registry.tests.sh; tests/validate-capability-registry.tests.ps1 | TEST-011, TEST-012, TEST-013, TEST-014, TEST-015 | tests/validate-capability-registry.tests.sh; tests/validate-capability-registry.tests.ps1 | reports/quality-gate/ for T-003; specs/epic-190-a2-capability-registry/verification/T-003/ | Planned |
| REQ-004 | investigation.md INV-005, INV-006 | N/A | design.md#api--contract-plan (`registry_digest` generator contract); design.md#assumptions (canonicalizer interface stability) | `generate-registry-digest.py --registry <path> --capability-ids <ids> \| --whole` → sha256 hex | plugins/sdd-capability/scripts/generate-registry-digest.py; generate-registry-digest.sh; generate-registry-digest.ps1; tests/generate-registry-digest.tests.sh; tests/generate-registry-digest.tests.ps1 | TEST-016, TEST-017 | tests/generate-registry-digest.tests.sh; tests/generate-registry-digest.tests.ps1 | reports/quality-gate/ for T-004; specs/epic-190-a2-capability-registry/verification/T-004/ | Planned |
| REQ-005 | investigation.md INV-009 | N/A | design.md#api--contract-plan (Projection generator contract); design.md#protected-file-statement | `gate-capabilities.json` — `_generated` header block (`source`, `schema_version`, `sha256`, notice); `--check` drift mode | plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json (generated, protected); plugins/sdd-capability/scripts/generate-gate-capabilities.py/.sh/.ps1; specs/epic-190-a2-capability-registry/human-copy/ (guard-invariants registration); tests/generate-gate-capabilities.tests.sh; tests/generate-gate-capabilities.tests.ps1 | TEST-018, TEST-019, TEST-020 | tests/generate-gate-capabilities.tests.sh; tests/generate-gate-capabilities.tests.ps1 | reports/quality-gate/ for T-005; specs/epic-190-a2-capability-registry/verification/T-005/ | Planned |
| REQ-006 | investigation.md INV-014 | N/A | design.md#test-strategy | No new contract; six suite pairs + fixtures + `test.yml` registration | tests/run-all.sh; tests/run-all.ps1; specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml | (covers TEST-001..TEST-019 registration; no dedicated new Test ID) | tests/run-all.sh; tests/run-all.ps1 | reports/quality-gate/ for T-006; specs/epic-190-a2-capability-registry/verification/T-006/ | Planned |

## Layer Coverage

Epic A2 has exactly one layer: contract + deterministic script. There is no
UX, frontend, or infrastructure-provisioning layer (design.md Layer
Specifications, Design System Compliance — both marked Not applicable).
Every REQ below is covered by `design.md`'s Architecture, Components, and
API / Contract Plan sections; no REQ has a design gap.

## Task Mapping

| Requirement | Task(s) | Notes |
|---|---|---|
| REQ-001 (Registry schema) | T-001 | Also the plugin-scaffolding task |
| REQ-002 (Predicate DSL evaluator) | T-002 | Depends on T-001's schema shape |
| REQ-003 (Registry validation) | T-003 | Depends on T-001; independent of T-002 |
| REQ-004 (`registry_digest`) | T-004 | Depends on T-001 and Epic A1's canonicalizer (external blocker) |
| REQ-005 (projection + protected-file registration) | T-005 | Depends on T-001, T-003; human-copy sub-step for guard-invariants registration |
| REQ-006 (tests) | T-006 | Depends on T-002..T-005; human-copy sub-step for `test.yml` registration |

## Acceptance Mapping

| Test ID | Acceptance Criterion | Requirement | Task |
|---|---|---|---|
| TEST-001 | AC-001 | REQ-001 | T-001 |
| TEST-002 | AC-002 | REQ-001 | T-001 |
| TEST-003 | AC-003 | REQ-001, REQ-003 | T-001, T-003 |
| TEST-004 | AC-004 | REQ-001 | T-001 |
| TEST-005 | AC-005 | REQ-001 | T-001 |
| TEST-006 | AC-006 | REQ-002 | T-002 |
| TEST-007 | AC-007 | REQ-002 | T-002 |
| TEST-008 | AC-008 | REQ-002 | T-002 |
| TEST-009 | AC-009 | REQ-002 | T-002 |
| TEST-010 | AC-010 | REQ-002 | T-002 |
| TEST-011 | AC-011 | REQ-003 | T-003 |
| TEST-012 | AC-012 | REQ-003 | T-003 |
| TEST-013 | AC-013 | REQ-003 | T-003 |
| TEST-014 | AC-014 | REQ-003 | T-003 |
| TEST-015 | AC-015 | REQ-003 | T-003 |
| TEST-016 | AC-016 | REQ-004 | T-004 |
| TEST-017 | AC-017 | REQ-004 | T-004 |
| TEST-018 | AC-018 | REQ-005 | T-005 |
| TEST-019 | AC-019 | REQ-005 | T-005 |
| TEST-020 | AC-020 | REQ-005 | T-005 (protected-file sub-step) |
| TEST-021 | AC-021 | Non-goals | (verified against this spec commit itself, no implementation task) |
| TEST-022 | AC-022 | User Stories, Dependencies | (verified at spec-review time via this document, no implementation task) |

## Open-Question Trace

| ID | Where raised | Where resolved (this spec) | Where finally settled |
|---|---|---|---|
| OQ-001 (`upgrade_reasons` vocabulary: ADR-0022 prose vs. YAML example) | investigation.md | design.md Design Decisions (open string array, not closed enum) | Human decision or a follow-up ADR amendment; not this Epic |
| OQ-002 ("conditions" vs. `trigger` as separate fields) | investigation.md | design.md Design Decisions (one predicate field, `trigger`; "conditions" describes the DSL body, not a third field) | Human confirmation at spec review |
| OQ-003 (`delivery_strategy.kind` enum membership) | investigation.md | design.md Design Decisions (4 values inferred from decision v2 §17's Pack rollout order) | Human confirmation at spec review, or revisited once a real cloud-service/durable-workflow Pack exists |
| OQ-004 (unregistered-script check mechanism) | investigation.md | design.md Design Decisions (`implementation_ref` field + configured scan-directory list — this spec's own proposal) | Revisited once a real Capability Pack ships a script outside this repository's own `plugins/` tree (design.md Risks) |

## Deliverables (Per Task)

- T-001: `plugins/sdd-capability/` (plugin scaffold, 3 runtimes),
  `contracts/capability-registry.schema.json`,
  `contracts/capability-registry.json`,
  `tests/capability-registry-schema.tests.sh`/`.ps1`,
  `tests/fixtures/capability-registry/` (schema fixtures).
- T-002: `plugins/sdd-capability/scripts/evaluate-predicate.{py,sh,ps1}`,
  `tests/evaluate-predicate.tests.sh`/`.ps1`.
- T-003:
  `plugins/sdd-capability/scripts/validate-capability-registry.{py,sh,ps1}`,
  `plugins/sdd-capability/references/provider-terms.json`,
  `tests/validate-capability-registry.tests.sh`/`.ps1`.
- T-004:
  `plugins/sdd-capability/scripts/generate-registry-digest.{py,sh,ps1}`,
  `tests/generate-registry-digest.tests.sh`/`.ps1`.
- T-005:
  `plugins/sdd-capability/scripts/generate-gate-capabilities.{py,sh,ps1}`,
  `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`
  (generated, protected),
  `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json`
  + regenerated siblings + `MANIFEST.sha256` (staged, pending human `cp`),
  `tests/generate-gate-capabilities.tests.sh`/`.ps1`.
- T-006: `tests/*.tests.sh`/`.tests.ps1` (all six pairs, direct edits to
  `tests/run-all.sh`/`.ps1`),
  `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
  + `MANIFEST.sha256` (staged, pending human `cp`).

## Final Status

`Spec-Review-Status: Pending`. No task has been implemented. This document,
`requirements.md`, `design.md`, `acceptance-tests.md`, `tasks.md`, and
`investigation.md` constitute the full spec package for Epic A2 as of this
commit; a human reviewer's approval (changing `Spec-Review-Status` to
`Passed`) is required before any T-00N task in `tasks.md` may be
implemented (AGENTS.md Rules: "Do not implement Draft tasks").
