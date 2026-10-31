# Specification Review Report: sdd-domain-concept-contract

- Attempt: 2
- Round: 2
- Input hashes: requirements `80b41de351ed186fff2491f262073ba3d4950c6fb3ec8e152d28fce42dc6808a` (unchanged from round 1), acceptance tests `d3d71347e171a691842c3227228a760676663b18b855198d63f6bee4eb16f2a5`
- Reviewer A: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-a-a2r2-seq0762`, host session `SESS-spec-spec-reviewer-a-sdd-domain-concept-contract-a2r2-0762`
- Reviewer B: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-b-a2r2-seq0763`, host session `SESS-spec-spec-reviewer-b-sdd-domain-concept-contract-a2r2-0763`
- Verdict: `NEEDS_WORK`
- Warning count: 0
- Finding counts: Critical 0, Major 1, Minor 0

Round 2 amended `acceptance-tests.md` only: AC-023 was extended from 4 to 8
fixtures covering every `minLength 1` target; the three 「AC-023 と同経路」
cells in the coverage matrix were replaced with direct AC references; the
matrix legend gained a rule forbidding any cell whose coverage rests on an
assumption about validator internals; and the fixture tally was corrected from
35 to 44 with its derivation shown. `Spec-Review-Status` remains `Pending`.

## Round-1 finding: resolved

Reviewer A passes `AC-OBSERVABLE`, confirming AC-023's eight fixtures are
"the complete and exact set of minLength-1 targets enumerated in REQ-002's own
sentence". Reviewer B independently recomputed the corrected tally
(44 = 8 single-fixture ACs + 36 across AC-014/017/018/019/020/021/022/023) and
confirmed it holds, and verified the matrix's cell citations against the AC
table's own test-target text.

## Finding

1. Major — `EDGE-CASE-COVERAGE` (reviewer B), a violation mode the coverage
   matrix does not model at all: every column of the matrix
   （キー欠落 / 空配列 / 空文字列 / pattern 違反 / 参照整合）presupposes the
   key is present **with its declared JSON type**. Nothing in requirements.md,
   the Edge Cases section, the matrix, or AC-001..AC-023 addresses a
   syntactically valid JSON document in which a field carries the wrong type —
   `concepts[].id` as a number, `responsibilities` as a string instead of an
   array.

   Because REQ-004(c) specifies a hand-rolled validator with no JSON-Schema
   engine (INV-005), this is precisely where two implementations diverge: one
   guards with a type check before applying the id/name/context regex and
   emits a clean one-line violation; the other lets a bare regex or iteration
   call raise on the wrong type and prints a stack trace — which would violate
   the fail-closed, no-raw-exception expectation that AC-017 states for
   malformed input but tests only for broken syntax and oversized files.

   Orchestrator verification: confirmed. The matrix header declares exactly the
   five columns quoted above, and no line in acceptance-tests.md mentions a
   type mismatch (zero matches for 型 / 数値 / isinstance).

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

Round 3 is the terminal round of attempt 2: a Minor-only result produces PASS
with `warningCount > 0`, but any surviving Major or Critical produces BLOCKED.
The amendment must:

1. Add a 「型不一致」 column to the Negative-path coverage matrix and populate
   it for every row whose declared type could be violated, so the dimension
   becomes part of the completeness criterion rather than an unmodelled gap.
2. Add an AC supplying wrong-type fixtures — at minimum a scalar field given a
   non-string (e.g. `id` as a number) and an array field given a non-array
   (e.g. `responsibilities` as a string) — asserting non-zero exit with a
   one-line violation naming the field and no raw exception or stack trace.
3. State the type-check obligation in requirements.md if REQ-004(c)'s
   「required 項目・パターンの構造検査」 is not already understood to include
   type conformance, so the AC has a requirement to trace to.

No finding may be waived.
