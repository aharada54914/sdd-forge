# Frontend Specification: epic-192-a4-facet-manifest

N/A — no change: this feature introduces no browser/client UI and no new
runtime service (design.md Technical Summary; Feature Type header line: "It
introduces no UI, no UX surface, no new runtime service, and no generator").
This document instead records the script/runtime inventory the four new
scripts and their wrapper pairs actually use, since design.md's Components
and Architecture sections already own that content and this file restates it
in the layer-file shape the review harness expects.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Script runtime (master) | Python | repository-standard, stdlib-only (not independently pinned by this spec) | Python master implements the actual schema-conformance / staleness-comparison logic for all four scripts (design.md Components); the hand-rolled schema validator is stdlib-only, no third-party `jsonschema` dependency (design.md Global Constraints, INV-014) | `.py` is always the canonical master; `.sh`/`.ps1` are thin wrappers invoking it (design.md Components) |
| Script runtime (wrappers) | POSIX sh, PowerShell | repository-standard | Thin wrappers invoking the Python master (design.md Components: `validate-facet-manifest.{py,sh,ps1}` etc.), one `.sh`/`.ps1` wrapper pair per `.py` master | byte-identical output across `.py`/`.sh`/`.ps1` per the Diagnostic determinism contract (design.md; AC-031) |

Unlike epic-190-a2 (which ships an additional `.js` wrapper for its digest
generator because that generator is a hash primitive requiring cross-runtime
`.js` parity), this feature's design.md Global Constraints state "No `.js`
wrapper for any of the four new scripts" — `compare-facet-manifest-staleness`
is a comparator/classifier, not a digest primitive, so it follows the
validator precedent (`.py`+`.sh`+`.ps1` only), not the digest-generator one.
No `.js` wrapper is introduced by this feature.

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A — no change: no browser UI, no client-side state, no routes, and no API
client of this feature's own. The closest analog — the four scripts' own CLI
invocation shapes, exit codes, and diagnostic-line formats — is fully
specified in design.md's API / Contract Plan (`validate-facet-manifest`
contract, `validate-capability-summary` contract, `validate-context-
projection` contract, `compare-facet-manifest-staleness` contract), not
duplicated here.

## Dependencies

| Dependency | Version | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| Epic A1 canonicalizer (`canonicalize-sdd-yaml`, imported as a subprocess, not vendored or reimplemented) | pending Epic A1 shipping this utility (requirements.md Dependencies; design.md Cross-Layer Dependencies) | the single YAML→structure parse path for `validate-facet-manifest`/`validate-capability-summary` and the two-pass canonicalization behind Context Projection generation (design.md "YAML parse contract"; Assumptions) — a non-zero canonicalizer exit is surfaced as the validator's own diagnostic, never swallowed or retried with a fallback parser | none — the scripts hand-roll no YAML parser of any kind; a canonicalizer-invocation failure fails closed (design.md "YAML parse contract") | Internal (same repository); no external package |
| Epic A2 `contracts/capability-registry.schema.json` + `evaluate-predicate` Evidence shape | pending Epic A2 reaching implementation (requirements.md Assumptions) | REQ-001's `conditional_facets[].evidence` node shape is a structural transcription of Epic A2's array-shaped Evidence output, not a live `$ref` (design.md API / Contract Plan) | none — the small, stable Evidence shape is duplicated verbatim rather than `$ref`-linked across separately-versioned files | Internal (same repository); no external package |

No new external (npm/pip/etc.) package is introduced by this feature — the
Python scripts are stdlib-only (design.md Global Constraints, INV-014). See
security-spec.md's SBOM and Supply Chain section for the full statement.

## Testing

Six new `tests/*.tests.sh`/`.tests.ps1` suite pairs
(`facet-manifest-schema`, `facet-manifest-semantics`,
`capability-summary-schema`, `context-projection-schema`,
`facet-manifest-staleness`, `facet-manifest-parity` — design.md Test
Strategy, AC-033), registered directly (unprotected) in
`tests/run-all.sh`/`.ps1` and staged via human-copy into
`.github/workflows/test.yml` (design.md Deployment / CI Plan; Test Strategy).
No browser/UI test tooling applies — no UI exists for this feature.

## Open Questions

- None.
