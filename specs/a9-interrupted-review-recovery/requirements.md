# Requirements: a9-interrupted-review-recovery

Spec-Review-Status: Passed
Feature Type: bugfix
Resolved Track: full (C1 COMPATIBILITY_FALLBACK)
Source: reports/recovery-candidates/a9-interrupted-recovery-contract-plan.md; bounded user instruction of 2026-09-27

## Overview

Provide one explicit spec-stage recovery entry for the observed A-interrupted-before-B launch. This is preparation, not authorization evidence, a verdict, or implementation. The approved product decisions are the narrow route, unchanged normal reset, immutable history, no global approval-sidecar change, no UI/mockup/dependency, and an eventual A9 attempt 4 with at most three rounds.

## Target Users / User Stories

The review orchestrator needs to start a fresh attempt after a human authorizes recovery, without interpreting interrupted diagnostic output as a completed review. The human owns the authorization evidence; independent reviewers own review findings.

## Problems and Existing Behavior

- Reset selects the latest previous round and requires a validated PASS or BLOCKED contract (`plugins/sdd-review-loop/scripts/spec-review-precheck.sh:388-397`; PowerShell counterpart `:538-555`).
- A9 attempt 3 round 2 declares NEEDS_WORK (`reports/spec-review/epic-197-a9-dogfood/attempt-3/round-2/spec-review-contract.json:71`). Round 3 A raw declares BLOCKED (`reports/spec-review/epic-197-a9-dogfood/attempt-3/round-3/reviewer-a.json:29`) while its host receipt records `review_execution_started: false` (`reviewer-a-host-receipt.json:39` in that directory). These are interruption diagnostics, not an integrated terminal contract.
- Interrupted output/reservation must be preserved; a saved BLOCKED is not completed-review proof, and the boundary supplies no automatic recovery (`plugins/sdd-review-loop/references/review-context-boundary.md:260-269`).
- Existing persisted-identity verification checks the full ledger chain, sequence and bindings without requiring the historical record to remain the tip (`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:518-573`).
- Global approval validation admits only project-context/provider-bindings schemas (`plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py:152-163`); do not expand it.

## Goals / Requirements

| ID | Requirement | Risk / Rationale | Canonical layer |
|---|---|---|---|
| REQ-001 | Distinct `--recover-interrupted=<record>` / `-RecoverInterrupted <record>`; exclusive with reset; only source attempt N latest interrupted round to N+1 round 1. | high: gate entry | infra-spec.md#deployment-topology |
| REQ-002 | Admit only Pending, A reserved and interrupted before B, preceded by an own-stage validated NEEDS_WORK round. Reject any other shape. | high: evidence validity | security-spec.md#trust-boundaries |
| REQ-003 | Validate exact closed recovery-record fields, human evidence path/hash, live input/calibration pins, complete old inventory and persisted A identity using existing verification. | high: authorization and provenance | security-spec.md#authorization |
| REQ-004 | Use real contained paths and existing single-writer destination semantics; success creates only new precheck and blank report, hash-bound recovery provenance, no reservation/status/history edits. | high: immutable state | infra-spec.md#data-residency-and-retention |
| REQ-005 | Keep ordinary reset and downstream PASS semantics unchanged; Bash/PowerShell identical decisions and negative coverage; no new dependency/global-sidecar change. | high: regression | infra-spec.md#cicd-sequence |

## Acceptance Criteria

| ID | Requirement | Observable assertion |
|---|---|---|
| AC-001 | REQ-001 | Explicit recovery accepts only N+1 round 1; missing flag, reset combination, unknown/case-variant options reject. |
| AC-002 | REQ-002 | Actual source must be latest in immediate prior attempt, Pending, A interrupted before B, with preceding validated NEEDS_WORK; each alternative rejects. |
| AC-003 | REQ-003 | Every record field/type/hash, authorization binding, input pin, artifact and identity binding is independently checked; invalid or ambiguous evidence rejects. Later valid ledger records are allowed. |
| AC-004 | REQ-004 | No symlink/escape/replay/concurrent write; validation rejection before publication creates no target files or state changes; interrupted publication fails nonzero, preserves any partial target as unusable failure evidence, and requires separate authorized remediation (never automatic reuse/reset/PASS); valid recovery preserves all old bytes and creates no reservation or verdict. |
| AC-005 | REQ-005 | Additive `recovery` provenance stays inside spec-review-precheck/v1 and never grants PASS; ordinary reset regression and downstream consumers continue to validate normally. Both runtime suites execute or are reported unverified. |

The concrete expanded branch matrix is acceptance-tests.md; each enumerated mutation has its own TEST-ID. Test rows are planned, not results.

## Non-goals

Other interruption shapes; automatic recovery; changing normal reset; adopting an A-only verdict; modifying A9 frozen inputs, old rounds, ledger, global sidecars, hook settings, tasks/approvals; UI, mockups, new dependencies; implementation or review launch during this preparation.

## Roles and Permissions / Main Workflows

Human supplies explicit bounded authorization artifact. Orchestrator invokes the separate recovery option. Pure validation precedes the existing lock; recheck mutable pins, latest source and destination under lock before publication. Validation rejection before publication is nonzero with no target evidence. Interrupted publication is nonzero with a quarantined partial target: no success, automatic erase, reuse, reset or PASS; separate authorized remediation is required; success emits fresh Pending precheck and blank report. Normal launch later allocates fresh A and B identities. A9 target is attempt 4 round 1; later rounds remain capped at 3, not a cap on the new repair feature's independent reviews.

## Edge Cases / Security Boundaries

Untrusted record -> trusted precheck: closed types, scoped authorization and hash checks. Repository evidence -> new destination: existing identity chain validation, contained nonsymlink paths, lock and revalidation. Full STRIDE/negative mapping: security-spec.md. Classification: internal provenance; no secrets or PII introduced; no regulatory change.

## Assumptions

At review time reverify latest A9 round, absence of B/integrated evidence and target, Pending, source pins, guard inventory, existing verifier semantics and consumers against current tree; these shared facts are not permanent. The supplied plan's issue-61 closure assertion is not independently verified here; this feature never uses manual fallback regardless. Existing runtime prerequisites remain required and missing tools fail closed.

## Open Questions

No unresolved product choices. Execution input AUTH-001: human must supply an authentic explicit authorization artifact identifying A9 source 3/3 -> target 4/1, maximum three rounds and approved recovery-record digest; path/hash are required, not invented here. Owner: human/orchestrator. Resolution: record the existing exact scoped approval and actual human application before real recovery validation. The orchestrator must match the actual human approval and human report of applying the exact bounded artifact in the user channel, retaining the original user-message reference and approved content/binding digest. Only the human's own message is an origin source; an agent summary, self-claim, file alone, or human-copy transaction log alone is insufficient. This is the existing human-outside-agent boundary (plugins/sdd-quality-loop/references/deterministic-check-policy.md:124-132), not cryptographic human authentication. Before invoking recovery the orchestrator establishes that origin prerequisite; the validator checks the artifact's eight contents, raw hash and recovery binding only. Unknown or mismatched origin blocks launch. No new approval is requested; AUTH-001 records the existing approval and actual human application. Conversation prose is not a signature. Missing evidence blocks real recovery, not drafting.

## Risks

Hash binding is integrity, not proof of human authorship. Refuse unknown authorization provenance. Races require lock/revalidation. Compatibility is not proven until the scoped suites run in both runtimes after implementation and required gates pass.

## Normative admissible record and authorization (REQ-003 / AC-003)

The following finite definitions are copied from the separate proposed data contract into this authorized Phase 1 input; reviewers need no external contract input. They govern TEST-044, TEST-050-057 and authorization TEST-035-043/TEST-050-A01-A08.


## Closed Record

UTF-8 JSON object; duplicate decoded members reject at all depths before ordinary JSON parsing. Exact required keys only. No nullable/optional record fields in this v1 observed route. Every integer is a JSON integer (not boolean, string or fractional number). All comparisons case-sensitive.

| Field | Exact type / constraint |
|---|---|
| schema | string exactly spec-review-interrupted-recovery/v1 |
| feature | string matching CLI feature; lowercase slug `[a-z0-9][a-z0-9-]*` |
| source | object with exactly attempt, round; positive integers; source round 2 or 3 with immediately preceding complete NEEDS_WORK |
| target | object with exactly attempt, round; attempt source+1, round exactly 1 |
| authorization | reference object |
| previous_contract | reference object to source attempt / source round-1 / spec-review-contract.json |
| interrupted_precheck | reference object to source precheck-result.json |
| pinned_inputs | exactly four reference objects, sorted unique paths: current requirements.md, acceptance-tests.md, investigation.md and spec-review-calibration.md |
| interrupted_artifacts | exactly six reference objects, sorted unique paths: source precheck-result.json, reviewer-a.json, reviewer-a-reservation.txt, reviewer-a-host-receipt.json, spec-review-report.md and external reviewer-a invocation manifest |
| reviewer_a | object with exactly invocation, sequence, stage, role, run_id, host_session_id, record_sha256; invocation is reference object, sequence positive integer, stage spec, role spec-reviewer-a, nonempty run/session strings, record_sha256 lowercase SHA256 |

Reference object has exactly path and sha256: path is nonempty repository-relative slash-separated string with no absolute prefix, dot/dotdot/empty segments, backslashes, tab, newline, NUL or other control characters; sha256 matches `[0-9a-f]{64}`. Validate every file and ancestor as real nonsymlink contained paths (lexists catches dangling symlinks). A reference must name its canonical role-specific path, not an arbitrary same-content file. The reviewer_a.invocation duplicates the inventory invocation reference exactly. All repeated pins agree, not merely independently hash.

No verdict, copied ledger-tip hash, approval status or reservation-writing field exists. Unknown fields reject at every object level. Legacy invocation manifests retain their own existing schema and historical path-normalization rules; recovery references themselves are relative.

## Authorization Input (AUTH-001)

Separate human-origin UTF-8 artifact, with exactly one bare line for each binding:

Feature: FEATURE
Source Attempt: N
Source Round: R
Target Attempt: N+1
Target Round: 1
Maximum Rounds: 3
Decision: Authorize interrupted A-before-B recovery
Recovery Binding SHA256: DIGEST

Additional prose may describe capture, without duplicating any required binding. Before launch, the orchestrator must match the original human approval and the human's actual application report in the user channel to the exact artifact and approved content/binding digest, retaining the original user-message references and digest. Agent self-claims, summaries, artifacts alone and human-copy transaction logs alone are not accepted origin evidence. Unknown or mismatched origin blocks launch. The validator checks the eight binding contents, raw artifact hash and recovery binding; it does not authenticate human authorship. No cryptographic signature, new approval sidecar or new product approval is introduced. AUTH-001 records existing scoped approval and actual human application; missing execution evidence blocks real recovery, not drafting.

To avoid a circular hash, Recovery Binding SHA256 is SHA256 of canonical JSON of the recovery record with the top-level authorization member removed: recursively sort object keys, retain array order, UTF-8, no terminal newline, separators comma/colon without spaces, ensure_ascii true. Numbers are contract-constrained integers. All remaining fields and pins are bound. The complete authorization artifact's raw SHA256 then goes in authorization.sha256. The complete recovery record's raw SHA256 is persisted in the new precheck. Any binding mismatch rejects. AUTH-001 captures the already-approved scope; it does not ask for a new product decision.

## Semantic Validation

The eight authorization values must equal the recovery record feature/source/target, Maximum Rounds exactly 3, Decision exactly `Authorize interrupted A-before-B recovery`, and a lowercase 64-hex Recovery Binding SHA256. Each required line occurs exactly once; additional prose must not duplicate a binding. Recovery Binding SHA256 hashes the record with only top-level authorization removed, recursively sorted object keys, retained array order, UTF-8 ensure_ascii JSON, comma/colon separators without spaces and no terminal newline; all numeric fields are integers. The authorization artifact raw hash is authorization.sha256; the complete recovery record raw hash is saved recovery.record_sha256. The optional legacy/new-route-mandatory precheck recovery object has exactly record_path (same contained path rules) and record_sha256 (same lowercase digest rules). It supplies no verdict or approval.
