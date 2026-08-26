# Specification Review Report: sdd-domain-concept-contract

- Attempt: 4
- Round: 1
- Input hashes: requirements `71463046b4058126cd33449eba371d1a6c2ce91386652b3737e2393715ddd4c0`, acceptance tests `985899644b99be188e53489b35dd17034f9eb4a9cc646da30cc3ae70e54a49da`
- Reviewer A: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-a-a4r1-seq0772`, host session `SESS-spec-spec-reviewer-a-sdd-domain-concept-contract-a4r1-0772`
- Reviewer B: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-b-a4r1-seq0773`, host session `SESS-spec-spec-reviewer-b-sdd-domain-concept-contract-a4r1-0773`
- Verdict: `NEEDS_WORK`
- Warning count: 0
- Finding counts: Critical 0, Major 2, Minor 0

Attempt 4 was opened with `--reset` after attempt 3 terminated BLOCKED. Before
this round: REQ-005 gained mandate (f) (all-optional-absent positive fixture);
AC-004 was restored to REQ-005(b)'s verbatim content (Book.must_not_own
populated with display position); AC-026 was added to realize REQ-005(f); the
matrix rows and cross-references were repointed accordingly. The orchestrator
ran a bidirectional mechanical check before finalizing (REQ-005 mandates vs
mapped ACs; matrix rows vs cited AC text; 55 negative-matrix cell citations)
and all items passed. `Spec-Review-Status` remains `Pending`.

## Attempt-3 finding: resolved

Both reviewers confirm the REQ-005(b)/AC-004 contradiction is closed. Reviewer
B verified all six REQ-005 (a)-(f) mandates upstream against their mapped ACs
and passes `CONTRADICTION`; reviewer A passes `GOAL-AC-TRACE` with the same
upstream verification and an independent recomputation of the 73-fixture tally.

## Findings

Both reviewers independently identified the same defect through their
respective checks (`AC-OBSERVABLE` for A, `AMBIGUITY` for B): the boundary
positive values `APIOrder` / `order-taking-2` have no positive-AC owner.

1. Major — the Positive-capability matrix row 「G3: validator が正当な契約を
   誤検知しない」 cites 「AC-018 の境界正例」, but AC-018's Test Type is
   `negative fixture (pattern 違反)` — a negative AC cited in the positive
   column, which the matrix's own legend forbids （「負例 AC はここでは根拠に
   ならない」）. AC-018's text delegates the acceptance proof to 「AC-003 の
   正例 fixture 系」, yet AC-003's Test Target never names `APIOrder` or
   `order-taking-2`, so nothing obligates the fixture to carry them; and the
   Notes section attributes the same fixtures to 「TEST-018 の境界正例」 — a
   location contradiction (TEST-003 vs TEST-018). A task author has no single
   authoritative instruction for where the boundary positives live.

   Orchestrator verification: confirmed all four elements (AC-018's negative
   Test Type; its delegation to AC-003; the Notes attribution to TEST-018;
   zero occurrences of `APIOrder` in AC-003's row).

   This defect predates this attempt — the citation has been in the G3 row
   since the matrix was introduced in attempt 3 round 1 — but earlier rounds'
   reviewers did not surface it. The orchestrator's bidirectional check missed
   it because it verified name presence in cited AC text without checking the
   cited AC's polarity (positive vs negative): `APIOrder` does appear in
   AC-018's text, just not as content AC-018 itself proves.

## Check results

| Check | Reviewer A | Reviewer B |
|---|---|---|
| REQ-TESTABILITY | PASS (Critical) | — |
| GOAL-AC-TRACE | PASS (Major) | — |
| AC-OBSERVABLE | **FAIL (Major)** | — |
| SCOPE-BOUNDARY | PASS (Major) | — |
| CONSTRAINTS-EXPLICIT | PASS (Major) | — |
| RISK-VALIDATION-SURFACE | PASS (Major) | — |
| AMBIGUITY | — | **FAIL (Major)** |
| CONTRADICTION | — | PASS (Critical) |
| EDGE-CASE-COVERAGE | — | PASS (Major) |
| ASSUMPTIONS-RESOLVABLE | — | PASS (Major) |
| APPROVAL-BOUNDARY | — | SKIP (Critical) |
| DOWNSTREAM-READINESS | — | PASS (Major) |
| DOMAIN-CONFORMANCE | SKIP (Major) | SKIP (Major) |

Reviewer A: 5 PASS, 1 FAIL, 1 SKIP. Reviewer B: 5 PASS, 1 FAIL, 1 SKIP.

## Next action

Amend `acceptance-tests.md` for round 2:

1. Make AC-003's Test Target explicitly obligate the boundary values: its
   fixture set must include a concept named `APIOrder` (consecutive uppercase)
   and a context named `order-taking-2` (digit segment), both accepted.
2. Remove the boundary-positive clause from AC-018 (keeping its three negative
   fixtures) or reduce it to a pointer to AC-003, so a negative AC no longer
   carries a positive proof.
3. Repoint the G3 matrix row's citation from 「AC-018 の境界正例」 to AC-003,
   and fix the Notes attribution from TEST-018 to TEST-003.
4. Extend the orchestrator's mechanical check to verify cited-AC polarity, not
   only name presence.

No finding may be waived.
