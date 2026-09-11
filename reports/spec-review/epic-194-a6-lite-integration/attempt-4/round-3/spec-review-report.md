# Specification Review Report: epic-194-a6-lite-integration — Attempt 4 / Round 3

## Verdict: BLOCKED

| Field | Value |
|---|---|
| Attempt | 4 |
| Round | 3 of 3 (last round of this attempt) |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings | 0 |

Per the spec-review state table, a round-3 result carrying Major or Critical
findings produces BLOCKED. `Spec-Review-Status` therefore remains `Pending`.

**The substantive defects of rounds 1 and 2 are closed, and both reviewers say
so independently.** Reviewer A: "No bucket was found with a correct
classification but a wrong stated mechanism — the round 1/round 2 defect class
was actually closed for the fixture-grounding content itself." Reviewer B:
"Round 2s missing-path defect is genuinely closed" and the fixture split "is a
correct fix, not merely a responsive one." Reviewer B also moved
`ASSUMPTIONS-RESOLVABLE` and `CONTRADICTION` from FAIL to PASS.

**What survives is form, not fact.** Both reviewers, blind to each other,
found the same two un-enumerated set-references and both state the underlying
facts are correct today.

## Reviewer-A Results

| Check | Result | Severity |
|---|---|---|
| `REQ-TESTABILITY` | PASS | Critical |
| `GOAL-AC-TRACE` | PASS | Major |
| `AC-OBSERVABLE` | PASS | Major |
| `SCOPE-BOUNDARY` | PASS | Major |
| `CONSTRAINTS-EXPLICIT` | FAIL | Major |
| `RISK-VALIDATION-SURFACE` | PASS | Major |
| `DOMAIN-CONFORMANCE` | SKIP | Major |

## Reviewer-B Results

| Check | Result | Severity |
|---|---|---|
| `AMBIGUITY` | FAIL | Major |
| `CONTRADICTION` | PASS | Critical |
| `EDGE-CASE-COVERAGE` | PASS | Major |
| `ASSUMPTIONS-RESOLVABLE` | PASS | Major |
| `APPROVAL-BOUNDARY` | PASS | Critical |
| `DOWNSTREAM-READINESS` | PASS | Major |
| `DOMAIN-CONFORMANCE` | SKIP | Major |

## Findings, verbatim

### CONSTRAINTS-EXPLICIT (Major) — reviewer A

Both passages amended for this round each contain one surviving pronoun-based set-reference that does not carry its own referents, violating the rule this round's own edit_summary states was adopted ('never refer to a set except by enumerating it -- no counts, no positional forms, no "those named"'): (1) requirements.md Roles and Permissions, 'Epic A2's own Phase 2 implementer' bullet, the contracts/lite-check-catalog.json sub-bullet: 'It is the one path among those listed here that still requires a new protection registration' -- 'those listed here' is the same referent-less pattern as the banned 'those named,' pointing at the four-path list without re-enumerating it at the point of use. (2) requirements.md Assumptions, 'REQ-006 fixture grounding, split per fixture,' bucket 1: 'Both turn on a Registry Capability carrying required_lite_checks' -- 'Both' stands in for {fixture (a), the required_lite_checks half of fixture (f)} without re-naming them, unlike every sibling bucket in the same Assumption (the (d)/(e), (i)/(j), (b)/(c), and (g)/(h)/(k) buckets each re-enumerate their own fixture letters at every reference, never using a pronoun). Downstream failure mode: a future editor who changes either enumerated set (adds/removes a contracts/ path, or reclassifies a REQ-006 fixture) has no textual signal that the pronoun-referenced sentence must be re-checked, which is the identical drift mechanism that produced this round's own predecessor findings (a per-path list silently omitting contracts/capability-registry.json; a fixture bucket citing the wrong grounding mechanism). This belongs to specification review because it is a self-consistency property of the Phase 1 text itself, not an implementation-phase concern. Major, because it reintroduces -- inside the very sentences drafted to close out two prior NEEDS_WORK rounds on this same defect family -- the exact ambiguity-under-future-edit pattern the adopted rule exists to prevent, even though both underlying facts are correct today.

### AMBIGUITY (Major) — reviewer B

requirements.md Roles and Permissions, contracts/lite-check-catalog.json sub-bullet: 'It is the one path among those listed here that still requires a new protection registration...' asserts a uniqueness claim over the four-path list using an un-enumerated positional reference ('those listed here'), structurally the same 'those named' pattern the round's own newly-adopted rule ('never refer to a set except by enumerating it -- no counts, no positional forms, no "those named"') forbids. requirements.md Assumptions, REQ-006 bucket 1: 'Both turn on a Registry Capability carrying required_lite_checks...' substitutes 'Both' for re-naming fixture (a) and the required_lite_checks half of fixture (f). Downstream failure mode: a future edit to the enumerated set either sentence depends on (a new contracts/ protection status change, a fixture re-bucketing) has no inline signal that 'those listed here' or 'Both' still holds -- the same silent-drift mechanism that produced round 2's missing-path contradiction, reintroduced in non-self-verifying form. This is spec-review scope because it is the literal remediation text this round reviews, and the round's own instruction treats a surviving un-enumerated set-reference as a finding regardless of whether today's underlying fact is correct (both facts here are in fact correct, keeping this Major rather than Critical: the substantive content -- the four-path set match against the opening sentence, each path's protection status, and the fixture-by-fixture bucket assignment across all twelve letters (a)-(l) with fixture (f) split into both its halves -- is independently verified correct).

## Proposed Changes

Not applied. Round 3 is the last round of attempt 4; closing these requires a
new attempt, which is an upstream decision.

The two surviving sites, both in `requirements.md`:

1. Roles and Permissions, `contracts/lite-check-catalog.json` sub-bullet —
   "It is the one path among those listed here that still requires a new
   protection registration". Replace "those listed here" with the three other
   paths named in full.
2. Assumptions, REQ-006 fixture split, first bucket — "Both turn on a Registry
   Capability carrying `required_lite_checks`". Replace "Both" with "fixture
   (a) and the `required_lite_checks` half of fixture (f)".

## Why the pre-commit check did not catch these

The enumeration self-check run before the round-3 commit used
`grep -nE` with a case-sensitive `\bboth\b` and a literal `those named`.
Capitalised `Both` at sentence start did not match, and `those listed here` is
a variant of the positional pattern that the literal string did not cover.
The check must be case-insensitive and must cover `\bthose\b` generally, not
only `those named`.

## Next Steps

1. Upstream decision required: attempt 5 with `--reset` is the only permitted
   route after a round-3 BLOCKED.
2. `requirements.md` remains `Spec-Review-Status: Pending`; the impl and task
   stages stay blocked behind it.
