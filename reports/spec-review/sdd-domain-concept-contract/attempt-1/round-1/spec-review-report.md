# Specification Review Report: sdd-domain-concept-contract

- Attempt: 1
- Round: 1
- Input hashes: requirements `007fb0d261ecebbb6eed0f03bcf97358ffa1efd0ea1b5278e43f11a3bcf276bd`, acceptance tests `47eb6d847d53355f1210619809db75900b14e45c18d5b7e959a8a6777759fb0c`
- Reviewer A: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-a-a1r1-seq0754`, host session `SESS-spec-spec-reviewer-a-sdd-domain-concept-contract-a1r1-0754`
- Reviewer B: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-b-a1r1-seq0755`, host session `SESS-spec-spec-reviewer-b-sdd-domain-concept-contract-a1r1-0755`
- Verdict: `NEEDS_WORK`
- Warning count: 0

First round of the first attempt for the Phase 0 spec of the Concept Design
Layer (issue #290). `Spec-Review-Status` remains `Pending`.

## Findings

1. Major — `EDGE-CASE-COVERAGE` (reviewer B): requirements.md's Edge Cases
   section asserts two validator-observable behaviors that have no entry in
   acceptance-tests.md's AC-001..AC-015 / TEST-001..TEST-015 table:
   (1) `concepts` が空配列は v2 では invalid（minItems 1） — requirements.md
   line 176 — has no AC/TEST exercising an empty `concepts[]` fixture; AC-014
   covers only field-level omissions (`essence` 欠落 / `evidence` 空配列 /
   `responsibilities` 空配列), not the top-level array itself.
   (2) 契約ファイルが 10MB を超える等の異常入力に対する fail-closed 非 0 終了 —
   requirements.md line 185, corresponding to validator duty (a)
   「JSON として可読」in REQ-004 — has no AC/TEST either.
   Downstream failure mode: a task author encoding acceptance tests from this
   document has no acceptance criterion for either behavior, so a validator
   that accepts an empty `concepts[]`, or that crashes or best-effort-parses
   instead of exiting non-zero on oversized or malformed input, would ship with
   no test catching the regression. The gap is in this gate's own artifact
   (acceptance-tests.md), not a later-stage concern.

## Non-blocking observations

- Reviewer A noted under `REQ-TESTABILITY` that `name` (PascalCase) and
  `context` (kebab-case) in REQ-002 lack an explicit regex, unlike `id`
  (`^CONCEPT-[A-Z][A-Z0-9-]*$`). Reviewer B independently reached the same
  observation under `AMBIGUITY` and judged that REQ-006's fixture-driven
  drift-lock between schema file and validator forces convergence. Both graded
  it non-blocking; it is recorded here for the spec author's discretion and is
  not part of the NEEDS_WORK verdict.

## Skipped checks

- `DOMAIN-CONFORMANCE` (both reviewers): sdd-forge has no `domain/` directory
  at the repository root (INV-009), so there is no `domain/context-map.md` with
  `Domain-Model-Status: Approved` and no schema-valid `domain/domain-contract.json`
  to check against.
- `APPROVAL-BOUNDARY` (reviewer B): this Phase 0 feature introduces no new
  human-approval or irreversible-change boundary; the existing `meta.status`
  Approved write-control is unchanged and reviewer/workflow changes are
  explicitly Phase 3 non-goals.

## Check results

| Check | Reviewer A | Reviewer B |
|---|---|---|
| REQ-TESTABILITY | PASS (Critical) | — |
| GOAL-AC-TRACE | PASS (Major) | — |
| AC-OBSERVABLE | PASS (Major) | — |
| SCOPE-BOUNDARY | PASS (Major) | — |
| CONSTRAINTS-EXPLICIT | PASS (Major) | — |
| RISK-VALIDATION-SURFACE | PASS (Major) | — |
| AMBIGUITY | — | PASS (Major) |
| CONTRADICTION | — | PASS (Critical) |
| EDGE-CASE-COVERAGE | — | **FAIL (Major)** |
| ASSUMPTIONS-RESOLVABLE | — | PASS (Major) |
| APPROVAL-BOUNDARY | — | SKIP (Critical) |
| DOWNSTREAM-READINESS | — | PASS (Major) |
| DOMAIN-CONFORMANCE | SKIP (Major) | SKIP (Major) |

Reviewer A: 6 PASS, 0 FAIL, 1 SKIP. Reviewer B: 4 PASS, 1 FAIL, 2 SKIP.

## Next action

Amend `specs/sdd-domain-concept-contract/acceptance-tests.md` to add acceptance
criteria for the two Edge Cases behaviors above, then re-invoke the gate for
attempt 1 round 2 with `--edit-summary` describing the amendment. The finding
must not be waived.
