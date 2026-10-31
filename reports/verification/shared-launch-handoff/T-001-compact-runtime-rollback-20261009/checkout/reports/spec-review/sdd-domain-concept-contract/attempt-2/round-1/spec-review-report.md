# Specification Review Report: sdd-domain-concept-contract

- Attempt: 2
- Round: 1
- Input hashes: requirements `80b41de351ed186fff2491f262073ba3d4950c6fb3ec8e152d28fce42dc6808a`, acceptance tests `98db8b7bd041ffe285bac4cc0c050239f1e5ecbc2f4c52c309d7752236577e4f`
- Reviewer A: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-a-a2r1-seq0760`, host session `SESS-spec-spec-reviewer-a-sdd-domain-concept-contract-a2r1-0760`
- Reviewer B: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-b-a2r1-seq0761`, host session `SESS-spec-spec-reviewer-b-sdd-domain-concept-contract-a2r1-0761`
- Verdict: `NEEDS_WORK`
- Warning count: 0
- Finding counts: Critical 0, Major 2, Minor 0

Attempt 2 was opened with `--reset` after attempt 1 terminated BLOCKED. Before
this round both artifacts were amended: `requirements.md` gained a `minLength 1`
declaration for every free-text string value and a pattern declaration for
`distinguished_from[].concept_id`; `acceptance-tests.md` gained AC-019..AC-023,
a rewritten AC-014 covering all seven required concept keys, and a new
"Negative-path coverage matrix" section intended as a structural fix for the
recurring negative-path gaps. `Spec-Review-Status` remains `Pending`.

## Attempt-1 findings: all resolved

Both reviewers pass the checks that failed across attempt 1. Reviewer B passes
`AMBIGUITY` (patterns now explicit), `CONTRADICTION` (governance text
consistent with INV-008), and skips `APPROVAL-BOUNDARY` as an explicitly
documented out-of-scope decision rather than a silently missing boundary.
Reviewer A passes `REQ-TESTABILITY`, `GOAL-AC-TRACE`, `SCOPE-BOUNDARY`,
`CONSTRAINTS-EXPLICIT`, and `RISK-VALIDATION-SURFACE`.

## Findings

Both reviewers independently identified the same defect through their
respective checks. It is a defect in the coverage matrix added this attempt.

1. Major — `AC-OBSERVABLE` (reviewer A) and `EDGE-CASE-COVERAGE` (reviewer B),
   converging on one root cause: requirements.md declares `minLength 1` for
   eight string targets, but AC-023 — the only minLength criterion — specifies
   exactly four fixtures (`definition`, `essence`, `responsibilities[]`
   element, `evidence[]` element). The coverage matrix nevertheless marks the
   空文字列 cells for `must_not_own[]`, `stakeholder_perspectives[].actor` /
   `.concern`, and `distinguished_from[].reasons[]` as 「AC-023 と同経路」.

   That label is an assumption about implementation structure — that the
   validator will route every minLength check through one shared routine — not
   an AC-backed coverage claim. REQ-004(c) specifies a hand-rolled validator
   (INV-005) in which required-vs-optional and top-level-vs-nested fields are
   typically separate branches, so an implementation could enforce minLength on
   the four tested fields and omit it on the other three with no acceptance
   test failing. The matrix's own completeness claim (「AC 表の網羅性はこの表の
   空白セルが無いことで判定する」) then actively misleads a task author into
   adding no fixture for them.

   Orchestrator verification: confirmed. AC-023's stated target lists exactly
   the four fixtures named; the three fields do not appear in it.

   Reviewer B additionally noted that the Notes tally 「負例 fixture の総数は
   35 件」 does not match the AC table's own per-AC counts, which sum to 40
   (AC-006..012 = 7, AC-014 = 7, AC-016 = 1, AC-017 = 2, AC-018 = 3,
   AC-019 = 3, AC-020 = 4, AC-021 = 7, AC-022 = 2, AC-023 = 4).

   Orchestrator verification: confirmed. The sum is 40; the document says 35.

## Reviewer-A output correction

Reviewer A's first return graded `REQ-TESTABILITY` a Critical FAIL, asserting
that REQ-002's minLength enumeration omitted `distinguished_from[].reasons[]`
and therefore contradicted the Field Definitions table. The orchestrator
checked the cited line against the bound (hash-verified) input and found the
quotation had dropped a token: requirements.md line 114 reads
`` `evidence[]` / `must_not_own[]` / `reasons[]` の各要素 ``, so no
contradiction exists. Reviewer A was asked to re-verify that specific
quotation against the file, with an explicit instruction not to alter any
other check and no indication of a preferred outcome; it re-read the line,
recorded the correction in its own finding text, and re-graded
`REQ-TESTABILITY` to PASS on the merits. `AC-OBSERVABLE` was left byte-
identical. No finding was waived by the orchestrator.

## Check results

| Check | Reviewer A | Reviewer B |
|---|---|---|
| REQ-TESTABILITY | PASS (Critical) | — |
| GOAL-AC-TRACE | PASS (Major) | — |
| AC-OBSERVABLE | **FAIL (Major)** | — |
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

## Next action

Amend `acceptance-tests.md` for attempt 2 round 2:

1. Extend AC-023 from 4 to 7 fixtures so every `minLength 1` target has its own
   negative fixture, adding `must_not_own[]` element,
   `stakeholder_perspectives[].actor`, `.concern`, and
   `distinguished_from[].reasons[]` element.
2. Remove the 「AC-023 と同経路」 label from the matrix and its explanatory
   note; those cells become direct AC-023 references once the fixtures exist.
   The matrix must not carry any cell whose coverage rests on an assumption
   about validator internals.
3. Correct the fixture tally to the value derived from the AC table itself.

No finding may be waived.
