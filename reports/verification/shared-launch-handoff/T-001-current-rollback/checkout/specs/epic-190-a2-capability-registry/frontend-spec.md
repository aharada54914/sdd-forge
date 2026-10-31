# Frontend Specification: epic-190-a2-capability-registry

N/A — no change: this Epic introduces no browser/client UI and no new
runtime service (design.md Technical Summary). This document instead
records the script/runtime inventory the four new scripts and their wrapper
pairs actually use, since design.md's Components and Architecture sections
already own that content and this file restates it in the layer-file shape
the review harness expects.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Script runtime (master) | Python | repository-standard (not independently pinned by this spec) | Python master implements the actual operator/evaluation-semantics/validation logic; matches the existing `plugins/sdd-quality-loop/scripts/` convention (Components, investigation.md INV-014) | `.py` is always the canonical `implementation_ref` target (API / Contract Plan, Gate implementation identity) |
| Script runtime (wrappers) | POSIX sh, PowerShell | repository-standard | Thin argument-forwarding wrappers only — no logic duplication (the `sdd-hook-guard.sh` pattern, INV-014, Components) | one wrapper pair (`.sh`/`.ps1`) per `.py` master, same directory, same basename (Gate implementation identity, wrapper grouping) |
| Script runtime (digest generator only) | Node.js (`.js` wrapper) | repository-standard, mirrors Epic A1 canonicalizer's own wrapper set | `generate-registry-digest` calls Epic A1's canonicalizer, which itself ships `.sh`/`.ps1`/`.js` wrappers (Components, decision v2 §18.3) — the digest generator's own wrapper set mirrors its dependency's, not an independent choice | `.js` wrapper is unique to `generate-registry-digest`; the other three scripts ship only `.sh`/`.ps1` (Components) |

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A — no change: no browser UI, no client-side state, no routes, and no API
client of this Epic's own. The closest analog — the Registry
validator/evaluator/digest/projection generator CLI contracts — is fully
specified in design.md's API / Contract Plan, not here.

## Dependencies

| Dependency | Version | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| Epic A1 canonicalizer (imported module/CLI, not vendored or reimplemented) | pending Epic A1's finalized path, version, and I/O contract (requirements.md Dependencies) | JCS canonicalization step for `registry_digest` (REQ-004) | An inline, non-reusable RFC 8785 implementation was considered and rejected; if Epic A1 instead ships as an inline, non-reusable script, REQ-004's task needs a small adapter, not a redesign (design.md Assumptions) | Internal (same repository); no external package |

No new external (npm/pip/etc.) package is introduced by this Epic — see
security-spec.md's SBOM and Supply Chain section for the full statement.

## Testing

`tests/*.tests.sh`/`.tests.ps1` pairs (Test Strategy items 1-8, design.md),
registered directly (unprotected) in `tests/run-all.sh`/`.ps1` and staged via
human-copy for `.github/workflows/test.yml` (Protected-File Statement). No
browser/UI test tooling applies — no UI exists for this Epic.

## Open Questions

- None.
