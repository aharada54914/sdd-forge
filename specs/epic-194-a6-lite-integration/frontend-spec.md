# Frontend Specification: epic-194-a6-lite-integration

N/A — no change: this feature introduces no browser/client UI and no new
runtime service, and no new plugin (design.md Global Constraints: "No new
plugin — every script/skill this design touches already lives in
`plugins/sdd-lite/` or `plugins/sdd-quality-loop/`"). This document
instead records the script/runtime inventory this design's own edits
actually use, since design.md's Components and API / Contract Plan
sections already own that content and this file restates it in the
layer-file shape the review harness expects.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Contract/catalog data | JSON / JSON Schema | repository-standard | `contracts/capability-registry.schema.json`'s `lite_policy` sub-schema (v1.1 additive extension), `contracts/lite-check-catalog.json` (new), `contracts/lite-upgrade-reason-catalog.json` (`catalog_version` 2, data-only) — design.md Data Plan | no new schema-authoring technology; reuses the exact JSON Schema draft/shape A2's own `lite_policy`/`upgrade_reasons` fields already establish |
| Script edits (existing, extended) | POSIX sh, PowerShell | repository-standard | `check-risk-upgrade.sh`/`.ps1` (REQ-002, human-copy) gain one optional CLI argument only — design.md Global Constraints: "Cross-runtime parity — every script edit this design names keeps its existing `sh`/`ps1` pair structure; this design introduces no `.py`/`.js` master for either file" | byte-identical output when the new argument is omitted (requirements.md AC-007) |
| Gate/skill process edits (existing, extended) | Markdown (skill process definitions) | repository-standard | `lite-gate/SKILL.md` (direct edit) and `lite-spec/SKILL.md` (human-copy) — design.md API / Contract Plan | no new skill-authoring mechanism; extends existing Process/Gate sections in place |
| Registry-sourced check execution (new indirection, bounded) | shell/PowerShell script invocation via `npm run <id>` or `scripts/<id>.{sh,ps1}`, argv-direct | repository-standard | Lite-check command-discovery contract (design.md API / Contract Plan, "Lite-check command-discovery contract") | bounded to two fixed, checked-in-order lookup locations; never an open-ended search (security-spec.md B4) |

design.md's Components table names no `.py` master and no `.js` wrapper
for any file this feature edits — this design's own new artifacts are
data files (JSON) and Markdown process edits, not a new script family
(unlike A2's own digest-primitive scripts, which alone need a `.js`
wrapper for cross-runtime hashing).

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A — no change: no browser UI, no client-side state, no routes, and no
API client of this feature's own. The closest analog — the CLI exit-code/
stdout contract for `check-risk-upgrade` and the `lite-gate` Process
Step 2a/2b outcomes — is fully specified in design.md's API / Contract
Plan, not duplicated here.

## Dependencies

| Dependency | Status | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| Epic A2 Registry schema (`lite_policy`, `upgrade_reasons`), catalog mechanism, `validate-capability-registry` check-suite pattern | shipped 2026-07-23 (`e48c9008`): `contracts/capability-registry.schema.json` is live and R-10 protected, and its `lite_policy` sub-schema is the exact two-key shape this design extends (design.md Cross-Layer Dependencies; investigation.md INV-013 as superseded 2026-08-25, INV-003 re-verified against the live file). This design was authored against A2's own `design.md` text; that text and the shipped file agree on every field this feature depends on | REQ-001's `required_lite_checks` third key and check (j) mirror A2's own check (h) pattern exactly | none — this feature does not re-derive the Registry schema or validator-check pattern itself | Internal (same repository); no external package |
| Epic A4 Capability Summary schema | `Spec-Review-Status: Passed`, content-frozen | REQ-003/REQ-004's `lite-gate` reads `capability-summary.yaml` against this already-fixed shape, validated via A4/A5-owned validator, never reimplemented | none | Internal (same repository); no external package |
| Epic A5 Lite-track Resolver contract (`required_lite_checks`, `full_upgrade_required`) | `Spec-Review-Status: Pending` at this feature's own spec-review time (design.md Risks: "A5 is not yet `Passed`") | REQ-003's field-naming and union-match aggregation grounding (design.md Design Decisions, "Field name `required_lite_checks`") | none — this feature's own field-naming choice is provisional on A5's text, not an independent invention | Internal (same repository); no external package |
| ADR-0022 (Combination Matrix, forced-upgrade rule, Gate Stage Model) and the existing, live `sdd-lite` plugin's own risk-upgrade gate and quality gate | Accepted / live | this design's entire scope is combinatorial — connecting these already-fixed contracts, never re-deciding them (design.md Technical Summary) | none | Internal (same repository); no external package |

No new external (npm/pip/etc.) package is introduced by this feature —
every edit is either a JSON/JSON-Schema data file or an additive
extension of existing shell/PowerShell/Markdown artifacts (design.md
Global Constraints). See security-spec.md's SBOM and Supply Chain
section for the full statement.

## Testing

No `tests/*.tests.sh`/`.tests.ps1` file is authored by this package
(design.md Test Strategy: "no `tests/*.tests.sh`/`.tests.ps1` file is
authored by this package; a future implementation task authors them").
Seventeen design-phase target fixtures are named in design.md's Test
Strategy, elaborating requirements.md REQ-006's twelve-item lettered
inventory. No browser/UI test tooling applies — no UI exists for this
feature.

## Open Questions

- None.
