# Acceptance Tests: epic-190-a2-capability-registry

TEST IDs are namespaced to this feature
(`specs/epic-190-a2-capability-registry/`). This package was renumbered on
2026-07-22 in response to an 18-finding adversarial spec review (orchestrator
ruling 2026-07-22); the review found the previous AC↔TEST numbering was not a
true 1:1 mapping (mismatched REQ IDs and test targets on several rows). The
table below now maps every automated, Planned, implementation-phase test to
exactly one Acceptance Criterion in requirements.md by matching row number
(AC-NNN ↔ TEST-NNN), with two documented exceptions:

- **AC-034 has no TEST-034 row.** It is a spec-commit-bound scope-boundary
  statement, not an automated implementation-phase test (it would fail by
  construction the moment REQ-001..006 are implemented). See the "Spec-
  Authoring-Time Manual Review Record" section below instead.
- **TEST-036's Status is `Deferred to Phase 2`, not `Planned`.** Its target
  (`traceability.md`) does not exist during this Phase 1 package (Non-goals,
  requirements.md); marking it `Planned` would make it fail immediately.

All other test targets named below are **design-phase targets**: no suite
file exists yet (this spec's Non-goals; the implementation phase's
`tasks.md` schedules authoring them).

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | schema conformance | new suite `tests/capability-registry-schema.tests.sh`/`.ps1`: `contracts/capability-registry.schema.json` (draft-07) validates `contracts/capability-registry.json`; `additionalProperties: false` enforced at every fully-enumerated object level via a fixture with an unexpected extra key | Planned |
| AC-002 | REQ-001 | TEST-002 | schema conformance (conditional-required) | same suite: a `gates[]` fixture entry with `stage: implementation` and no `implementation_ref` is rejected; the same shape with `stage: artifact`/`promotion` and no `implementation_ref` is accepted | Planned |
| AC-003 | REQ-001, OQ-001 | TEST-003 | schema conformance | same suite: `lite_policy.upgrade_reasons` accepts an arbitrary non-empty-string array (not limited to ADR-0022's 5-token example); `lite_policy.eligible` is required and rejected when non-boolean or when `lite_policy` is present without it | Planned |
| AC-004 | REQ-001, OQ-003 | TEST-004 | schema conformance (open string, no enum, required) | same suite: `delivery_strategy.kind` accepts any non-empty string value, including values outside the four/five literals this spec's first draft inferred; an empty string and a non-string value are each rejected; no fixture asserts a closed set of accepted values; **new (2026-07-22, closing the NEW Major finding)**: a `capabilities[]` fixture entry with no `delivery_strategy` key at all is rejected (missing required field); a fixture with `delivery_strategy: {}` (present but no `kind`) is rejected (missing required nested field) | Planned |
| AC-005 | REQ-001 | TEST-005 | schema conformance (const + reserved-stage inertness) | same suite: `minimum_enforcement: "required"` is accepted; `minimum_enforcement` set to any other string is rejected (positive/negative pair); a `stage: artifact`/`promotion` `gates[]` entry with no `implementation_ref` and no `minimum_enforcement` passes validation and triggers no completeness check | Planned |
| AC-006 | REQ-001, OQ-002 | TEST-006 | schema conformance (no third DSL field) | same suite: a `capabilities[]` fixture entry carrying an extra top-level `conditions` key (sibling to `trigger`) is rejected by `additionalProperties: false`; confirms the schema holds the Predicate DSL only at `trigger` and `conditional_facets[].when` | Planned |
| AC-007 | REQ-002 | TEST-007 | behavior lock (fail-closed) | new suite `tests/evaluate-predicate.tests.sh`/`.ps1`: for each of `equals`/`not_equals`/`contains`/`in`, three fixtures (missing path, `null` value, type-mismatched value) each yield `{"result": false}` plus a `WARN` evidence entry, never a thrown error | Planned |
| AC-008 | REQ-002 | TEST-008 | behavior lock (exists exception) | same suite: `exists` against a present-but-`null` path yields `{"result": true}`; `exists` against an absent path yields `{"result": false}` + `WARN`; a fixture confirms no type-inspection occurs for `exists` (a present array, string, and boolean value each independently yield `true`) | Planned |
| AC-009 | REQ-002 | TEST-009 | behavior lock (no short-circuit) | same suite: `all` over an empty list → `true`; `any` over an empty list → `false`; an `any` fixture whose first child is already `true` still records evidence for every remaining child (proving no short-circuit) | Planned |
| AC-010 | REQ-002 | TEST-010 | design-conformance (single code path) | same suite: a `trigger`-labeled fixture and a `conditional_facets[].when`-labeled fixture with identical predicate content produce byte-identical `evidence` shape, evidencing one shared evaluator | Planned |
| AC-011 | REQ-002 | TEST-011 | drift lock (allowlist ↔ A1 schema) | same suite: a fixture predicate referencing a `field` outside the 8-path allowlist is rejected with `PREDICATE_SCHEMA_ERROR`; a drift-check fixture fails when the schema's `field` enum and Epic A1's Project-Context-schema-declared field set (once it lands) diverge, rather than silently accepting a stale copy | Planned |
| AC-012 | REQ-002 | TEST-012 | behavior lock (`not` arity + truth table) | same suite: a `not` fixture whose shape carries zero or two children is rejected as `PREDICATE_SCHEMA_ERROR`; three fixtures (child `true`, child `false`, child `false`+`WARN`) each confirm `not`'s documented truth table, and the child's own Evidence entry (including its `WARN` reason, where applicable) is present in the `not` node's recorded `children` | Planned |
| AC-013 | REQ-002 | TEST-013 | schema conformance (Evidence) + ordering lock | same suite: every fixture's `evidence` output validates against the published Evidence JSON Schema; a nested `all`-of-`any`-of-comparisons fixture asserts depth-first, left-to-right, stable Evidence ordering across repeated runs | Planned |
| AC-014 | REQ-003(a) | TEST-014 | uniqueness lock | new suite `tests/validate-capability-registry.tests.sh`/`.ps1`: a fixture Registry with two `gates[]` entries sharing one `id` fails validation with a `gate-id-duplicate` diagnostic | Planned |
| AC-015 | REQ-003(b) | TEST-015 | completeness lock (stage-scoped) | same suite: a `stage: implementation` Gate missing `implementation_ref` (or pointing at a nonexistent path) fails with `implementation-ref-missing`; the identical shape at `stage: artifact`/`promotion` passes | Planned |
| AC-016 | REQ-003(c) | TEST-016 | identity-schema lock | same suite: `implementation_ref` pointing at a non-`.py` path (e.g. an `.sh` wrapper) is rejected as an invalid identity reference; a symlinked wrapper script resolves to its target before grouping; two `gates[]` entries that would resolve to the same wrapper-group identity (same-directory, same-basename `check-*` files) fail validation; a fixture scoped to a second, non-configured directory (i.e. anything other than the literal `plugins/sdd-quality-loop/scripts/`) confirms the scan root is a concrete, single value, not a pattern | Planned |
| AC-017 | REQ-003(c) | TEST-017 | bidirectional completeness lock | same suite: (i) an sh+ps1 wrapper pair for one `check-*.py` master counts as exactly one registered implementation — no `unregistered-script` diagnostic; (ii) a script placed outside `plugins/sdd-quality-loop/scripts/` is not flagged; (iii) an in-scan-root `check-*.py` script with no `gates[].implementation_ref` is flagged `unregistered-script`; (iv) an in-scan-root, non-`check-*`-prefixed script (e.g. `emit-run-record.py`) is never scanned or flagged, confirming the `check-` prefix is the gate-shaped-script selection rule | Planned |
| AC-018 | REQ-003(e) | TEST-018 | defense-in-depth lock | same suite: a validator-direct fixture (constructed to bypass schema validation) with a `gates[]` entry missing `stage` fails with `stage-missing`, proving the validator's own re-assertion fires independently of the schema | Planned |
| AC-019 | REQ-003(d) | TEST-019 | forward-guard | same suite: a fixture tree containing a `capability-packs/*/gates.yaml`-shaped file fails validation with a `pack-owns-gate-definition` diagnostic | Planned |
| AC-020 | REQ-003(g) | TEST-020 | boundary enforcement (negative, per-category) | same suite: one fixture per provider-terms category (cloud provider name, workflow-runtime product name, distribution-channel product name) each independently fails with a `provider-name-detected` diagnostic; a clean fixture using only provider-neutral vocabulary (e.g. `durable_workflow` as an `artifact_kinds` value) passes, proving no false positive | Planned |
| AC-021 | REQ-003(f) | TEST-021 | referential integrity (validator-only) | same suite: a `capabilities[].gate_ids` entry naming an undefined Gate ID fails with a `dangling-gate-reference` diagnostic; this is the only referential-integrity test in this package — no fixture anywhere in this suite asserts a schema-level dynamic reference check | Planned |
| AC-022 | REQ-003(h) | TEST-022 | catalog fail-closed lock | same suite: a `lite_policy.upgrade_reasons` token absent from `contracts/lite-upgrade-reason-catalog.json` fails validation with `unknown-upgrade-reason`; every token in the catalog's own `reasons` array passes | Planned |
| AC-023 | REQ-004 | TEST-023 | design-conformance (canonicalizer delegation) | new suite `tests/generate-registry-digest.tests.sh`/`.ps1`: the generator's implementation imports/calls Epic A1's canonicalizer module for the JCS step rather than containing an inline RFC 8785 implementation; a code-inspection-style check (or, once Epic A1 lands, a live call) confirms no YAML-1.2 parse path exists for this JSON-authored input | Planned (blocked on Epic A1's canonicalizer contract, requirements.md Dependencies) |
| AC-024 | REQ-004 | TEST-024 | fragment-identity lock | same suite: `--capability-ids <id>,<id>` and the same two IDs in reverse order, or with one duplicated, produce an identical digest; `--gate-ids <id>` selects that Gate directly even when no named Capability references it; an ID absent from the Registry in either flag is a hard failure (non-zero exit, `unknown-fragment-id`); `--whole` changes when any part of the Registry changes | Planned |
| AC-025 | REQ-005 | TEST-025 | generated-header conformance | new suite `tests/generate-gate-capabilities.tests.sh`/`.ps1`: the generated `gate-capabilities.json`'s `_generated` block carries `source`, `schema_version`, `sha256`, and the "Do not edit" notice string, matching guard-invariants' header *concept* (not its comment-line syntax); no fixture or assertion anywhere in this suite expects a `# Generated...` comment line, since `.json` cannot carry one | Planned |
| AC-026 | REQ-005 | TEST-026 | drift detection (negative canary) | same suite: a hand-mutated `gate-capabilities.json` (committed content diverging from what regeneration would produce) causes `--check` to exit non-zero; an unmutated, freshly-regenerated file causes `--check` to exit zero; an mtime-unchanged assertion proves `--check` performs no filesystem write | Planned |
| AC-027 | REQ-005 | TEST-027 | installed-layout discovery lock | new suite (Registry discovery, may be folded into the schema-conformance or validator suite's setup fixtures at implementation time): three fixtures — one simulating a standalone Claude Code install, one Codex CLI, one Copilot CLI — each with only the packaged `plugins/sdd-quality-loop/contracts/capability-registry.json`/`.schema.json`/`lite-upgrade-reason-catalog.json` present at the script-relative offset (no monorepo `contracts/`, no reachable `.git`, **no runtime environment variable set in any of the three fixtures**) — assert discovery succeeds via the packaged copy alone in every fixture, proving the contract does not depend on a runtime-specific variable; three per-artifact version-check fixtures (a `capability-registry.json` with the wrong `schema` value, a `.schema.json` with no `$schema` or a mismatched `$id`, a reason catalog with the wrong `schema` value) each assert a fail-closed diagnostic; a neither-location-resolves fixture asserts a fail-closed diagnostic naming both attempted paths; a fifth fixture asserts the release-gating `--check` mode fails when a vendored copy's sha256 diverges from its canonical `contracts/*` source | Planned |
| AC-028 | REQ-005 | TEST-028 | structural placement check | repository-structure assertion (implementation phase, run alongside the `validate-capability-registry` suite's own setup): `plugins/sdd-capability/` does not exist anywhere in the repository; `evaluate-predicate`, `validate-capability-registry`, `generate-registry-digest`, `generate-gate-capabilities`, and `references/provider-terms.json` all exist under `plugins/sdd-quality-loop/` | Planned |
| AC-029 | REQ-005 | TEST-029 | protected-file procedure proof | tasks.md's protected-file-registration task (design.md's Protected-File Statement) is verified in three parts, mirroring the `epic-159-pillar-c` AC-027 precedent: (a) a staged candidate for the `guard-invariants.json` addition exists under `specs/epic-190-a2-capability-registry/human-copy/` with a correct `MANIFEST.sha256` entry; (b) the live `guard-invariants.json` and its generated siblings are byte-identical before/after this Epic's implementation-phase work until a human applies the staged candidate; (c) after a human `cp`, the new paths (Components list, design.md) appear in the regenerated `guard_invariants.py`'s `PROTECTED_GATE_SUFFIXES`/`PHASE2_HUMAN_COPY_TARGETS` | Planned (Status resolves through a human `cp` action, not automation alone) |
| AC-030 | REQ-006 | TEST-030 | test-registration procedure proof | tasks.md's test-registration task is verified: each of the eight new `tests/*.tests.sh`/`.tests.ps1` pairs (Test Strategy items 1-8, design.md) is registered directly (unprotected) in `tests/run-all.sh`/`.ps1`; a staged candidate for its `.github/workflows/test.yml` registration exists under `specs/epic-190-a2-capability-registry/human-copy/` with a correct `MANIFEST.sha256` entry | Planned (Status resolves through a human `cp` action for the `test.yml` portion) |
| AC-031 | REQ-006 | TEST-031 | golden-fixture parity lock | new suite (parity harness shared by all four scripts): for `evaluate-predicate`, `validate-capability-registry`, `generate-registry-digest`, and `generate-gate-capabilities`, the `.sh`- and `.ps1`-wrapper invocations of the identical fixture input produce byte-identical stdout/output; `generate-registry-digest`'s `.js` wrapper is included in this comparison alongside its `.sh`/`.ps1` siblings | Planned |
| AC-032 | REQ-006 | TEST-032 | JCS/NFC vector + stable-ordering lock | `tests/generate-registry-digest.tests.sh`/`.ps1` (same suite as TEST-023/024): an RFC 8785 key-ordering/number-formatting vector fixture set and a Unicode NFC composed-vs-decomposed string-equivalence fixture set each assert identical digests for canonically-equivalent-but-differently-encoded input; a stable-ordering fixture re-confirms AC-024's ID-array sort independent of caller-supplied input order | Planned |
| AC-033 | REQ-006 | TEST-033 | 3-runtime invocation parity lock | same parity harness as TEST-031: each of the four scripts' wrapper pair is invoked from within a Claude Code, a Codex CLI, and a Copilot CLI installed-plugin context (ties to TEST-027's installed-layout fixtures) against the identical fixture input, asserting identical exit codes and stdout across all three runtimes | Planned |
| AC-035 | User Stories, Dependencies | TEST-035 | Phase 1 open-question audit | a grep/cross-reference audit (manual or lightly scripted) confirming OQ-001 and OQ-004 (investigation.md) are each cross-referenced from the relevant REQ/AC in requirements.md; this check is doable now, without `traceability.md` | Planned |
| AC-036 | User Stories, Dependencies | TEST-036 | Phase 2 traceability audit | `traceability.md` (once authored in Phase 2) cross-references every OQ-001..OQ-004 resolution against the REQ/design/task/test rows that resolved or trace it; a manual review-time check confirming none was resolved without a recorded trace | Deferred to Phase 2 (target file does not exist during this Phase 1 package) |

## Spec-Authoring-Time Manual Review Record

**AC-034** (scope boundary: no file under `plugins/`, `scripts/`,
`contracts/`, `tests/`, or `.github/` is created or modified by this spec
commit) is evaluated exactly once, at this spec package's own commit
boundary — not as a repeating, automated, implementation-phase test. Once
`tasks.md` schedules REQ-001..006's implementation, every one of those paths
is expected to change; an automated test asserting AC-034 as a Planned,
ongoing implementation-phase check would fail by construction the first time
implementation work lands, which is precisely the false-1:1 problem the
2026-07-22 adversarial review's Blocker/Major findings ("AC↔TEST 1:1 is
false" and "TEST-021 is a time-dependent test that must fail once
implemented") identified.

Resolution procedure (recorded here, not as a `tests/` file):
1. The human reviewer confirms, at the point they change this spec's
   `Spec-Review-Status` (or, failing that, at the point they merge this
   spec-authoring commit), that `git status`/`git diff` for the commit shows
   changes confined to `specs/epic-190-a2-capability-registry/`.
2. The reviewer records the confirmation against **this commit's own SHA**
   (filled in by the reviewer at review time — this file does not hardcode
   a commit hash it cannot yet know) in the spec-review-loop's own round
   record, not in this file.
3. This record is a one-time gate on the spec-authoring commit itself; it is
   not re-evaluated at every later commit against this feature (those
   commits are expected to touch `plugins/`, `contracts/`, `tests/`, and
   `.github/` by design, per `tasks.md`).

## Notes

- TEST-001..TEST-013 exercise **contract shape and evaluator semantics** in
  isolation from any Registry-validation policy; TEST-014..TEST-022 exercise
  **Registry-validation policy** against fixture Registries that are
  individually mutated to isolate exactly one failure mode each (never two
  failure modes in one fixture — a design choice carried over from this
  session's other reference specs' own negative-fixture discipline, e.g.
  `epic-159-pillar-c`'s TEST-054 "one fixture per malformed-field category").
- TEST-023/TEST-024/TEST-032 are the cases requiring Epic A1's canonicalizer
  to actually exist as an importable dependency (requirements.md
  Dependencies); every other test in this suite can be authored and run
  against fixture data alone, independent of Epic A1's landing order.
  TEST-011 similarly depends on Epic A1's Project Context schema landing for
  its drift-check half, though its `PREDICATE_SCHEMA_ERROR` half does not.
- TEST-027/TEST-033 are the cases requiring a simulated (not necessarily
  live) Claude Code/Codex CLI/Copilot CLI installed-plugin context; "3
  runtimes" here means three fixture *environments* the suite constructs,
  not three live product installations the CI job depends on.
- TEST-029/TEST-030 are the only cases whose "Planned" status resolves
  through a human action (the `cp` step), not purely through automation —
  consistent with every other protected-file precedent this repository
  already uses (`epic-159-pillar-c` TEST-027, `epic-136-phase2-gates`'s own
  human-copy suite).
- No TEST in this suite invokes a live LLM, a live Provider API, or any
  network call — every case is fixture-driven and fully offline, matching
  Global Constraints (design.md) and ADR-0020's forbidden-operator list.
