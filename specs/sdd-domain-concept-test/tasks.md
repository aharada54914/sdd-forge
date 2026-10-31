# Tasks: sdd-domain-concept-test

Task-Review-Status: Passed

## Lifecycle and constraints

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`. Every task below is a proposal, not implementation approval. A human confirms each risk tier and approval. Only quality-gate sets Done. Implement one task at a time. The 2026-09-28 Governing Amendments in requirements.md supersede the preserved older layer-spec open questions. Do not edit the hash-frozen requirements, design, acceptance tests, layer specs, or this reviewed task-plan body after a gate passes; put later verification in non-frozen addenda. Phase 2–4 authoring, reviewer reorganization, reverse flow, C4 transfer, lite integration, v1 migration, and dual loaders are outside this feature.

2026-10-02 human-authorized Done When amendment: T-001 retains the validator-side rollback and existing approval-type regression. The v2 bootstrap unsigned/legacy negative fixture moves to T-003, which owns bootstrap flow control. This changes neither required proof nor task approval/status. The amended task-plan body requires a new task-stage review binding before its Passed status can be used as current evidence.

## T-001 Define the Concept Test evidence contract and signed approval binding

Source Issue: #290 Phase 1

Approval: Approved

Status: Implementation Complete

Risk: high

Risk Rationale: This changes an authorization-like signed human decision boundary and a public JSON contract; a false acceptance would permit unapproved generation.

Required Workflow: tdd

Requirements: REQ-001, REQ-002, REQ-003

Planned Files: `contracts/concept-test.v1.schema.json`, `contracts/approval-sidecar.schema.json`, `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py`, `tests/validate-approval-sidecar.tests.sh`, `tests/validate-approval-sidecar.tests.ps1`, focused new contract tests

Data Migration: none; no v1 compatibility loader

Breaking API: additive concept-test sidecar type; existing sidecar types must retain behavior

### Goal

Specify the feature-local md/json evidence and reuse the existing full content/hash/HMAC/registered-approver validator for a concept-test sidecar, without allowing provenance-only validation or agent signing.

### Must Read

- `specs/sdd-domain-concept-test/requirements.md`, `design.md`, `acceptance-tests.md`, `traceability.md`
- `specs/sdd-domain-concept-contract/design.md`; existing approval-sidecar schema and validator

### Scope

- Primary acceptance ownership: AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-014, AC-015, AC-016 (contract and signed-evidence validation).
- Contract fields bind feature, one of four proposals, rationale, confirmed same/different/undecided, optional non-FITS decision, and every read input path+sha256. Term is not Concept.
- Register the concept-test sidecar type and feature-local path; retain the Human/CI-only signer boundary. Recheck shared enum/mapping immediately before implementation.
- Validate all persisted fields against sibling md/json and signed content. Before implementation, record a high-risk preflight table for each field, counterpart, and failing mismatch test.

### Done When

- [ ] Contract and signed-approval positive tests cover valid FITS and all three non-FITS decisions with a temporary key and registered test approver. Record validator-side results corresponding to TEST-001–007 and TEST-015–022; TEST-022's bootstrap-stop and zero-invocation assertion remains T-003 pending until exercised end to end.
- [ ] Separate real-validator negatives reject absent sidecar, modified signature, missing key, unregistered approver, and decision-only evidence (TEST-030–034); no mock, skip, or provenance-only path substitutes.
- [ ] Exact field mismatch and missing/changed input tests fail closed at the validator boundary, including all four proposal classes; md/json and sidecar agree. Record validator-side results corresponding to TEST-035–037 and TEST-051–078; the latter rows' zero-downstream-invocation assertions remain T-003 pending until exercised end to end.
- [ ] Existing approval types and Phase 0 contract suites remain green; Red→Green, independent review, and spec_revision/environment provenance are recorded under `specs/sdd-domain-concept-test/verification/T-001/` and `reports/implementation/sdd-domain-concept-test/T-001.md`.
- [ ] After every approved task reaches Implementation Complete, a named independent quality-gate evaluator, distinct from the implementer, records a PASS verdict with Run ID in the T-001 quality-gate report; self-review is not Done evidence and this is not a prerequisite for T-001 Implementation Complete.
- [ ] Document and exercise validator-side rollback in the T-001 verification addendum: disable the new concept-test sidecar route while preserving existing approval types; negative fixtures prove unsigned or legacy concept-test evidence remains rejected by the validator.
- [ ] The T-001 validator-side REQ/AC/TEST evidence mapping is recorded in a non-frozen verification addendum with the shared bootstrap assertions explicitly pending; quality-gate alone marks Done after the full feature mapping is complete.

### Out of Scope

Proposal authoring, bootstrap flow control, review-context registration, release manifests, new cryptography, or signing by an agent.

### Blockers

None

## T-002 Add the read-only Concept Test proposal and human confirmation workflow

Source Issue: #290 Phase 1

Approval: Approved

Status: In Progress

Risk: medium

Risk Rationale: This is a new feature-level proposal workflow; it reads domain data but must not mutate domain state or authorize a decision itself.

Required Workflow: acceptance-first

Requirements: REQ-001, REQ-002

Planned Files: new `plugins/sdd-domain/skills/concept-test/SKILL.md`, focused `tests/sdd-domain/` fixtures/tests

Data Migration: none

Breaking API: none; produces a new feature-local evidence pair

### Goal

Use validated v2 concepts and feature requirements to propose one of four classifications, record human-confirmed relation, and write `specs/<feature>/concept-test.{md,json}` without changing `domain/`.

### Must Read

- `specs/sdd-domain-concept-test/requirements.md`, `design.md`, `acceptance-tests.md`, `traceability.md`
- `plugins/sdd-domain/skills/domain-sync/SKILL.md`; Phase 0 v2 validator contract

### Scope

- Primary acceptance ownership: AC-008, AC-009 (human relation confirmation and read-only proposal).
- Separate Term from Concept and ask the human to confirm same/different/undecided; an LLM proposal never becomes its own human confirmation.
- Future-only scenarios remain candidate evidence and do not append to `domain/`. The skill prepares evidence for T-001 validation; it does not sign approvals.

### Done When

- [ ] Acceptance-first fixtures cover the four proposals, three relation choices, and future-only candidate behavior (TEST-001–004, TEST-008–009, TEST-023–024).
- [ ] Domain files are byte/hash unchanged; existing Phase 0 validation regresses green.
- [ ] Related test results and REQ/AC/TEST mapping are saved in `specs/sdd-domain-concept-test/verification/T-002/` and `reports/implementation/T-002.md`; quality-gate alone marks Done.

### Out of Scope

Automatic concept authoring, sidecar signing, bootstrap gating, reviewer changes, or lite integration.

### Blockers

T-001

## T-003 Enforce the signed decision before bootstrap domain-sync

Source Issue: #290 Phase 1

Approval: Approved

Status: Planned

Risk: high

Risk Rationale: Fail-open flow control would bypass the human approval boundary and allow generation after rejected, deferred, stale, or invalid evidence.

Required Workflow: tdd

Requirements: REQ-003, REQ-004

Planned Files: `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`, focused bootstrap and Concept Test gate tests

Data Migration: none

Breaking API: full-profile v2 intake gains a required evidence gate; absent `domain/` preserves legacy behavior

### Goal

Invoke Concept Test before domain-sync only for v2 full-profile intake, validate the complete signed evidence, then deterministically continue, defer, or stop.

### Must Read

- `specs/sdd-domain-concept-test/requirements.md`, `design.md`, `acceptance-tests.md`, `traceability.md`
- T-001 and T-002 implementation reports and contracts
- T-005 v2 consumer implementation report and verification evidence

### Scope

- Primary acceptance ownership: AC-010, AC-011, AC-017 (bootstrap flow and outcome routing); AC-016 is exercised end-to-end after T-001 unit coverage.
- FITS with valid evidence and non-FITS with valid signed `proceed` continue domain-sync then generation. Valid `defer-to-domain-update` pauses; valid `rejected` stops. Invalid/missing/stale evidence blocks. Downstream invocation counts are zero for every non-continue case.
- Preserve the domain-absent path and existing skip result; do not add a dual v1/v2 loader. Spy only on downstream domain-sync/generation, never the signature verifier. Preflight persisted verdict/traceability fields with counterpart and failing mismatch tests before implementation.

### Done When

- [ ] Red→Green tests cover absent/malformed/unknown JSON and decision, all decision outcomes for each proposal, stale inputs, and md/json mismatch (TEST-002–007, TEST-014–022, TEST-028–046, TEST-075–078).
- [ ] Domain-absent output and skip behavior match baseline; v2 full path is Concept Test → domain-sync → generation (TEST-010–011).
- [ ] Negative and deferred/stopped cases record zero downstream calls, including a real signed-validator integration run; Phase 0 regressions remain green.
- [ ] Independent review and spec_revision/environment provenance are recorded in `specs/sdd-domain-concept-test/verification/T-003/` and `reports/implementation/T-003.md`; quality-gate result is recorded in its report and REQ/AC/TEST mapping in that verification directory.
- [ ] After every approved task reaches Implementation Complete, a named independent quality-gate evaluator, distinct from the implementer, records a PASS verdict with Run ID in the T-003 quality-gate report; self-review is not Done evidence and this is not a prerequisite for T-003 Implementation Complete.
- [ ] Document and exercise a fail-closed T-003 rollback in its verification addendum: disable v2 generation or restore the last guarded entry point only while the signed decision gate remains mandatory; negative fixtures prove missing/invalid/rejected/deferred and unsigned/legacy evidence still invokes neither domain-sync nor generation.

### Out of Scope

Lite, v1 migration, domain authoring, or changing the quality gate to rely on an LLM verdict.

### Blockers

T-001, T-002, T-005

## T-004 Bind Concept Test evidence in later review-context manifests

Source Issue: #290 Phase 1

Approval: Approved

Status: Planned

Risk: high

Risk Rationale: Review-input allowlists and manifest hashes are a provenance boundary; omission or substitution would let reviews inspect different evidence from intake.

Required Workflow: tdd

Requirements: REQ-005

Planned Files: `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh`, `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1`, corresponding precheck/input-manifest callers, focused review-context tests, `specs/sdd-domain-concept-test/traceability.json`

Data Migration: none; existing frozen review rounds are not retrofitted

Breaking API: additive evidence input class for new v2 Concept Test reviews

### Goal

Reserve and recheck the same concept-test md, json, signed sidecar, and every read input path+sha256 in each downstream review context.

### Must Read

- `specs/sdd-domain-concept-test/requirements.md`, `design.md`, `acceptance-tests.md`, `traceability.md`
- T-001 contract and T-003 flow evidence; current sh/ps1 allowlists and all callers

### Scope

- Primary acceptance ownership: AC-012, AC-018 (complete and stable downstream review inputs).
- Recheck both twins and callers immediately before implementation; add one complete input class with fail-closed omissions, hash drift, and replacement checks.
- As the final dependent implementation task, assemble `specs/sdd-domain-concept-test/traceability.json` from T-001–T-006 real results and independently compare every REQ/AC/TEST assertion in the frozen acceptance table. Do not declare a shared TEST complete until both validator and bootstrap assertions have real evidence; no pending feature row may be treated as a link pass.
- Run separate operator and cmdlet/language-feature case-sensitivity sweeps on any sh→ps1 port, each with a mis-cased negative fixture. Preflight each persisted manifest field, counterpart, and failing mismatch test before implementation.

### Done When

- [ ] Both twins reserve md, json, sidecar, and all read inputs; absent or replaced entries fail (TEST-012, TEST-025–027, TEST-047–050).
- [ ] Entry and later review manifests identify byte-identical evidence; independent negative case fixtures and twin parity pass without modifying old frozen rounds.
- [ ] Red→Green, independent review, spec_revision/environment provenance, Phase 0 regression output, and REQ/AC/TEST mapping are recorded in `specs/sdd-domain-concept-test/verification/T-004/` and `reports/implementation/T-004.md`; quality-gate result is recorded separately.
- [ ] After every approved task reaches Implementation Complete, a named independent quality-gate evaluator, distinct from the implementer, records a PASS verdict with Run ID in the T-004 quality-gate report; self-review is not Done evidence and this is not a prerequisite for T-004 Implementation Complete.
- [ ] The feature-root `traceability.json` contains real evidence for every frozen REQ/AC/TEST assertion, including shared-row bootstrap behavior; record the full-table expected-ID and assertion comparison in `verification/T-004/` before Implementation Complete. The existing `check-traceability` must pass in `require-evidence` mode; its listed-link success alone is insufficient.
- [ ] Document and exercise rollback in the T-004 verification addendum: pause new v2 review launches until the complete evidence input class is restored; negative fixtures prove omission or hash drift still fails closed and old frozen rounds remain unchanged.

### Out of Scope

Review policy changes, retrofitting old rounds, or bypassing protected-script write denials.

### Blockers

T-001, T-003, T-006

## T-005 Switch the in-scope domain consumer to v2 without a second loader

Source Issue: #290 Phase 1

Approval: Approved

Status: Planned

Risk: medium

Risk Rationale: This changes the domain-sync consumer contract but not the signed authorization gate; a version mistake must be caught by acceptance and regression tests.

Required Workflow: acceptance-first

Requirements: REQ-004

Planned Files: `plugins/sdd-domain/skills/domain-sync/SKILL.md`, `tests/sdd-domain/domain-sync.Tests.ps1`, related shell fixtures/tests

Data Migration: none; old v1 assets require no new upgrade mode in this phase

Breaking API: in-scope v2 consumer switch; no dual version loader

### Goal

Make the existing in-scope domain-sync consumer use the Phase 0 v2 contract while preserving the documented domain-absent skip path.

### Must Read

- `specs/sdd-domain-concept-test/requirements.md`, `design.md`, `acceptance-tests.md`, `traceability.md`
- Phase 0 v2 contract and validator; current in-scope consumer inventory

### Scope

- Primary acceptance ownership: AC-010 and AC-011 at the domain-sync consumer level; T-003 owns bootstrap flow integration.
Recheck all target consumers immediately before implementation, switch the in-scope set together, and test v2 input plus absent-domain behavior. Do not create a v1 fallback or migration branch.

### Done When

- [ ] Acceptance-first v2 and absent-domain cases pass (TEST-010–011); Phase 0 contract and sync regressions pass.
- [ ] In-scope consumers have one v2 path, no dual loader; results and REQ/AC/TEST mapping are saved in `specs/sdd-domain-concept-test/verification/T-005/` and `reports/implementation/T-005.md`, then quality-gate alone marks Done.

### Out of Scope

Out-of-scope consumers, v1 migration, domain authoring, or lite integration.

### Blockers

None

## T-006 Register and verify the Concept Test release surface

Source Issue: #290 Phase 1

Approval: Approved

Status: Planned

Risk: medium

Risk Rationale: Plugin discovery and release metadata affect availability, but do not themselves authorize evidence or mutate domain data.

Required Workflow: acceptance-first

Requirements: REQ-006

Planned Files: `plugins/sdd-domain/.claude-plugin/plugin.json`, `plugins/sdd-domain/.codex-plugin/plugin.json`, `plugins/sdd-domain/.plugin/plugin.json`, release-surface validation tests

Data Migration: none

Breaking API: additive skill visibility

### Goal

Expose the new Concept Test skill consistently in all three plugin manifests and the existing release validation surface.

### Must Read

- `specs/sdd-domain-concept-test/requirements.md`, `design.md`, `acceptance-tests.md`, `traceability.md`
- Current plugin manifests, release checks, and T-002 skill

### Scope

- Primary acceptance ownership: AC-013 (release skill visibility).
Update only the required discovery metadata and matching release assertions; no publish/deploy is authorized by this task.

### Done When

- [ ] Three manifests and release-surface visibility agree (TEST-013), with acceptance-first regression evidence.
- [ ] Release validation output and REQ/AC/TEST mapping are saved in `specs/sdd-domain-concept-test/verification/T-006/` and `reports/implementation/T-006.md`; quality-gate result is recorded before Done.

### Out of Scope

Publication, deployment, independent reviewer restructuring, or unrelated plugin registration.

### Blockers

T-002
