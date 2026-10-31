# Specification Review Report: sdd-domain-concept-contract

- Attempt: 3
- Round: 1
- Input hashes: requirements `2c5ef1adf119736594b839119f5f13e8c8715542470c9d095e9f41b7d34fa397`, acceptance tests `a7acb13de336c1ec7ac67d1c6449f4621c76f024296bdc91a197ab2d5e3ef75f`
- Reviewer A: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-a-a3r1-seq0766`, host session `SESS-spec-spec-reviewer-a-sdd-domain-concept-contract-a3r1-0766`
- Reviewer B: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-b-a3r1-seq0767`, host session `SESS-spec-spec-reviewer-b-sdd-domain-concept-contract-a3r1-0767`
- Verdict: `NEEDS_WORK`
- Warning count: 0
- Finding counts: Critical 0, Major 2, Minor 0

Attempt 3 was opened with `--reset` after attempt 2 terminated BLOCKED. Before
this round: REQ-005 gained fixture requirement (e) for the term → concept link
plus an explicit positive-coverage rule; acceptance-tests.md gained AC-025
(the positive link criterion) and a new **Positive-capability matrix** — one
row per declared Goal capability, citing the positive AC that proves the
capability is accepted when exercised correctly. The two non-blocking nits
reviewer B recorded in attempt 2 were also fixed. `Spec-Review-Status` remains
`Pending`.

## Attempt-2 finding: resolved

The `term.concept_id` positive-case gap is closed by AC-025, which requires a
fixture where a term references an existing concept (exit 0), a structural
assertion that the v2 schema declares the field as optional with the concept-id
pattern, and a check that the value survives validation. Neither reviewer
raises it.

## Finding

Both reviewers independently identified the same defect through their
respective checks — and it is a defect in the Positive-capability matrix added
this attempt.

1. Major — `GOAL-AC-TRACE` (reviewer A) and `EDGE-CASE-COVERAGE` (reviewer B):
   the matrix row 「G1: concept の全 required フィールドと optional
   フィールドが表現できる」 cites AC-003 and AC-004, but its own evidence
   column names only `must_not_own`, `distinguished_from`, and
   `responsibilities`. **The claim is broader than the evidence it cites.**

   `concepts[].stakeholder_perspectives[]` is a declared optional field
   (`{actor, concern}[]、両者 required・minLength 1`), and no positive AC
   anywhere populates it. Every mention of the field is negative or
   absence-only: AC-020 (nested required missing, plus the optional-absent
   canary), AC-023(6)(7) (minLength), AC-024(20)-(23) (type mismatch).
   Reviewer B further notes AC-020's text explicitly records that AC-004's
   positive fixture *lacks* the array, so the optional-and-absent state is
   covered while optional-and-present is not.

   Downstream failure mode: a validator that incorrectly rejects a well-formed,
   populated `stakeholder_perspectives` — a stuck-shut defect — would leave
   every fixture green. The spec canaries against exactly this elsewhere
   (AC-018's pattern boundary positives, AC-020's optional-absent case), so the
   omission is inconsistent with its own convention. It also violates the
   positive-coverage rule this attempt added to REQ-005.

   Orchestrator verification: confirmed. `stakeholder` occurs five times in
   acceptance-tests.md — AC-020, AC-023, AC-024, and two rows of the
   negative-path matrix. No positive AC mentions it.

## Reviewer B's independent corroboration

Reviewer B re-derived the negative fixture tally from the AC table
(8 single-fixture ACs + 65 across the multi-fixture ACs = 73) and recounted
AC-024's 29 sub-items; both match the stated values.

## Check results

| Check | Reviewer A | Reviewer B |
|---|---|---|
| REQ-TESTABILITY | PASS (Critical) | — |
| GOAL-AC-TRACE | **FAIL (Major)** | — |
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

Reviewer A: 5 PASS, 1 FAIL, 1 SKIP. Reviewer B: 4 PASS, 1 FAIL, 2 SKIP.

## Pattern worth recording

Each new coverage device introduced to close a class of gaps has itself
carried the same class of defect on introduction:

| Device introduced | Defect it shipped with |
|---|---|
| Negative-path coverage matrix (attempt 2 round 1) | three cells claimed covered via a shared-code-path assumption, with no fixture |
| Positive-capability matrix (attempt 3 round 1) | one row's claimed capability broader than the evidence cited |

Both are the same error: a matrix cell asserting coverage the AC table does not
supply. The negative matrix already carries a rule forbidding
internals-based justification; the positive matrix needs the analogous rule —
a row's capability statement must not exceed the union of what its cited ACs
actually exercise, enumerated field by field.

## Next action

Amend `acceptance-tests.md` for attempt 3 round 2:

1. Populate `stakeholder_perspectives` with valid data in one positive fixture
   — AC-003 (Purchase/Fulfillment) is the natural host, keeping AC-004 as the
   optional-absent canary — and state it in that AC's test target.
2. Restate the G1 optional-field row so its capability statement enumerates
   exactly the optional fields its cited ACs exercise.
3. Add a rule to the Positive-capability matrix legend: a row's capability
   statement must not claim more than the union of what its cited ACs
   demonstrate, and every declared optional field needs a positive fixture in
   the populated state, not only the absent state.

No finding may be waived.
