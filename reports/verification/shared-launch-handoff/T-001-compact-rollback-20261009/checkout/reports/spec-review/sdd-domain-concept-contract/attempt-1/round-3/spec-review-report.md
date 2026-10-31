# Specification Review Report: sdd-domain-concept-contract

- Attempt: 1
- Round: 3 (terminal round of the attempt)
- Input hashes: requirements `7358082e0477468d77973eb096f963917a410bbfcc7138c7fb8392b2338b5243`, acceptance tests `be3a0757a281de6d1f37d63584593174e1cf8b7e768e26a808d7df329538006d`
- Reviewer A: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-a-a1r3-seq0758`, host session `SESS-spec-spec-reviewer-a-sdd-domain-concept-contract-a1r3-0758`
- Reviewer B: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-b-a1r3-seq0759`, host session `SESS-spec-spec-reviewer-b-sdd-domain-concept-contract-a1r3-0759`
- Verdict: `BLOCKED`
- Warning count: 0
- Finding counts: Critical 0, Major 1, Minor 0

Round 3 amended both `requirements.md` (first change to that file in this
attempt) and `acceptance-tests.md`. `Spec-Review-Status` remains `Pending`.

## Round-2 findings: all five resolved

Both reviewers confirm the round-2 findings are closed:

- `CONTRADICTION` and `APPROVAL-BOUNDARY` (both Critical): reviewer B now
  passes both. Roles and Permissions states plainly that no mechanical
  enforcement of `meta.status` Approved writes exists, matching INV-008, and
  the new Non-goals bullet reinforces it. Reviewer A cites the same text under
  `CONSTRAINTS-EXPLICIT`.
- `AMBIGUITY` (Major): reviewer B passes. The `name`
  (`^[A-Z][A-Za-z0-9]*$`) and `context` (`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`)
  patterns are now stated in REQ-002 and the Field Definitions table.
- `EDGE-CASE-COVERAGE` (Major, round-2 form): the pattern-violation gap is
  closed by AC-018.
- `DOWNSTREAM-READINESS` (Major): reviewer B now passes it.

## Surviving finding

1. Major — `EDGE-CASE-COVERAGE` (reviewer B), a new instance of the same check
   against a different gap: REQ-002 and the Field Definitions table declare
   seven required concept fields — `id`, `name`, `context`, `definition`,
   `essence`, `responsibilities`, `evidence`. AC-014 is the only required-field
   enforcement criterion and exercises three of them (`essence` 欠落 /
   `evidence` 空配列 / `responsibilities` 空配列). AC-018 exercises `id`,
   `name`, and `context` only for pattern violation while the key is present,
   never for outright key absence. `definition` has no negative fixture
   anywhere. Downstream failure mode: a validator that silently accepts a
   concept missing `definition`, or missing `id`/`name`/`context` keys
   entirely, would pass every fixture in REQ-005/REQ-006 — which undercuts
   Risk R2's claim that the REQ-006 fixtures drift-lock the schema's required
   declarations against validator behavior.

   Orchestrator verification: confirmed. `definition` occurs zero times in
   acceptance-tests.md. AC-014's target text names exactly `essence`,
   `evidence`, and `responsibilities`.

## Terminal-round outcome

Per the state-transition rules, a round-3 result carrying any Major or
Critical produces `BLOCKED`; only a Minor-only result would have produced a
PASS with `warningCount > 0`. One Major survived, so attempt 1 is BLOCKED. The
finding was not waived and the status field was not changed.

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
| APPROVAL-BOUNDARY | — | PASS (Critical) |
| DOWNSTREAM-READINESS | — | PASS (Major) |
| DOMAIN-CONFORMANCE | SKIP (Major) | SKIP (Major) |

Reviewer A: 6 PASS, 0 FAIL, 1 SKIP. Reviewer B: 5 PASS, 1 FAIL, 1 SKIP.

## Attempt-level observation

Every round of this attempt closed the prior round's findings and surfaced a
new true gap in the same area — negative-path coverage of the AC table:

| Round | Surviving gap |
|---|---|
| 1 | empty `concepts[]`, oversized/malformed input |
| 2 | pattern violations for `id`/`name`/`context` (plus the governance contradiction) |
| 3 | required-key absence for `definition` and for `id`/`name`/`context` |

Each was verified as factually correct by the orchestrator. The pattern
indicates the acceptance-test table was built by enumerating REQ-004's check
list rather than by systematically crossing every declared required field and
every validator duty against the AC rows. Attempt 2 should begin with that
systematic cross-product audit — required fields x {absence, empty, pattern
violation} and validator duties (a)-(i) x {negative fixture present?} — rather
than with another incremental patch.

## Next action

Attempt 1 is terminal. Re-invoke the gate with `--reset` to open attempt 2
round 1 after amending acceptance-tests.md. Prior evidence is preserved and
`Spec-Review-Status` stays `Pending`. No finding may be waived.
