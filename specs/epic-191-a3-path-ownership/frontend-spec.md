# Frontend Specification: epic-191-a3-path-ownership

N/A — no change: this feature introduces no browser/client UI and no new
runtime service (design.md Technical Summary; Feature Type header line).
This document instead records the script/runtime inventory the two new
product scripts and their wrapper pairs actually use, since design.md's
Components and Architecture sections already own that content and this file
restates it in the layer-file shape the review harness expects.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Script runtime (master) | Python | repository-standard (not independently pinned by this spec) | Python master implements the actual matching/classification/Gate logic for both `resolve-component-paths.py` and `check-component-coverage.py` (design.md Components) | `.py` is always the canonical master; `.sh`/`.ps1` are thin wrappers invoking it (design.md Components table) |
| Script runtime (wrappers) | POSIX sh, PowerShell | repository-standard | Thin wrappers invoking the Python master (design.md Components: `resolve-component-paths.sh`/`.ps1`, `check-component-coverage.sh`/`.ps1`, "thin wrappers invoking the Python master (INV-008 convention)") | one `.sh`/`.ps1` wrapper pair per `.py` master, same directory, same basename |

Unlike epic-190-a2 (which ships an additional `.js` wrapper for its digest
generator because that generator calls Epic A1's canonicalizer's own `.js`
wrapper), this feature's design.md Components table lists no `.js` wrapper
anywhere — `resolve-component-paths` and `check-component-coverage` each
ship only a `.py` master plus `.sh`/`.ps1` wrappers. `resolve-component-paths.py`
(T-003) also calls Epic A1's canonicalizer to emit `ownership_digest`, but
design.md does not describe this as requiring a `.js` wrapper of its own;
no `.js` wrapper is introduced by this feature.

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A — no change: no browser UI, no client-side state, no routes, and no API
client of this feature's own. The closest analog — `resolve-component-paths`
and `check-component-coverage`'s own CLI invocation shapes — is fully
specified in design.md's API / Contract Plan, not duplicated here.

## Dependencies

| Dependency | Version | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| Epic A1 canonicalizer (imported, not vendored or reimplemented) | pending Epic A1 shipping this utility (requirements.md Dependencies) | canonicalization step for `ownership_digest` (REQ-005; design.md Technical Summary: "depends on Epic A1's canonicalizer"; Data Plan: "via Epic A1's canonicalizer — not reimplemented; BLOCKED until that utility exists") | none — REQ-005's task records a documented blocker if the canonicalizer does not yet exist, rather than reimplementing canonicalization (acceptance-tests.md notes) | Internal (same repository); no external package |

No new external (npm/pip/etc.) package is introduced by this feature — see
security-spec.md's SBOM and Supply Chain section for the full statement.

## Testing

Five new `tests/*.tests.sh`/`.tests.ps1` suite pairs
(`component-path-resolver`, `component-path-diff-basis`,
`check-component-coverage`, `ownership-digest`,
`component-path-ownership-parity` — design.md Test Strategy), registered
directly (unprotected) in `tests/run-all.sh`/`.ps1` and staged via human-copy
into `.github/workflows/test.yml` (design.md Deployment / CI Plan, INV-010).
No browser/UI test tooling applies — no UI exists for this feature.

## Open Questions

- None.
