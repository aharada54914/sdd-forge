# Frontend Specification: epic-193-a5-capability-resolver

N/A — no change: this feature introduces no browser/client UI and no new
runtime service (design.md Technical Summary; Feature Type header line:
"one new deterministic script family ... plus companion validator
scripts ... No new plugin"). This document instead records the
script/runtime inventory the new scripts actually use, since design.md's
Components and API / Contract Plan sections already own that content and
this file restates it in the layer-file shape the review harness expects.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Script runtime (master) | Python | repository-standard, stdlib-only (design.md Global Constraints: "No third-party Python dependency anywhere in this feature's own scripts", investigation.md INV-011) | `resolve-project-context.py` and `validate-resolver-evidence.py` implement the actual orchestration/evaluation logic and the hand-rolled, closed-subset draft-07 schema validator respectively (design.md Components; `validate-resolver-evidence` contract) | `.py` is always the canonical master; `.sh`/`.ps1` are thin dispatchers invoking it, matching `canonicalize-sdd-yaml`'s own dispatch shape (Epic A1 precedent, design.md Components) |
| Script runtime (wrappers) | POSIX sh, PowerShell | repository-standard | Thin `python3`/`python` resolution dispatchers only — no native fallback (design.md Components) | byte-identical output across `.py`/`.sh`/`.ps1` per REQ-005 (AC-022, AC-023) |

design.md's Components table lists only `.py`+`.sh`+`.ps1` for both
`resolve-project-context.*` and `validate-resolver-evidence.*` — no `.js`
wrapper is named for either script family anywhere in design.md, matching
Epic A4's own validator-script precedent (three structural validators,
`.py`+`.sh`+`.ps1` only) rather than Epic A2's digest-primitive precedent
(which alone needs a `.js` wrapper for its own cross-runtime hashing
concern, security-spec.md SBOM and Supply Chain).

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A — no change: no browser UI, no client-side state, no routes, and no
API client of this feature's own. The closest analog — the two scripts'
own CLI invocation shapes, exit codes, and diagnostic-line formats — is
fully specified in design.md's API / Contract Plan (`resolve-project-
context.{py,sh,ps1}` CLI contract; `validate-resolver-evidence.{py,sh,
ps1}` contract), not duplicated here.

## Dependencies

| Dependency | Version | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| Epic A1 `canonicalize-sdd-yaml` (subprocess, not vendored or reimplemented) | pending Epic A1 shipping this utility (requirements.md Assumptions) | Project Context canonicalization (pass 1, `source_sha256`) and Context Projection re-keyed-structure canonicalization (pass 2, `projection_sha256`) — design.md Architecture / API / Contract Plan steps 2-3; a non-zero exit maps to `canonicalizer-invocation-failed`, an unparseable-but-zero-exit stdout maps to `dependency-output-malformed` (B3) | none — this feature hand-rolls no YAML parser of its own | Internal (same repository); no external package |
| Epic A2 `evaluate-predicate` / `generate-registry-digest` / ADR-0025 discovery | Epic A2 `Spec-Review-Status: Passed`, content-frozen (design.md Cross-Layer Dependencies) | per-`(capability, component)` trigger/`when` evaluation fan-out (API / Contract Plan steps 7-8); `registry_digest --whole` binding (step 6); Registry/schema discovery reused unmodified (Discovery contract) | none — this feature never re-derives the Predicate DSL or the discovery procedure itself | Internal (same repository); no external package |
| Epic A3 `resolve-component-paths` | Epic A3 `Spec-Review-Status: Passed`, content-frozen (design.md Cross-Layer Dependencies) | affected-component resolution + `ownership_digest` (API / Contract Plan step 4), invoked a second and third time for the pre-publication (step 13) and post-publication (transactional bundle contract step 4) TOCTOU rechecks | none — this feature never re-implements any part of Epic A3's own `git diff` basis | Internal (same repository); no external package |
| Epic A4 `facet-manifest.schema.json` / `capability-summary.schema.json` / `context-projection.schema.json` + `validate-facet-manifest`/`validate-capability-summary`/`validate-context-projection` | Epic A4 `Spec-Review-Status: Passed`, content-frozen (design.md Cross-Layer Dependencies) | this feature's Full/Lite-track outputs are assembled against, and self-validated (API / Contract Plan step 12) using, these already-fixed shapes verbatim | none — no `$ref` across separately-versioned `contracts/` files; the shared `evidenceNode` shape is a structural transcription (Data Plan; `contracts/resolver-evidence.schema.json`) | Internal (same repository); no external package |

No new external (npm/pip/etc.) package is introduced by this feature — the
Python scripts are stdlib-only (design.md Global Constraints, INV-011).
See security-spec.md's SBOM and Supply Chain section for the full
statement.

## Testing

Ten new `tests/*.tests.sh`/`.tests.ps1` suite pairs (design.md Test
Strategy: `resolve-project-context-cli`, `resolve-project-context-block`,
`resolve-project-context-match`, `resolve-project-context-lite`,
`resolve-project-context-parity`, `resolve-project-context-discovery`,
`resolver-evidence-schema`, `validate-resolver-evidence`,
`resolve-project-context-metamorphic`, `resolve-project-context-caller-
contract`), registered directly (unprotected) in `tests/run-all.sh`/`.ps1`
(AC-026), with a staged `.github/workflows/test.yml` registration
candidate under `specs/epic-193-a5-capability-resolver/human-copy/`
(design.md Deployment / CI Plan; Test Strategy). No browser/UI test
tooling applies — no UI exists for this feature.

## Open Questions

- None.
