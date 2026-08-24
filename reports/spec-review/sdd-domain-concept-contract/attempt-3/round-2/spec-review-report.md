# Specification Review Report: sdd-domain-concept-contract

- Attempt: 3
- Round: 2
- Input hashes: requirements `2c5ef1adf119736594b839119f5f13e8c8715542470c9d095e9f41b7d34fa397` (unchanged from round 1), acceptance tests `b549ca86e7835704b449a378c6a129ad0eddbc79bc16463aa0dfa5bc640c5a5c`
- Reviewer A: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-a-a3r2-seq0768`, host session `SESS-spec-spec-reviewer-a-sdd-domain-concept-contract-a3r2-0768`
- Reviewer B: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-b-a3r2-seq0769`, host session `SESS-spec-spec-reviewer-b-sdd-domain-concept-contract-a3r2-0769`
- Verdict: `NEEDS_WORK`
- Warning count: 0
- Finding counts: Critical 0, Major 2, Minor 0

Round 2 amended `acceptance-tests.md` only: AC-003 was promoted to an
all-optional-fields-populated positive fixture including
`stakeholder_perspectives`; the G1 matrix row was split into three (required 7 /
optional populated / optional absent); the Positive-capability matrix legend
gained three satisfaction rules; and one non-enumerated universal in the G3 row
was replaced with an enumeration. `Spec-Review-Status` remains `Pending`.

## Round-1 finding: resolved

Neither reviewer raises the `stakeholder_perspectives` positive-coverage gap.
AC-003 now names the field explicitly and requires a valid `{actor, concern}`
entry.

## Findings

Both findings concern the Positive-capability matrix — the device added in
round 1 — and both are instances of the same class: a row claiming more than
its cited ACs demonstrate.

1. Major — `GOAL-AC-TRACE` (reviewer A): the row 「G1: optional フィールドは
   **不在でも**受理される | AC-004, AC-020」 cites AC-004 as evidence that an
   optional field may be absent, but AC-004's Test Target reads
   「Book/Bookshelf 正例 fixture（Book.must_not_own に display position /
   Placement concept が並び責務）が通過」 — `must_not_own` is **populated**
   there, the opposite state. AC-020's canary is scoped to the two object
   arrays its four sub-fixtures concern (`stakeholder_perspectives`,
   `distinguished_from`), and does not name `must_not_own`, a plain string
   array with no nested required fields. No AC states a fixture where
   `must_not_own` is entirely omitted and the concept still passes — even
   though requirements.md's Edge Cases requires that behavior
   （「must_not_own が空/欠落: 有効」）.

   Orchestrator verification: confirmed. AC-004's row contains
   `Book.must_not_own に display position`; a search for an AC covering
   `must_not_own` omission returns zero matches.

2. Major — `AMBIGUITY` (reviewer B): the same `must_not_own` defect, plus a
   second instance — the row 「G1: concept の required 7 フィールドが表現
   できる | AC-003, AC-004」 enumerates all seven field names, but neither
   cited AC's Test Target names `id`, `name`, `context`, `definition`,
   `essence`, or `evidence` literally; only `must_not_own`,
   `distinguished_from`, `stakeholder_perspectives`, and the gloss 「責務」
   appear. Under the matrix's own legend rule added this round
   （「各要素が引用 AC の Test Target に名前で現れることを確認する」）, the
   row does not satisfy its own standard.

## Recurrence

This is the third consecutive round in which a coverage device introduced by
the amendment carried the same defect it was introduced to prevent:

| Round | Device or row added | Defect |
|---|---|---|
| attempt 2 round 1 | Negative-path coverage matrix | three cells claimed covered by a shared-code-path assumption, no fixture |
| attempt 3 round 1 | Positive-capability matrix, G1 row | claimed all optional fields; `stakeholder_perspectives` had no positive AC |
| attempt 3 round 2 | G1 row split, optional-absent row | cites AC-004 for absence while AC-004 populates the field |

The third instance is the sharpest: the amendment that wrote the rule
「各要素が引用 AC の Test Target に名前で現れることを確認する」 shipped rows
violating that rule in the same edit. Writing the rule and applying it were
separate acts, and only the first was performed.

The corrective for round 3 is mechanical rather than editorial: for every row
of both matrices, grep the cited AC's Test Target text for each element the row
names, in the state the row claims (populated and absent are distinct states),
and only then finalize the row. Had that check been run this round, AC-004's
populated `must_not_own` would have surfaced immediately.

## Check results

| Check | Reviewer A | Reviewer B |
|---|---|---|
| REQ-TESTABILITY | PASS (Critical) | — |
| GOAL-AC-TRACE | **FAIL (Major)** | — |
| AC-OBSERVABLE | PASS (Major) | — |
| SCOPE-BOUNDARY | PASS (Major) | — |
| CONSTRAINTS-EXPLICIT | PASS (Major) | — |
| RISK-VALIDATION-SURFACE | PASS (Major) | — |
| AMBIGUITY | — | **FAIL (Major)** |
| CONTRADICTION | — | PASS (Critical) |
| EDGE-CASE-COVERAGE | — | PASS (Major) |
| ASSUMPTIONS-RESOLVABLE | — | PASS (Major) |
| APPROVAL-BOUNDARY | — | PASS (Critical) |
| DOWNSTREAM-READINESS | — | PASS (Major) |
| DOMAIN-CONFORMANCE | SKIP (Major) | SKIP (Major) |

Reviewer A: 5 PASS, 1 FAIL, 1 SKIP. Reviewer B: 5 PASS, 1 FAIL, 1 SKIP.

Note that reviewer B graded `APPROVAL-BOUNDARY` PASS this round, having
previously skipped it; both dispositions rest on the same reading that the
boundary is explicitly documented as human-only and out of scope.

## Next action

Round 3 is the terminal round of attempt 3: a Minor-only result produces PASS
with `warningCount > 0`, but any surviving Major or Critical produces BLOCKED.
The amendment must:

1. Add a positive fixture in which `must_not_own` is entirely absent and the
   concept passes, naming the field explicitly — AC-004 is the natural host
   since AC-003 is now the all-populated fixture — and restate the
   optional-absent row to cite it.
2. State in AC-003's Test Target that its concept carries all seven required
   fields, naming them, so the required-7 row's citation is literally true.
3. Before finalizing, mechanically verify every row of both matrices against
   the cited ACs' text, element by element and state by state.

No finding may be waived.
