# Acceptance Tests: Bootstrap Interviewer Enhancement

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-006, REQ-007 | TEST-001 | static integration | template validation in `tests/scripts.tests.ps1` | Planned |
| AC-002 | REQ-007 | TEST-002 | static integration | `ux-spec.template.md` assertions | Planned |
| AC-003 | REQ-007 | TEST-003 | static integration | `frontend-spec.template.md` assertions | Planned |
| AC-004 | REQ-007 | TEST-004 | static integration | `infra-spec.template.md` assertions | Planned |
| AC-005 | REQ-007 | TEST-005 | static integration | `security-spec.template.md` assertions | Planned |
| AC-006 | REQ-010 | TEST-006 | static integration | interview question-bank assertions | Planned |
| AC-007 | REQ-008 | TEST-007 | static integration | design template assertions | Planned |
| AC-008 | REQ-009 | TEST-008 | static integration | traceability template assertions | Planned |
| AC-009 | REQ-006, REQ-013 | TEST-009 | static integration | interviewer skill assertions | Planned |
| AC-010 | REQ-011 | TEST-010 | static integration | Claude Design reference assertions | Planned |
| AC-011 | REQ-012, REQ-014 | TEST-011 | regression | existing Bash/PowerShell structure fixtures | Planned |
| AC-012 | REQ-012, REQ-014 | TEST-012 | integration/parity | missing/complete feature fixtures in Bash and PowerShell | Planned |
| AC-013 | REQ-013, REQ-014 | TEST-013 | repository regression | scoped suites and `tests/run-all.sh` | Planned |
| AC-014 | REQ-015 | TEST-014 | repository validation | manifest/catalog/version/changelog assertions | Planned |
| AC-015 | REQ-016 | TEST-015 | review-boundary integration | implementation/task prechecks and manifest tamper fixtures | Planned |
| AC-016 | REQ-017 | TEST-016 | governance regression | Draft rejection and human/signed-sudo approval fixtures | Planned |
| AC-009 | REQ-006, REQ-013 | TEST-017 | workflow edge case | bugfix/refactor unaffected-layer and security-assessment assertions | Planned |
| AC-010 | REQ-011 | TEST-018 | workflow edge case | no-mockup optional-step assertions | Planned |
| AC-011 | REQ-012 | TEST-019 | backward compatibility | legacy spec remains valid in repository-only mode | Planned |

## Behavioral Contracts

| Contract | Input | Expected Result |
|---|---|---|
| Repository preflight compatibility | Existing complete project root, no feature selector | Existing host/advisory/final output; exit 0 |
| Missing layer artifact | Full-profile feature selector with `ux-spec.md` absent | `missing: specs/<feature>/ux-spec.md`; exit 1 |
| Complete full-profile artifact set | Feature selector with all required core and layer files | No feature `missing:` lines; exit 0 |
| Exact feature inventory | Feature selector with each of the nine required files removed in turn | Exactly one matching `missing:` line per removed file; exit 1 |
| Invalid feature slug | Explicit empty, absolute, traversal-like, uppercase, or underscore-containing feature selector | `invalid feature: <value>`; exit 1; no path escape |
| LITE | Interviewer invoked with LITE profile | No layer files generated or required |
| Existing artifact | Layer output path already exists | File content remains unchanged |
| Bugfix/refactor unaffected layer | Interview marks a layer unaffected | Layer records `N/A — no change` with rationale; security impact is still assessed |
| No visual input | Full-profile interview has no mockup | Optional visualization step is skipped without blocking or placeholder input |
| Legacy specification | Repository-only preflight contains a pre-v1.4 spec directory | Existing repository result and exit semantics are unchanged |
| Complete review input | Canonical core and four layer files are present | Implementation/task manifests bind every layer path and SHA-256 |
| Tampered review input | A bound layer file changes or is path-substituted | Deterministic precheck fails before reviewer invocation |
| Layer-owned requirement | Traceability row affects one or more defined layers | Cell contains canonical `<layer>-spec.md#<section>` anchor(s) |
| Cross-layer-only requirement | Traceability row has no UX/frontend/infra/security owner | Cell contains `N/A — cross-layer only: <reason>` |
| Invalid layer traceability | Layer Spec cell is blank, bare `N/A`, malformed, or lacks a reason | Task precheck/review fails |
| Post-review task state | Task review passes | Tasks remain Draft and `implement-task` rejects them |
| Authorized approval | Human edit or active signed `sdd-sudo` selects a Draft task | Selected task becomes Approved and is eligible for `implement-task` |

## Layer Test Contracts

| Layer | Contract |
|---|---|
| UX | Every listed interactive state maps to an acceptance criterion. |
| Frontend | Typed contract examples contain named fields and concrete types. |
| Infrastructure | Availability and p95 latency have numeric targets and AC references. |
| Security | STRIDE is evaluated per trust boundary and data classification covers named entities. |

## Question Bank Contract

For each of the eight categories named by REQ-010, static validation confirms
that the category contains at least one retained Japanese probe and at least
three new English layer-specific probes. The probes are counted independently;
Japanese/English translation pairs are not required.

## UI Integration Checklist

Not applicable. This change adds no product UI entry point.
