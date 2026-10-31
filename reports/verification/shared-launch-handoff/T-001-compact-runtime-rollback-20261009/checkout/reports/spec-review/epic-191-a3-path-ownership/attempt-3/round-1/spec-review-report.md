# Specification Review Report: epic-191-a3-path-ownership

- Attempt: 3
- Round: 1
- Input hashes: requirements `a3d710ca599f42b6c67f6df88887578d73b8d610b463238b9a79f00019636d69`, acceptance tests `8f47775bee958d9f5ba59e3e84e5cea306b8f6ecb381faaeb6b0d662d76f28e0`
- Reviewer A: run `RUN-epic-191-a3-path-ownership-spec-spec-reviewer-a-a3r1-seq0669`, host session `SESS-spec-spec-reviewer-a-epic-191-a3-path-ownership-a3r1-0669`
- Reviewer B: run `RUN-epic-191-a3-path-ownership-spec-spec-reviewer-b-a3r1-seq0670`, host session `SESS-spec-spec-reviewer-b-epic-191-a3-path-ownership-a3r1-0670`
- Verdict: `PASS`
- Warning count: 0

Attempt 3 was opened with `--reset` after attempt 2 ended BLOCKED at round 3
(terminal), on explicit human authorization. `spec-review-precheck.sh` rejects
`--edit-summary` at round 1, so the amendment context is recorded here: the
human-directed amendment `6e7c84dd` closed the a2r3 single Major
(EDGE-CASE-COVERAGE, reviewer B, seq0668) by assigning the resolver-side
present-but-malformed `--config` clause of REQ-001 its own anchor — new
AC-056 in requirements.md (both runtimes exit non-zero at load time naming
the parse failure, before any matching work; `--diagnose` inherits the
identical contract; explicitly the resolver-side twin of AC-035's Gate-side
extension, never merged with it) and a new TEST-056 row in
acceptance-tests.md (explicitly distinct from TEST-035d, mirroring 035d's
own distinct-from-035c statement), with the declared 1:1 mapping ranges
extended to AC-001..AC-056 / TEST-001..TEST-056 and a dated amendment note
quoting the previous values. A fourth-gap sweep verified every other
normative statement introduced by the round-3 amendment `2bb10bac` already
carries an AC/TEST anchor. Identities seq0669 (reviewer A) and seq0670
(reviewer B) were validator-reserved in sequence; the documented orphan
seq0664 was not reused.

## Findings

Reviewer A: verdict `PASS` — 6 PASS, 0 FAIL, 1 SKIP (DOMAIN-CONFORMANCE, no
`domain/` directory). Reviewer A found every Goal (REQ-001..REQ-009) traced
to concrete, fixture-based, externally observable acceptance criteria with
the 1:1 AC↔TEST mapping intact through AC-056/TEST-056, explicit non-goal
and constraint boundaries, and every named risk bound to a concrete
validation surface.

Reviewer B: verdict `PASS` — 6 PASS, 0 FAIL, 1 SKIP (DOMAIN-CONFORMANCE).
Reviewer B traced the conditional-activation ruling across all six locations
it touches and found no divergent claim; confirmed the a2r3 Major is closed
by TEST-035d/TEST-056 with the three surfaces (check-contract-side,
Gate-side, resolver-side) explicitly disambiguated; and found no
contradiction, unresolved assumption, or product behavior left for a
downstream reviewer to invent. Reviewer B noted one prose slip in
Dependencies ("a fourth protected-file family" where only two families are
named beside it) but ruled it below the calibration Finding Evidence Gate
because the protected-file enumeration is independently consistent in Roles
and Permissions and AC-036, so no implementer decision is affected.

Procedural disclosure (recorded verbatim from reviewer B, not a spec
finding): "while investigating this same question, a directory-scoped Grep
of mine (procedural error, not evidence) surfaced 2 lines of design.md
content outside my manifest; not used as evidence for this or any other
finding." Reviewer B disclosed this in its AMBIGUITY finding per
review-context-boundary.md's disclosure guidance, independently re-derived
the analysis from in-manifest requirements.md, and used only single-file,
manifest-scoped reads thereafter. The verdict is recorded as delivered.

## Transition

Both reviewers returned `PASS` with zero FAIL findings, so the merged
verdict is `PASS` with `warningCount: 0` (state table row "Pending, no
evidence | round 1 | PASS changes header to Passed"). `Spec-Review-Status`
in requirements.md moves from `Pending` to `Passed` via this validated
merged PASS — the sole sanctioned mechanism. The three-attempt history is
preserved intact under `reports/spec-review/epic-191-a3-path-ownership/`:
attempt 1 (BLOCKED, Critical CONTRADICTION, fixed), attempt 2 (BLOCKED at
round 3: two validation-surface Majors fixed in round 2's amendment, the
round-3 anchor Major fixed by `6e7c84dd`), attempt 3 round 1 (PASS).
Downstream provenance pins on the impl- and task-review stages are stale
against the amended spec bytes and require their `--provenance-rereview`
passes next.
