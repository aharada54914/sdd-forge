# Acceptance Tests: epic-192-a4-facet-manifest

TEST IDs are namespaced to this feature
(`specs/epic-192-a4-facet-manifest/`) and map 1:1 to
`requirements.md`'s Acceptance Criteria by matching row number
(AC-NNN ↔ TEST-NNN), with one documented class of exception:

- **AC-036, AC-037, and AC-038 have no TEST-036/037/038 rows.** All three
  are spec-commit-bound scope-boundary statements about *this Phase 1
  package's own registration commit* (Global ACs, requirements.md), not
  automated implementation-phase tests a future `tests/*.tests.sh` suite
  would run — they are checked directly against the live repository by
  running the named validator scripts, once, at registration time (mirroring
  `specs/epic-190-a2-capability-registry/acceptance-tests.md`'s identical
  AC-034 exception). See "Spec-Authoring-Time Manual Review Record", below.

Every other row named below is a **design-phase target**: no suite file
exists yet (this spec's Non-goals; a future `tasks.md` schedules authoring
them, once this package's own `Spec-Review-Status`/`Impl-Review-Status`
reach `Passed`).

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | contract existence + `$id` convention | new suite `tests/facet-manifest-schema.tests.sh`/`.ps1`: `contracts/facet-manifest.schema.json` exists, is valid draft-07, and its `$id` matches every other `contracts/*.schema.json`'s convention | Planned |
| AC-002 | REQ-001 | TEST-002 | required-field matrix | same suite: one fixture per top-level required field (deleting exactly that field, matching Epic A1's Field Requirement Matrix pattern); `capability_minimum_enforcement` absent is separately confirmed schema-valid | Planned |
| AC-003 | REQ-001 | TEST-003 | uniqueItems + empty-array | same suite: `affected_components`/`required_facets`/`capabilities` each reject a duplicate-entry fixture and accept an empty-array fixture | Planned |
| AC-004 | REQ-001 | TEST-004 | conditional-required (`if`/`then`/`else`) | same suite: `applied: false` without `reason` is rejected; `applied: false` with `reason` is accepted; `applied: true` with a `reason` present is rejected; `applied: true` without `reason` is accepted | Planned |
| AC-005 | REQ-001 | TEST-005 | Evidence-shape conformance | same suite: `conditional_facets[].evidence` validates against the embedded Evidence definition; a fixture with an `operator` value outside the fixed 8-value enum is rejected | Planned |
| AC-006 | REQ-001 | TEST-006 | `resolved_gates[]` shape | same suite: a `stage` value outside `implementation`/`artifact`/`promotion` is rejected; a fixture missing any of `id`/`stage`/`blocking` is rejected | Planned |
| AC-007 | REQ-001 | TEST-007 | const + optionality | same suite: `capability_minimum_enforcement: "required"` accepted; any other string value rejected; field entirely absent accepted | Planned |
| AC-008 | REQ-001 | TEST-008 | required/default | same suite: `lite_eligibility` missing `eligible` is rejected; `upgrade_reasons` absent defaults to `[]` and is accepted | Planned |
| AC-009 | REQ-001 | TEST-009 | digest pattern + minItems | same suite: each of `full_context_revision`/`projection_sha256`/`registry_digest`/`ownership_digest` rejects a non-`sha256:<64-hex>` fixture; `dependency_pointers: []` is rejected (`minItems: 1`) | Planned |
| AC-010 | REQ-001 | TEST-010 | semver pattern | same suite: `resolver.version: "1.1"` (two components) is rejected; `resolver.version: "1.1.0"` is accepted | Planned |
| AC-011 | REQ-001 | TEST-011 | worked-example conformance | same suite: decision document v2 §16's literal `context_binding`/`resolver` example, embedded in an otherwise-minimal-valid Facet Manifest, validates successfully | Planned |
| AC-012 | REQ-002 | TEST-012 | contract existence + `if`/`then`/`else` | new suite `tests/capability-summary-schema.tests.sh`/`.ps1`: `contracts/capability-summary.schema.json` exists; `track: lite` requires `required_lite_checks`+`full_upgrade_required` and forbids `facet_manifest_ref`; `track: full` requires `facet_manifest_ref` and forbids the two lite-only fields | Planned |
| AC-013 | REQ-002 | TEST-013 | worked-example conformance | same suite: decision document v2 §6's literal Lite Capability Summary example, extended with `schema`/`track: lite`, validates successfully | Planned |
| AC-014 | REQ-002 | TEST-014 | cross-branch rejection | same suite: a `track: full` fixture with `facet_manifest_ref` set is accepted; the same fixture with `required_lite_checks` also present is rejected | Planned |
| AC-015 | REQ-003 | TEST-015 | re-keying proof | new suite `tests/context-projection-schema.tests.sh`/`.ps1`: a two-component raw-`project-context.yaml` fixture, transformed per REQ-003's procedure, produces a `components` object with exactly two `id`-valued keys, and neither value carries its own `id` sub-field | Planned |
| AC-016 | REQ-003 | TEST-016 | end-to-end pointer resolution | same suite: `/components/desktop-client/artifact_kinds` (decision document v2 §16's own example) resolves via RFC 6901 against an AC-015-shaped fixture Context Projection to a real value | Planned |
| AC-017 | REQ-003 | TEST-017 | root-allowlist semantic check | `tests/facet-manifest-semantics.tests.sh`/`.ps1`: `validate-facet-manifest.py` rejects a `dependency_pointers` entry whose first segment is not `workflow`/`components`/`shared_paths` with `dependency-pointer-root-not-allowlisted` | Planned |
| AC-018 | REQ-003 | TEST-018 | malformed-pointer schema rejection | `tests/facet-manifest-schema.tests.sh`/`.ps1`: a `dependency_pointers` entry with no leading `/`, or an unescaped bare `~`, is rejected at the schema level (`pattern` violation) | Planned |
| AC-019 | REQ-004 | TEST-019 | digest-only-change, not-stale lock | `tests/facet-manifest-staleness.tests.sh`/`.ps1`: a fixture pair differing only in `context_binding.registry_digest` is classified not-stale (metadata-only refresh) | Planned |
| AC-020 | REQ-004 | TEST-020 | same-gate-ID attribute-change, stale lock | same suite: a fixture pair differing in `registry_digest` and in one `resolved_gates[]` entry's `blocking` value (same `id`) is classified stale | Planned |
| AC-021 | REQ-004 | TEST-021 | `evidence`-exclusion gap-closing lock | same suite: a fixture pair differing only in `conditional_facets[].evidence` (identical `facet`/`applied`/`reason`) is classified not-stale | Planned |
| AC-022 | REQ-004 | TEST-022 | minimum-enforcement-tightening lock | same suite: a fixture pair where `capability_minimum_enforcement` goes from absent to `"required"` is classified stale | Planned |
| AC-023 | REQ-004 | TEST-023 | Policy-Weakening short-circuit lock | same suite: a fixture representing `weakening_verdict.policy_weakening: true` blocks unconditionally even when every semantic-output field is byte-identical old-vs-new | Planned |
| AC-024 | REQ-004 | TEST-024 | scope-narrowing lock (no Registry/ownership weakening) | same suite: a `registry_digest`-changed fixture with no Epic-A1 weakening verdict goes through the ordinary comparison path, never the Block short-circuit, even when the underlying edit resembles a weakening (e.g. a `minimum_enforcement` field removed) | Planned |
| AC-025 | REQ-005 | TEST-025 | patch-tier no-op lock | same suite: a patch-only `resolver.version` bump with byte-identical semantic output requires no regeneration | Planned |
| AC-026 | REQ-005 | TEST-026 | minor-tier impact-assessment lock | same suite: a minor bump triggers the REQ-004 comparison; one fixture where semantic output changes (stale) and one where it does not (not stale) | Planned |
| AC-027 | REQ-005 | TEST-027 | major-tier forced-regardless lock | same suite: a major bump forces re-resolve even when semantic output is otherwise byte-identical | Planned |
| AC-028 | REQ-006 | TEST-028 | diagnostic-id table lock | `tests/facet-manifest-semantics.tests.sh`/`.ps1`: one fixture per `validate-facet-manifest` diagnostic-id table row (`schema-invalid`, `resolved-gate-id-duplicate`, `facet-classification-conflict`, `dependency-pointer-root-not-allowlisted`), plus one fully-clean fixture proving a negative | Planned |
| AC-029 | REQ-006 | TEST-029 | dual-track validator lock | `tests/capability-summary-schema.tests.sh`/`.ps1`: `validate-capability-summary.py` exits 0 on a valid `track: lite` and a valid `track: full` fixture, and non-zero on a field-mixing fixture | Planned |
| AC-030 | REQ-006 | TEST-030 | re-keying enforcement lock | `tests/context-projection-schema.tests.sh`/`.ps1`: `validate-context-projection.py` exits 0 on a valid re-keyed fixture and non-zero on a fixture where `components` is still array-shaped | Planned |
| AC-031 | REQ-006 | TEST-031 | golden-fixture parity lock | new suite (parity harness shared by all three scripts): `.py`/`.sh`/`.ps1` invocations of every fixture above produce byte-identical exit codes and diagnostic output | Planned |
| AC-032 | REQ-006 | TEST-032 | installed-layout discovery lock | same parity suite: three fixtures per script (one per runtime) with only the packaged `plugins/sdd-quality-loop/contracts/*.schema.json` copy present (no monorepo `contracts/`, no reachable `.git`) each resolve and validate correctly | Planned |
| AC-033 | REQ-006 | TEST-033 | test-registration procedure proof | tasks.md's (future, Phase 2) test-registration task is verified: all four new `tests/*.tests.sh`/`.tests.ps1` pairs are registered directly (unprotected) in `tests/run-all.sh`/`.ps1`; a staged candidate for `.github/workflows/test.yml` registration exists under `specs/epic-192-a4-facet-manifest/human-copy/` with a correct `MANIFEST.sha256` entry | Planned (Status resolves through a human `cp` action for the `test.yml` portion) |
| AC-034 | REQ-007 | TEST-034 | placement-regression lock | `tests/facet-manifest-schema.tests.sh`/`.ps1`'s own setup fixture: a fixture `specs/<feature>/` tree with `facet-manifest.yaml`/`capability-summary.yaml` present alongside `requirements.md`/`design.md`/`acceptance-tests.md` passes `check-sdd-structure.sh`'s repository-root-level checks unchanged | Planned |
| AC-035 | REQ-008 | TEST-035 | version-mutation self-check | repository-wide grep-based self-check (implementation-phase, run once per task landing): no version string is mutated anywhere in the diff outside a `scripts/bump-version.sh` invocation | Planned |

## Spec-Authoring-Time Manual Review Record

AC-036, AC-037, and AC-038 (Global, requirements.md) are verified directly
against the live repository as part of this Phase 1 package's own two
commits, not by an automated test suite:

- **AC-036** (`check-workflow-state.sh --feature epic-192-a4-facet-manifest`
  exits 0): verified after the registration commit lands the new
  `specs/workflow-state-registry.json` entry, `requirements.md`'s
  `Spec-Review-Status: Pending` header, and `design.md`'s
  `Impl-Review-Status: Pending` header, with no `tasks.md`/`traceability.md`
  present.
- **AC-037** (`check-sdd-structure.sh` — no feature argument — exits 0):
  verified after the registration commit, run as
  `sh scripts/check-sdd-structure.sh .` (matching the documented usage in
  `docs/skill-reference.md` and this feature's own INV-016), which never
  enters the per-feature four-layer-file check.
- **AC-038** (registry entry shape): verified by inspecting the new
  `specs/workflow-state-registry.json` entry directly —
  `{"feature": "epic-192-a4-facet-manifest", "profile": "full"}`, no
  additional keys — and by `check-workflow-state.sh`'s own registry-shape
  jq assertion (which independently enforces `(keys | sort) ==
  ["feature","profile"]` for any `full`/`lite` entry) passing as part of
  AC-036's same run.

None of the three requires a `tests/*.tests.sh` suite of its own: all three
are one-shot facts about this specific package's registration commit, not
reusable, fixture-driven regression tests a future code change could break
— the same reasoning `specs/epic-190-a2-capability-registry/acceptance-
tests.md` records for its own, structurally identical AC-034 exception.
