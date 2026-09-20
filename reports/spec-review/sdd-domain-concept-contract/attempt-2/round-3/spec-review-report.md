# Specification Review Report: sdd-domain-concept-contract

- Attempt: 2
- Round: 3 (terminal round of the attempt)
- Input hashes: requirements `823e8fad6b62d65dda47ed114640c48a9d94ac65dee987940cb7db80023370f0`, acceptance tests `6ee9192ace100ebace7041c35e448b668d07053726a764ac290c84ca6f2cc86d`
- Reviewer A: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-a-a2r3-seq0764`, host session `SESS-spec-spec-reviewer-a-sdd-domain-concept-contract-a2r3-0764`
- Reviewer B: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-b-a2r3-seq0765`, host session `SESS-spec-spec-reviewer-b-sdd-domain-concept-contract-a2r3-0765`
- Verdict: `BLOCKED`
- Warning count: 0
- Finding counts: Critical 0, Major 1, Minor 0

Round 3 amended both artifacts: REQ-004(c) gained an explicit JSON type-conformance
obligation with a precedence rule (type check runs before pattern / minLength /
minItems, and must not apply those to a mistyped value); acceptance-tests.md
gained AC-024 / TEST-024 with 29 fixtures — one per typed field — plus a
「型不一致」 column filling every row of the coverage matrix. The fixture tally
was updated to 73. `Spec-Review-Status` remains `Pending`.

## Round-2 finding: resolved

Both reviewers confirm the type-mismatch gap is closed. Reviewer B passes
`EDGE-CASE-COVERAGE` after walking the matrix cell by cell and independently
re-deriving the tally (8 single-fixture ACs + 65 across the multi-fixture ACs =
73, matching), and recounting AC-024's 29 sub-items against its own
enumeration. Reviewer A passes `REQ-TESTABILITY`, confirming the 29 fixtures
match every typed field in the Field Definitions table (4 root + 3 meta +
1 concept element + 5 concept scalars + 3 concept arrays + 3 array elements +
4 stakeholder_perspectives + 5 distinguished_from + 1 term = 29).

## Surviving finding

1. Major — `GOAL-AC-TRACE` (reviewer A): G2「term から concept への連結
   （concept_id）を v2 で表現可能にする（REQ-003）」has **no positive-case
   acceptance criterion**. Every AC mentioning `term.concept_id` is negative:
   AC-009 (dangling reference), AC-022(2) (pattern violation), AC-024(29)
   (type mismatch). AC-001, the only schema-structure criterion, is scoped to
   root required keys and meta shape and never asserts that the v2 schema's
   term definition actually carries the new optional `concept_id` with its
   pattern. REQ-005's fixture mandate — (a) Purchase/Fulfillment 正例,
   (b) Book/Bookshelf 正例, (c) 同名別概念のコンテキスト横断正例,
   (d) REQ-004(d)-(i) の負例 — never requires a fixture in which a term
   actually references a concept.

   Downstream failure mode: a task author could build the entire corpus (73
   negative + the positive fixtures) without ever exercising the valid-link
   path. A validator that rejects a syntactically valid, non-dangling
   `concept_id` as if it were dangling, or that silently ignores the field,
   would leave every fixture green while G2's central claim — that the link is
   expressible — remains unverified.

   Orchestrator verification: confirmed. `concept_id` appears in AC-008,
   AC-009, AC-020, AC-022, and AC-024, all negative-fixture rows. AC-003,
   AC-004, and AC-005 (the positive fixtures) contain no reference to `term`,
   and neither does AC-001.

## Terminal-round outcome

Per the state-transition rules, a round-3 result carrying any Major or Critical
produces `BLOCKED`. One Major survived, so attempt 2 is BLOCKED. The finding
was not waived and the status field was not changed.

Reviewer B returned PASS on all five evaluated checks. The merged verdict takes
any FAIL, so reviewer A's Major governs.

## Non-blocking observations recorded by reviewer B

- The 「`concepts[]` の要素 (object)」 row's キー欠落 cell cites AC-021, which
  tests the root `concepts` key being absent rather than an element-scoped
  constraint — redundant with the row above rather than incorrect.
- The Open Questions section's boilerplate wording is stale: OQ-003 and OQ-004
  are in practice resolved by adoption into unconditional REQ-002 / REQ-004(b)
  text.

Neither was graded blocking; both are recorded for the next amendment.

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
| EDGE-CASE-COVERAGE | — | PASS (Major) |
| ASSUMPTIONS-RESOLVABLE | — | PASS (Major) |
| APPROVAL-BOUNDARY | — | SKIP (Critical) |
| DOWNSTREAM-READINESS | — | PASS (Major) |
| DOMAIN-CONFORMANCE | SKIP (Major) | SKIP (Major) |

Reviewer A: 5 PASS, 1 FAIL, 1 SKIP. Reviewer B: 5 PASS, 0 FAIL, 2 SKIP.

## Attempt-level observation

Across both attempts every surviving finding has been a coverage gap in
acceptance-tests.md, and each was verified factually correct by the
orchestrator:

| Attempt / round | Surviving gap |
|---|---|
| 1 / 1 | empty `concepts[]`, oversized and malformed input |
| 1 / 2 | pattern violations; governance contradiction (Critical x2) |
| 1 / 3 | required-key absence for `definition` and for `id`/`name`/`context` |
| 2 / 1 | three `minLength` targets asserted covered by a shared-code-path assumption |
| 2 / 2 | JSON type mismatch — a violation mode the matrix did not model |
| 2 / 3 | **no positive-case criterion for the `term` → `concept` link** |

The first five are all negative-path gaps, and the coverage matrix introduced
in attempt 2 was built to close that class systematically. This round's finding
is the first on the **positive** side: the matrix models constraint × violation
mode, and therefore cannot express "this declared capability is accepted when
used correctly". Every goal that adds an expressive capability needs a positive
criterion proving the capability works, not only negatives proving misuse is
rejected.

## Next action

Attempt 2 is terminal. Re-invoke the gate with `--reset` to open attempt 3
round 1 after amending the artifacts. Prior evidence is preserved and
`Spec-Review-Status` stays `Pending`.

The amendment should:

1. Add a positive acceptance criterion for the `term.concept_id` link: a
   fixture in which a term references an existing concept, passing the
   validator with exit 0, paired with a structural assertion that the v2 schema
   declares `contexts[].terms[].concept_id` as optional with the concept-id
   pattern.
2. Add REQ-005 fixture-mandate text requiring that link, so a task author is
   obliged to build it.
3. Introduce a **positive-capability matrix** alongside the negative-path one:
   one row per goal / declared capability, each citing the AC that proves the
   capability is accepted when exercised correctly. The negative-path matrix
   cannot express this dimension, which is why the gap survived two attempts.
4. Optionally fix the two non-blocking nits reviewer B recorded.

No finding may be waived.
