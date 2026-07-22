# Traceability: epic-192-a4-facet-manifest

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-002, INV-004, INV-005, INV-006, INV-014 | security-spec.md#trust-boundaries | design.md#api--contract-plan (`contracts/facet-manifest.schema.json` block: `conditionalFacet`/`evidenceNode`/`resolvedGate`/`liteEligibility`/`contextBinding`/`resolverBlock`/`sha256Digest`); design.md#design-decisions-resolving-open-questions (`evidence`/`schema`/`feature` semantic-output reversal; `conditional_facets` total-order prohibition; `upgrade_reasons` sorted-and-unique) | `contracts/facet-manifest.schema.json` draft-07 schema: 10-field top-level `required`; `affected_components`/`required_facets`/`capabilities` unique-string arrays; `conditional_facets[]` `if`/`then`/`else`; `evidence` array of `evidenceNode`; `resolved_gates[]` `{id,stage,blocking}`; `capability_minimum_enforcement` const-or-absent; `lite_eligibility` required `upgrade_reasons`; `context_binding`/`resolver` digest/semver patterns; combined syntax+root `dependency_pointers[].pattern` | plugins/sdd-quality-loop/scripts/validate-facet-manifest.py; validate-facet-manifest.sh; validate-facet-manifest.ps1; tests/facet-manifest-schema.tests.sh; tests/facet-manifest-schema.tests.ps1; tests/facet-manifest-semantics.tests.sh; tests/facet-manifest-semantics.tests.ps1 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-007, TEST-008, TEST-009, TEST-010, TEST-011, TEST-017, TEST-018, TEST-028, TEST-041, TEST-047, TEST-048 | tests/facet-manifest-schema.tests.{sh,ps1}; tests/facet-manifest-semantics.tests.{sh,ps1} | reports/quality-gate/ for T-001; specs/epic-192-a4-facet-manifest/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-010 | security-spec.md#trust-boundaries | design.md#api--contract-plan (`contracts/capability-summary.schema.json` block); design.md#design-decisions-resolving-open-questions ("Capability Summary schema is Lite-track-only") | `contracts/capability-summary.schema.json`: exact six-field `required` set (`schema`,`feature`,`track`,`capabilities`,`required_lite_checks`,`full_upgrade_required`); `track` const `"lite"`; `additionalProperties: false`, no full-track branch | plugins/sdd-quality-loop/scripts/validate-capability-summary.py; validate-capability-summary.sh; validate-capability-summary.ps1; tests/capability-summary-schema.tests.sh; tests/capability-summary-schema.tests.ps1 | TEST-012, TEST-013, TEST-014, TEST-029 | tests/capability-summary-schema.tests.{sh,ps1} | reports/quality-gate/ for T-002; specs/epic-192-a4-facet-manifest/verification/T-002/ | Planned |
| REQ-003 | investigation.md INV-007, INV-008, INV-009 | security-spec.md#trust-boundaries; infra-spec.md#deployment-topology | design.md#api--contract-plan (`contracts/context-projection.schema.json` block; "Generation procedure" — normative for Epic A5, not built by this feature); design.md#design-decisions-resolving-open-questions ("B3" relaxed key vocabulary; "B8" source-omission normalization, folded into Goals) | `contracts/context-projection.schema.json`: `components` object keyed by A1-identical non-empty-string ids (`propertyNames`+schema-typed `additionalProperties`, no character-set restriction); `shared_paths[]` bounded/unbounded `oneOf`; `projectedComponent` definition; `dependency_pointers` re-keyed-projection addressing (RFC 6901) | plugins/sdd-quality-loop/scripts/validate-context-projection.py; validate-context-projection.sh; validate-context-projection.ps1; tests/context-projection-schema.tests.sh; tests/context-projection-schema.tests.ps1 | TEST-015, TEST-016, TEST-030, TEST-042 | tests/context-projection-schema.tests.{sh,ps1} | reports/quality-gate/ for T-003; specs/epic-192-a4-facet-manifest/verification/T-003/ | Planned |
| REQ-004 | investigation.md INV-012, INV-019 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | design.md#api--contract-plan (`compare-facet-manifest-staleness` contract: Invocation, Output, Exit codes, Branch order in full); design.md#design-decisions-resolving-open-questions ("Policy-Weakening short-circuit is uniform... fails closed"; "three `--*-weakening` inputs are mandatory"; "stdout, exit-code, and error contracts are unified") | `compare-facet-manifest-staleness` CLI: `--old-manifest`/`--new-manifest`/three mandatory `--*-weakening` enum flags/`--resolver-version-bump`; semantic-output field set (every REQ-001 field except `context_binding`/`resolver`); 5-branch precedence table; `<status>:<reason>` stdout; exit `0`/`1`/`2`/`3` | plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.py; compare-facet-manifest-staleness.sh; compare-facet-manifest-staleness.ps1; tests/facet-manifest-staleness.tests.sh; tests/facet-manifest-staleness.tests.ps1 | TEST-019, TEST-020, TEST-021, TEST-022, TEST-023, TEST-024, TEST-039, TEST-040, TEST-044 | tests/facet-manifest-staleness.tests.{sh,ps1} | reports/quality-gate/ for T-004; specs/epic-192-a4-facet-manifest/verification/T-004/ | Planned |
| REQ-005 | investigation.md INV-011 | security-spec.md#stride-analysis | design.md#api--contract-plan (`compare-facet-manifest-staleness` contract, branch order items 2-4); design.md#design-decisions-resolving-open-questions ("`rule_set_revision`-only change treated as a minor-tier transition"; "Major-version-bump precedence over an unrelated digest change") | `compare-facet-manifest-staleness --resolver-version-bump {none,patch,minor,minor-rule-set,major}`: patch-tier no-op; minor/minor-rule-set unconditional impact assessment; major unconditional forced-stale below Block; tier/actual-diff consistency check (argument error on mismatch) | plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.py (shared with REQ-004); tests/facet-manifest-staleness.tests.sh; tests/facet-manifest-staleness.tests.ps1 | TEST-025, TEST-026, TEST-027, TEST-045, TEST-046 | tests/facet-manifest-staleness.tests.{sh,ps1} | reports/quality-gate/ for T-004; specs/epic-192-a4-facet-manifest/verification/T-004/ | Planned |
| REQ-006 | investigation.md INV-014, INV-018 | infra-spec.md#cicd-sequence; security-spec.md#security-tests; security-spec.md#sbom-and-supply-chain | design.md#api--contract-plan (`validate-facet-manifest`/`validate-capability-summary`/`validate-context-projection` contracts; YAML parse contract; Discovery contract; Diagnostic determinism contract); design.md#test-strategy (six-suite list in full) | four scripts' hand-rolled draft-07 subset validator + diagnostic-id tables; Discovery contract (script-relative then git-root fallback, fail-closed); vendored `plugins/sdd-quality-loop/contracts/*.schema.json` copies + `--check` drift gate; fixed `(check-id, JSON-Pointer-path)` sort order, RFC 6901 path representation, UTF-8/LF-only, fixed exit codes | plugins/sdd-quality-loop/scripts/validate-facet-manifest.{py,sh,ps1}; validate-capability-summary.{py,sh,ps1}; validate-context-projection.{py,sh,ps1}; compare-facet-manifest-staleness.{py,sh,ps1}; plugins/sdd-quality-loop/contracts/{facet-manifest,capability-summary,context-projection}.schema.json; tests/facet-manifest-schema.tests.{sh,ps1}; tests/facet-manifest-semantics.tests.{sh,ps1}; tests/capability-summary-schema.tests.{sh,ps1}; tests/context-projection-schema.tests.{sh,ps1}; tests/facet-manifest-staleness.tests.{sh,ps1}; tests/facet-manifest-parity.tests.{sh,ps1} | TEST-028, TEST-029, TEST-030, TEST-031, TEST-032, TEST-033, TEST-043, TEST-044 | tests/facet-manifest-parity.tests.{sh,ps1} (cross-cutting AC-031/032/033/043); each schema's own suite (per-script AC-028/029/030) | reports/quality-gate/ for T-001, T-002, T-003, T-004, T-005; specs/epic-192-a4-facet-manifest/verification/{T-001..T-005}/ | Planned |
| REQ-007 | investigation.md INV-010 | infra-spec.md#data-residency-and-retention | design.md#components (`specs/<feature>/facet-manifest.yaml`/`capability-summary.yaml`, no instance committed by this feature); design.md#design-decisions-resolving-open-questions ("Facet Manifest and Capability Summary are `.yaml`, not `.json`") | storage-location convention: `specs/<feature>/facet-manifest.yaml`, `specs/<feature>/capability-summary.yaml`, unprotected, agent-writable-only-via-the-Resolver | tests/facet-manifest-schema.tests.sh (AC-034 setup fixture); tests/facet-manifest-schema.tests.ps1 | TEST-034 | tests/facet-manifest-schema.tests.{sh,ps1} | reports/quality-gate/ for T-001; specs/epic-192-a4-facet-manifest/verification/T-001/ | Planned |
| REQ-008 | investigation.md INV-013 | N/A — cross-layer only: a documentation/versioning-discipline requirement (per-task CHANGELOG entries, a version-mutation grep self-check, no new ADR) with no UX/frontend/infra/security-layer surface of its own — design.md Layer Specifications frames every layer N/A or Infrastructure-only for this feature, and REQ-008's own text names no infra/security control | design.md#global-constraints ("Version bumps only via `scripts/bump-version.sh`"; "No new ADR"); design.md#adr-change-log ("No new ADR is proposed by this spec") | no new runtime contract; each of T-001..T-005 lands its own `CHANGELOG.md` bullet under the existing `## Unreleased` header citing #192; no `docs/adr/00NN-*.md` file added; grep self-check confirms no version string mutated outside `scripts/bump-version.sh` | CHANGELOG.md | TEST-035 | CHANGELOG.md `## Unreleased` bullets (5, one per T-001..T-005) | reports/quality-gate/ for T-001..T-005; specs/epic-192-a4-facet-manifest/verification/{T-001..T-005}/ | Planned |

## Global Acceptance Criteria (spec-commit-bound, not implementation-phase tasks)

AC-036, AC-037, and AC-038 (Global, requirements.md) are **intentionally not
mapped to any task above.** acceptance-tests.md states explicitly that all
three are "spec-commit-bound scope-boundary statements about this Phase 1
package's own registration commit," verified once, directly against the live
repository, not by an automated `tests/*.tests.sh` suite a Phase 2 task would
own (mirroring `specs/epic-190-a2-capability-registry/acceptance-
tests.md`'s identical AC-034 exception). All three were satisfied by this
feature's own spec-phase registration commit — the `specs/workflow-state-
registry.json` entry (`{"feature": "epic-192-a4-facet-manifest", "profile":
"full"}`), `requirements.md`'s `Spec-Review-Status: Passed` transition, and
`design.md`'s `Impl-Review-Status: Passed` transition — which already landed
before this `tasks.md`/`traceability.md` pair was authored. No task above
re-verifies them; doing so would re-run a check against artifacts this
feature's own frozen spec-phase commits already fixed.

The "Draft-07 metaschema conformance" one-shot manual review
(acceptance-tests.md "Spec-Authoring-Time Manual Review Record") names a
check against the *content* of the three schemas — content that exists only
inside `design.md`'s JSON blocks until each schema *file* is actually
created. This traceability document schedules that one-shot check inside
each owning task's own Done When list (T-001 for `facet-manifest.schema.
json`, T-002 for `capability-summary.schema.json`, T-003 for `context-
projection.schema.json`), immediately after each file is authored, rather
than as a separate task — it is not a reusable regression test (the schema
files are content-frozen once each task's own quality-gate passes, matching
AC-036/037/038's non-regression treatment), so it belongs beside the file it
checks, not in a sixth standalone task.

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — schema/script feature work only | ux-spec.md | No rendered or interactive surface; three static contract files and four deterministic CLI scripts have no GUI entry point (design.md Technical Summary; Design System Compliance: "Not applicable — no UI surface"). ux-spec.md records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — CLI/script feature work | frontend-spec.md#technology-stack | Python master + `sh`/`ps1` wrappers, no `.js` wrapper, no browser/client UI, no new runtime service; frontend-spec.md records N/A and restates the script/runtime inventory in the layer-file shape only. |
| Infrastructure | REQ-003, REQ-006, REQ-007 | AC-015, AC-031, AC-032, AC-033, AC-034 | infra-spec.md#cicd-sequence; infra-spec.md#deployment-topology; infra-spec.md#data-residency-and-retention | The six new `.sh`/`.ps1` suite pairs register in `tests/run-all.*` (direct edit) and stage their `.github/workflows/test.yml` CI steps via human-copy (R-10 protected, matching every sibling epic's CI-registration precedent); no new CI job/matrix dimension — wired the same way Epic A2's `--check` mode is wired (design.md Deployment / CI Plan). |
| Security | REQ-001, REQ-004, REQ-005, REQ-006 | AC-009, AC-023, AC-024, AC-031, AC-032, AC-040, AC-043, AC-044, AC-046 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis; security-spec.md#security-tests; security-spec.md#sbom-and-supply-chain | Five boundaries B1-B5 (canonicalizer subprocess parse; `context_binding` digest-binding provenance; Policy-Weakening fail-closed staleness; schema-file discovery/vendored-copy integrity; provider-neutrality); no new trust boundary crossed — every deliverable is a read-only structural validator or comparator over already-repository-trusted files, no network access, no dynamic code execution, no credential handling (security-spec.md Framing). |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-006 (share — AC-017, AC-018, AC-028, AC-041, AC-047, AC-048), REQ-007 (share — AC-034), REQ-008 (share — AC-035) | TEST-001..011, TEST-017, TEST-018, TEST-028, TEST-034, TEST-035 (share), TEST-041, TEST-047, TEST-048 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-192-a4-facet-manifest/verification/T-001/green-sh.log, .../T-001/red-sh.log, .../T-001/metaschema-conformance.md |
| T-002 | REQ-002, REQ-006 (share — AC-029), REQ-008 (share — AC-035) | TEST-012, TEST-013, TEST-014, TEST-029, TEST-035 (share) | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-192-a4-facet-manifest/verification/T-002/green-sh.log, .../T-002/red-sh.log, .../T-002/metaschema-conformance.md |
| T-003 | REQ-003, REQ-006 (share — AC-030, AC-042), REQ-008 (share — AC-035) | TEST-015, TEST-016, TEST-030, TEST-042, TEST-035 (share) | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-192-a4-facet-manifest/verification/T-003/green-sh.log, .../T-003/red-sh.log, .../T-003/metaschema-conformance.md |
| T-004 | REQ-004, REQ-005, REQ-006 (share — AC-044, AC-045, AC-046), REQ-008 (share — AC-035) | TEST-019..027, TEST-039, TEST-040, TEST-044, TEST-045, TEST-046, TEST-035 (share) | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-192-a4-facet-manifest/verification/T-004/green-sh.log, .../T-004/red-sh.log |
| T-005 | REQ-006 (primary — AC-031, AC-032, AC-033, AC-043), REQ-008 (share — AC-035) | TEST-031, TEST-032, TEST-033, TEST-043, TEST-035 (share) | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-192-a4-facet-manifest/verification/T-005/green-sh.log, .../T-005/red-sh.log, .../T-005/vendor-check.log |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-001 |
| AC-002 | TEST-002 | T-001 |
| AC-003 | TEST-003 | T-001 |
| AC-004 | TEST-004 | T-001 |
| AC-005 | TEST-005 | T-001 |
| AC-006 | TEST-006 | T-001 |
| AC-007 | TEST-007 | T-001 |
| AC-008 | TEST-008 | T-001 |
| AC-009 | TEST-009 | T-001 |
| AC-010 | TEST-010 | T-001 |
| AC-011 | TEST-011 | T-001 |
| AC-012 | TEST-012 | T-002 |
| AC-013 | TEST-013 | T-002 |
| AC-014 | TEST-014 | T-002 |
| AC-015 | TEST-015 | T-003 |
| AC-016 | TEST-016 | T-003 |
| AC-017 | TEST-017 | T-001 |
| AC-018 | TEST-018 | T-001 |
| AC-019 | TEST-019 | T-004 |
| AC-020 | TEST-020 | T-004 |
| AC-021 | TEST-021 | T-004 |
| AC-022 | TEST-022 | T-004 |
| AC-023 | TEST-023 | T-004 |
| AC-024 | TEST-024 | T-004 |
| AC-025 | TEST-025 | T-004 |
| AC-026 | TEST-026 | T-004 |
| AC-027 | TEST-027 | T-004 |
| AC-028 | TEST-028 | T-001 |
| AC-029 | TEST-029 | T-002 |
| AC-030 | TEST-030 | T-003 |
| AC-031 | TEST-031 | T-005 |
| AC-032 | TEST-032 | T-005 |
| AC-033 | TEST-033 | T-005 (cumulative — verified complete only once all of T-001..T-005 have landed their own suite registration) |
| AC-034 | TEST-034 | T-001 |
| AC-035 | TEST-035 | T-001 (share), T-002 (share), T-003 (share), T-004 (share), T-005 (share) — each task's own CHANGELOG bullet + own no-version-bump grep self-check |
| AC-039 | TEST-039 | T-004 |
| AC-040 | TEST-040 | T-004 |
| AC-041 | TEST-041 | T-001 |
| AC-042 | TEST-042 | T-003 |
| AC-043 | TEST-043 | T-005 |
| AC-044 | TEST-044 | T-004 |
| AC-045 | TEST-045 | T-004 |
| AC-046 | TEST-046 | T-004 |
| AC-047 | TEST-047 | T-001 |
| AC-048 | TEST-048 | T-001 |

Global ACs AC-036, AC-037, AC-038 are intentionally absent from this table —
see "Global Acceptance Criteria (spec-commit-bound, not implementation-phase
tasks)" above.

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #192 | contracts/facet-manifest.schema.json; plugins/sdd-quality-loop/scripts/validate-facet-manifest.{py,sh,ps1}; plugins/sdd-quality-loop/contracts/facet-manifest.schema.json; tests/facet-manifest-schema.tests.{sh,ps1}; tests/facet-manifest-semantics.tests.{sh,ps1}; tests/fixtures/facet-manifest/ (base tree) | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (own bullet); specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml (staged); specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256 |
| T-002 | #192 | contracts/capability-summary.schema.json; plugins/sdd-quality-loop/scripts/validate-capability-summary.{py,sh,ps1}; plugins/sdd-quality-loop/contracts/capability-summary.schema.json; tests/capability-summary-schema.tests.{sh,ps1} | tests/fixtures/facet-manifest/; tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (own bullet); specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256 |
| T-003 | #192 | contracts/context-projection.schema.json; plugins/sdd-quality-loop/scripts/validate-context-projection.{py,sh,ps1}; plugins/sdd-quality-loop/contracts/context-projection.schema.json; tests/context-projection-schema.tests.{sh,ps1} | tests/fixtures/facet-manifest/; tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (own bullet); specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256 |
| T-004 | #192 | plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.{py,sh,ps1}; tests/facet-manifest-staleness.tests.{sh,ps1} | tests/fixtures/facet-manifest/; tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (own bullet); specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256 |
| T-005 | #192 | tests/facet-manifest-parity.tests.{sh,ps1}; plugins/sdd-quality-loop/scripts/generate-vendored-contracts-check.py (or an in-place extension of an existing vendoring `--check` mechanism, re-verified at implementation-start time) | tests/fixtures/facet-manifest/; tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (own bullet); specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml (staged, final — all six suites); specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256 |

## Final Status

Update requirement status only from saved test evidence and quality-gate
reports. Implementation reports are claims, not independent verification
evidence.
