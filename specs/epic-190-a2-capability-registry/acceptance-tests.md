# Acceptance Tests: epic-190-a2-capability-registry

TEST IDs (TEST-001..TEST-022) are namespaced to this feature
(`specs/epic-190-a2-capability-registry/`) and map 1:1 to AC-001..AC-022 in
requirements.md. All test targets named below are **design-phase targets**:
no suite file exists yet (this spec's Non-goals; the implementation phase's
tasks.md schedules authoring them). Every row's Status is `Planned`.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | schema conformance | new suite `tests/capability-registry-schema.tests.sh`/`.ps1`: `contracts/capability-registry.schema.json` (draft-07) validates `contracts/capability-registry.json`; `additionalProperties: false` enforced at every fully-enumerated object level via a fixture with an unexpected extra key | Planned |
| AC-002 | REQ-001 | TEST-002 | schema conformance (conditional-required) | same suite: a `gates[]` fixture entry with `stage: implementation` and no `implementation_ref` is rejected; the same shape with `stage: artifact`/`promotion` and no `implementation_ref` is accepted | Planned |
| AC-003 | REQ-001, REQ-003 | TEST-003 | referential integrity | same suite (schema-level, `gate_ids` type-only) plus `tests/validate-capability-registry.tests.sh`/`.ps1` (validator-level, REQ-003(f)): a `capabilities[].gate_ids` entry naming an undefined `gates[].id` is rejected by the validator even though the schema alone cannot express the cross-reference | Planned |
| AC-004 | REQ-001 | TEST-004 | schema conformance | `tests/capability-registry-schema.tests.sh`/`.ps1`: `lite_policy.upgrade_reasons` accepts an arbitrary non-empty-string array (not limited to ADR-0022's 5-token example); `lite_policy.eligible` is required and rejected when non-boolean or when `lite_policy` is present without it | Planned |
| AC-005 | REQ-001 | TEST-005 | schema conformance (enum) | same suite: `delivery_strategy.kind` accepts only `developer-tooling`/`cli-library`/`desktop`/`cloud-service`/`durable-workflow`; a fixture with a sixth value is rejected | Planned |
| AC-006 | REQ-002 | TEST-006 | behavior lock (fail-closed) | new suite `tests/evaluate-predicate.tests.sh`/`.ps1`: for each of `equals`/`not_equals`/`contains`/`in`, three fixtures (missing path, `null` value, type-mismatched value) each yield `{"result": false}` plus a `WARN` evidence entry, never a thrown error | Planned |
| AC-007 | REQ-002 | TEST-007 | behavior lock (exists exception) | same suite: `exists` against a present-but-`null` path yields `{"result": true}`; `exists` against an absent path yields `{"result": false}` + `WARN`; a fixture confirms no type-inspection occurs for `exists` (a present array, string, and boolean value each independently yield `true`) | Planned |
| AC-008 | REQ-002 | TEST-008 | behavior lock (no short-circuit) | same suite: `all` over an empty list → `true`; `any` over an empty list → `false`; an `any` fixture whose first child is already `true` still records evidence for every remaining child (proving no short-circuit) | Planned |
| AC-009 | REQ-002 | TEST-009 | design-conformance (single code path) | same suite: a `trigger`-labeled fixture and a `conditional_facets[].when`-labeled fixture with identical predicate content produce byte-identical `evidence` shape, evidencing one shared evaluator | Planned |
| AC-010 | REQ-002 | TEST-010 | schema-rejection (allowlist) | same suite: a predicate referencing a `field` outside ADR-0020 item 5's 8-path allowlist is rejected with `PREDICATE_SCHEMA_ERROR`, not silently evaluated | Planned |
| AC-011 | REQ-003 | TEST-011 | uniqueness lock | new suite `tests/validate-capability-registry.tests.sh`/`.ps1`: a fixture Registry with two `gates[]` entries sharing one `id` fails validation with a `gate-id-duplicate` diagnostic | Planned |
| AC-012 | REQ-003 | TEST-012 | completeness lock (stage-scoped) | same suite: a `stage: implementation` Gate missing `implementation_ref` (or pointing at a nonexistent path) fails; the identical shape at `stage: artifact`/`promotion` passes | Planned |
| AC-013 | REQ-003 | TEST-013 | forward-guard | same suite: a fixture tree containing a `capability-packs/*/gates.yaml`-shaped file fails validation with a `pack-owns-gate-definition` diagnostic | Planned |
| AC-014 | REQ-003 | TEST-014 | boundary enforcement (negative, per-category) | same suite: one fixture per provider-terms category (cloud provider name, workflow-runtime product name, distribution-channel product name) each independently fails with a `provider-name-detected` diagnostic; a clean fixture using only provider-neutral vocabulary (e.g. `durable_workflow` as an `artifact_kinds` value) passes, proving no false positive | Planned |
| AC-015 | REQ-003 | TEST-015 | referential integrity | same suite: a `capabilities[].gate_ids` entry naming an undefined Gate ID fails with a `dangling-gate-reference` diagnostic (validator-level restatement of AC-003, run even though the schema-level check in TEST-003 already exists — defense-in-depth) | Planned |
| AC-016 | REQ-004 | TEST-016 | dual-runtime determinism + negative canary | new suite `tests/generate-registry-digest.tests.sh`/`.ps1`: the `.sh`- and `.ps1`-wrapped invocations of the digest generator, given the identical fixture fragment, produce an identical sha256; a one-character mutation to the fragment changes the digest (negative self-check proving the hash is content-sensitive) | Planned |
| AC-017 | REQ-004 | TEST-017 | fragment-scoping lock | same suite: `--capability-ids <id>` selects only that Capability plus its transitively-referenced `gates[]` entries (asserted by a fixture where an unrelated Capability's Gate change does not change the digest); `--whole` changes when any part of the Registry changes | Planned |
| AC-018 | REQ-005 | TEST-018 | generated-header conformance | new suite `tests/generate-gate-capabilities.tests.sh`/`.ps1`: the generated `gate-capabilities.json`'s `_generated` block carries `source`, `schema_version`, `sha256`, and the "Do not edit" notice string, matching guard-invariants' header convention; `--check` performs no filesystem write (asserted via mtime-unchanged) | Planned |
| AC-019 | REQ-005 | TEST-019 | drift detection (negative canary) | same suite: a hand-mutated `gate-capabilities.json` (committed content diverging from what regeneration would produce) causes `--check` to exit non-zero; an unmutated, freshly-regenerated file causes `--check` to exit zero | Planned |
| AC-020 | REQ-005 | TEST-020 | protected-file procedure proof | tasks.md's protected-file-registration task (Design's Protected-File Statement) is verified in three parts, mirroring the `epic-159-pillar-c` AC-027 precedent: (a) a staged candidate for the `guard-invariants.json` addition exists under `specs/epic-190-a2-capability-registry/human-copy/` with a correct `MANIFEST.sha256` entry; (b) the live `guard-invariants.json` and its generated siblings are byte-identical before/after this Epic's implementation-phase work until a human applies the staged candidate; (c) after a human `cp`, the five new paths (Components list, design.md) appear in the regenerated `guard_invariants.py`'s `PROTECTED_GATE_SUFFIXES`/`PHASE2_HUMAN_COPY_TARGETS` | Planned |
| AC-021 | Non-goals | TEST-021 | scope-boundary proof | `git diff --stat` (or `git status`) at this spec's own commit boundary shows changes confined to `specs/epic-190-a2-capability-registry/`; zero paths under `plugins/`, `scripts/`, `contracts/`, `tests/`, `.github/`, `docs/` | Planned |
| AC-022 | User Stories, Dependencies | TEST-022 | traceability audit | traceability.md cross-references OQ-001..OQ-004 (investigation.md) against the REQ/AC/task each touches; a manual review-time check (not an automated script) confirming none of the four was resolved without a recorded trace | Planned |

## Notes

- TEST-001..TEST-010 exercise **contract shape and evaluator semantics** in
  isolation from any Registry-validation policy; TEST-011..TEST-015 exercise
  **Registry-validation policy** against fixture Registries that are
  individually mutated to isolate exactly one failure mode each (never two
  failure modes in one fixture — a design choice carried over from this
  session's other reference specs' own negative-fixture discipline, e.g.
  `epic-159-pillar-c`'s TEST-054 "one fixture per malformed-field category").
- TEST-016/TEST-017 are the only cases requiring Epic A1's canonicalizer to
  actually exist as an importable dependency (requirements.md Dependencies);
  every other test in this suite can be authored and run against fixture
  data alone, independent of Epic A1's landing order.
- TEST-020 is the only case whose "Planned" status resolves through a human
  action (the `cp` step), not purely through automation — consistent with
  every other protected-file precedent this repository already uses
  (`epic-159-pillar-c` TEST-027, `epic-136-phase2-gates`'s own human-copy
  suite).
- No TEST in this suite invokes a live LLM, a live Provider API, or any
  network call — every case is fixture-driven and fully offline, matching
  Global Constraints (design.md) and ADR-0020's forbidden-operator list.
