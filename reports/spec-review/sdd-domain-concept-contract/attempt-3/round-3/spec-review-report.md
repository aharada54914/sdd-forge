# Specification Review Report: sdd-domain-concept-contract

- Attempt: 3
- Round: 3 (terminal round of the attempt)
- Input hashes: requirements `2c5ef1adf119736594b839119f5f13e8c8715542470c9d095e9f41b7d34fa397` (unchanged across all three rounds), acceptance tests `7c7d401b7837af103a08b89657669e18996deadca6ee468d875a57ce2ffbec63`
- Reviewer A: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-a-a3r3-seq0770`, host session `SESS-spec-spec-reviewer-a-sdd-domain-concept-contract-a3r3-0770`
- Reviewer B: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-b-a3r3-seq0771`, host session `SESS-spec-spec-reviewer-b-sdd-domain-concept-contract-a3r3-0771`
- Verdict: `BLOCKED`
- Warning count: 0
- Finding counts: Critical 1, Major 1, Minor 0

Round 3 amended `acceptance-tests.md` only: AC-004 was redefined as the
optional-fields-all-absent positive fixture, AC-003 gained an explicit
enumeration of the seven required fields, the three G1 rows of the
Positive-capability matrix were rewritten to match their cited ACs, and
AC-020's canary was removed in favour of AC-004. `Spec-Review-Status` remains
`Pending`.

## Round-2 findings: resolved

Both reviewers confirm the two round-2 Majors are closed. Reviewer A verifies
that the rewritten G1 rows now literally match their cited ACs' Test Target
text in the correct populated/absent states. Reviewer B re-derived the
73-fixture tally independently (8 single-fixture ACs + 65 across the nine
multi-fixture ACs) and confirms every negative-matrix cell is backed by an AC
naming the field.

## Surviving finding

Both reviewers identified the same defect; they graded it under different
checks and at different severities, and the higher governs.

1. Critical — `CONTRADICTION` (reviewer B) / Major — `GOAL-AC-TRACE`
   (reviewer A): requirements.md REQ-005(b) mandates
   「Book/Bookshelf の正例（**Book.must_not_own に display position**、
   Placement concept が並び責務を持つ）」. AC-004, the only AC mapped to
   REQ-005(b), was rewritten this round to require
   「optional フィールドを 1 つも持たない状態とし、`must_not_own`・
   `stakeholder_perspectives`・`distinguished_from` の 3 キーをいずれも
   欠落させる」 — the opposite instruction for the same fixture. The string
   `display position` no longer appears anywhere in acceptance-tests.md, so no
   other AC picks up REQ-005(b)'s content mandate. An implementer cannot
   satisfy both texts with one fixture.

   Orchestrator verification: confirmed. REQ-005(b)'s text is intact at
   requirements.md line 145; `display position` returns zero matches in
   acceptance-tests.md.

   This is a regression introduced by this round's own amendment. The round-2
   finding (AC-004 cited as evidence of optional-absence while it populated
   `must_not_own`) was correct, but the fix repurposed AC-004 instead of adding
   a new AC, and in doing so broke AC-004's traceability to REQ-005(b).

## Terminal-round outcome

Per the state-transition rules, a round-3 result carrying any Major or Critical
produces `BLOCKED`. One Critical and one Major survived, so attempt 3 is
BLOCKED. No finding was waived and the status field was not changed.

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
| CONTRADICTION | — | **FAIL (Critical)** |
| EDGE-CASE-COVERAGE | — | PASS (Major) |
| ASSUMPTIONS-RESOLVABLE | — | PASS (Major) |
| APPROVAL-BOUNDARY | — | SKIP (Critical) |
| DOWNSTREAM-READINESS | — | PASS (Major) |
| DOMAIN-CONFORMANCE | SKIP (Major) | SKIP (Major) |

Reviewer A: 5 PASS, 1 FAIL, 1 SKIP. Reviewer B: 5 PASS, 1 FAIL, 1 SKIP.

## Process finding: the amendment loop is the failure mode

Three attempts, nine rounds, eighteen reviewer invocations. Every surviving
finding has been a defect in the amendment written to close the previous
finding:

| Round | What the amendment added | Defect it carried |
|---|---|---|
| a2 r1 | Negative-path coverage matrix | three cells claimed covered by a shared-code-path assumption |
| a2 r2 | `型不一致` column | (resolved cleanly) |
| a3 r1 | Positive-capability matrix | G1 row claimed all optional fields; `stakeholder_perspectives` had no positive AC |
| a3 r2 | G1 row split, legend rules | optional-absent row cited AC-004, which populates the field |
| a3 r3 | AC-004 repurposed | contradicts REQ-005(b), which mandates the populated field |

The orchestrator's self-check before this round verified matrix rows against AC
text — 10 positive rows and 55 negative cell citations, all consistent — but did
not verify AC text against requirements.md's REQ-005 fixture mandates. The
check covered the downstream edge and missed the upstream one, which is exactly
where this round's regression landed.

Two structural conclusions:

1. Any future amendment must be validated in **both** directions: REQ-005's
   fixture enumeration and the Field Definitions table against the AC table,
   and the matrices against the AC table. A one-directional check will keep
   producing this class of defect.
2. Repurposing an existing AC to serve a new role silently drops whatever
   requirement it was mapped to. New capabilities need new ACs; the mapping
   column is a contract, not a label.

## Next action

Attempt 3 is terminal. Re-invoke the gate with `--reset` to open attempt 4
after amending. Prior evidence is preserved and `Spec-Review-Status` stays
`Pending`.

The minimal correct amendment:

1. Restore AC-004 to REQ-005(b)'s mandate: Book/Bookshelf positive fixture with
   `Book.must_not_own` populated with `display position` and Placement holding
   the ordering responsibility.
2. Add a **new** AC (AC-026) for the optional-fields-all-absent positive
   fixture, and repoint the Positive-capability matrix's optional-absent row at
   it.
3. Add REQ-005(f) mandating that absent-optional fixture, so the new AC has a
   requirement to trace to.
4. Before finalizing, run the bidirectional check described above.

Given that five consecutive amendments have each introduced a defect, the
alternative worth weighing is to stop amending in-session: file the remaining
findings as issues and let a human decide the specification text. No finding
may be waived either way.
