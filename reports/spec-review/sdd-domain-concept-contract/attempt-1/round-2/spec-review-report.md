# Specification Review Report: sdd-domain-concept-contract

- Attempt: 1
- Round: 2
- Input hashes: requirements `007fb0d261ecebbb6eed0f03bcf97358ffa1efd0ea1b5278e43f11a3bcf276bd` (unchanged from round 1), acceptance tests `7e4b2f9fe0d866390b9ddafb935eacacdba226422fda7e79a3d370c1996c2168`
- Reviewer A: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-a-a1r2-seq0756`, host session `SESS-spec-spec-reviewer-a-sdd-domain-concept-contract-a1r2-0756`
- Reviewer B: run `RUN-sdd-domain-concept-contract-spec-spec-reviewer-b-a1r2-seq0757`, host session `SESS-spec-spec-reviewer-b-sdd-domain-concept-contract-a1r2-0757`
- Verdict: `NEEDS_WORK`
- Warning count: 0
- Finding counts: Critical 2, Major 3, Minor 0

Round 2 was opened with `--edit-summary` after the round-1 NEEDS_WORK. The
amendment added AC-016 (empty `concepts[]`) and AC-017 (malformed / oversized
input, fail-closed) to acceptance-tests.md and extended the TEST ID range to
TEST-017. `requirements.md` was not changed. `Spec-Review-Status` remains
`Pending`.

The round-1 finding is resolved: reviewer B's round-2 `EDGE-CASE-COVERAGE`
finding no longer cites the empty-`concepts[]` or oversized-input gaps, and
reviewer A's `AC-OBSERVABLE` explicitly cites AC-017's stderr contract as
observable. Round 2 surfaced five new findings against artifact text that was
already present in round 1.

## Findings

1. Critical — `CONTRADICTION` (reviewer B): requirements.md "Roles and
   Permissions" asserts in one sentence that this feature's artifacts are
   「いずれも hook-guard 保護対象外（INV-008）で agent 編集可能」and in the
   same parenthetical that「meta.status の Approved 書込制御は既存どおり
   v1/v2 共通で hook guard と人間の責務」. INV-008 states hook-guard's
   protected-path list does not include `contracts/domain-contract.*` at all
   (「contracts 配下の保護は capability-registry 系のみ」). The spec cannot
   simultaneously assert zero hook-guard protection for this path and that
   hook-guard controls `meta.status` writes within the same path family. A
   design or task author cannot determine whether an approval-enforcement
   mechanism exists, must be built here, or is genuinely absent.

   Orchestrator verification: confirmed against
   `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` —
   `PROTECTED_GATE_SUFFIXES` contains `contracts/capability-registry.json`,
   `contracts/capability-registry.schema.json`, and
   `contracts/lite-upgrade-reason-catalog.json`, and no
   `contracts/domain-contract.*` entry. INV-008 is accurate; the
   requirements.md sentence is the defective text.

2. Critical — `APPROVAL-BOUNDARY` (reviewer B): because "Roles and
   Permissions" puts the `meta.status` Approved write control in scope, SKIP is
   unavailable for this check. The claim is self-contradictory (finding 1) and
   no AC in acceptance-tests.md references `meta.status` or verifies any
   enforcement of it, so the boundary is not testable in its current form.

3. Major — `AMBIGUITY` (reviewer B): REQ-002 and the Field Definitions table
   give `concepts[].name` as "PascalCase" and `concepts[].context` as
   "kebab-case" with no regex, while `concepts[].id` gets an explicit
   `^CONCEPT-[A-Z][A-Z0-9-]*$`. REQ-004(c) requires the hand-rolled validator
   (INV-005, no external JSON-Schema engine) to perform
   「パターンの構造検査」. Two implementers writing the independent sh/ps1
   twins would plausibly encode different PascalCase regexes (digits,
   single-letter names, acronyms such as `APIOrder`), producing exactly the
   twin divergence requirements.md itself names as R2/R3.

4. Major — `EDGE-CASE-COVERAGE` (reviewer B): no AC exercises a pattern-format
   violation for `id`, `name`, or `context`, although REQ-004(c) lists
   「パターンの構造検査」as a validator duty distinct from required-field and
   reference checks. AC-006..AC-012, AC-014, AC-016, AC-017 cover duplicates,
   dangling references, self-contradiction, required-field omission, empty
   array, and malformed input — none covers a malformed identifier.

   Orchestrator verification: confirmed by reading the AC table; no row
   exercises a pattern violation.

5. Major — `DOWNSTREAM-READINESS` (reviewer B): the compounding effect of
   findings 1-3 means a design/implementation-policy reviewer would have to
   invent product decisions — whether an approval-control mechanism must be
   newly built, and what regex defines a valid concept name — rather than
   receiving a bounded specification.

## Reviewer disagreement

Reviewer A returned PASS on all six evaluated checks, including
`CONSTRAINTS-EXPLICIT` and `REQ-TESTABILITY`. Reviewer A also read the
PascalCase/kebab-case gap in round 1 and graded it non-blocking, whereas
reviewer B in round 2 graded the same text a Major `AMBIGUITY` failure on the
strength of the twin-divergence argument. The merged verdict takes any FAIL,
so the NEEDS_WORK stands. This disagreement is recorded rather than resolved:
no finding was waived.

Note also that reviewer B graded `CONTRADICTION` PASS and `APPROVAL-BOUNDARY`
SKIP in round 1 against byte-identical requirements.md text, and FAIL/Critical
in round 2. The round-2 findings were independently verified by the
orchestrator against the guard source and the AC table and are factually
grounded; the round-1 instance missed them.

## Check results

| Check | Reviewer A | Reviewer B |
|---|---|---|
| REQ-TESTABILITY | PASS (Critical) | — |
| GOAL-AC-TRACE | PASS (Major) | — |
| AC-OBSERVABLE | PASS (Major) | — |
| SCOPE-BOUNDARY | PASS (Major) | — |
| CONSTRAINTS-EXPLICIT | PASS (Major) | — |
| RISK-VALIDATION-SURFACE | PASS (Major) | — |
| AMBIGUITY | — | **FAIL (Major)** |
| CONTRADICTION | — | **FAIL (Critical)** |
| EDGE-CASE-COVERAGE | — | **FAIL (Major)** |
| ASSUMPTIONS-RESOLVABLE | — | PASS (Major) |
| APPROVAL-BOUNDARY | — | **FAIL (Critical)** |
| DOWNSTREAM-READINESS | — | **FAIL (Major)** |
| DOMAIN-CONFORMANCE | SKIP (Major) | SKIP (Major) |

Reviewer A: 6 PASS, 0 FAIL, 1 SKIP. Reviewer B: 1 PASS, 5 FAIL, 1 SKIP.

## Next action

Round 3 is the terminal round of attempt 1: a Minor-only result produces PASS
with `warningCount > 0`, but any surviving Major or Critical produces BLOCKED.
The round-3 amendment must therefore resolve all five findings, and requires
edits to `requirements.md` — which has been unchanged through both rounds so
far — not only to `acceptance-tests.md`:

1. Correct the "Roles and Permissions" sentence so it states the actual
   enforcement position for `meta.status` under INV-008 (no hook-guard
   protection for `contracts/domain-contract.*`), rather than asserting
   hook-guard control.
2. State explicit regexes for `concepts[].name` and `concepts[].context`
   alongside the existing `id` pattern, in both REQ-002 and the Field
   Definitions table.
3. Add acceptance criteria for pattern-format violations of `id`, `name`, and
   `context`.

No finding may be waived.
