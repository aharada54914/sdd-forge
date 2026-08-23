# Specification Review Report: epic-193-a5-capability-resolver

- Attempt: 3
- Round: 1
- Context: human-approved (2026-08-24, 「A①B①C①でやれ」) frozen-document amendments A① (AC-056 warn-only sentence, "or jointly caused" evaluation-abort exception) and B① (AC-016 byte-identity scoped to exclude `state` and the enforcement-derived `context_binding` digests) applied to a previously `Spec-Review-Status: Passed` package; reset to `Pending` for amendment re-review under the `## Amendment Re-Review Context` lane (investigation.md entry; calibration section of the same name). Automated `spec-review-precheck.sh 3 1 --reset` could not validate attempt-2's legacy-shaped evidence; manual precheck fallback documented in `manual-precheck-note.md` beside `precheck-result.json`, attempt-2 evidence preserved unchanged.
- Input hashes: requirements `9c52691e2eac9ed30c01580ed6d8b256920ee7c898b42da7cc01f4180a707b7c`, acceptance tests `ef78ed2463854cc01933b8e9af860540d2deca1c53387f4feeecda149fec4aa2`
- Reviewer A: run `RUN-epic-193-a5-capability-resolver-spec-spec-reviewer-a-a3r1-seq0770`, host session `SESS-spec-spec-reviewer-a-epic-193-a5-capability-resolver-a3r1-0770`, allowed input manifest: requirements.md, acceptance-tests.md, investigation.md, spec-review-calibration.md, precheck-result.json (5 files, see `spec-review-contract.json` for hashes)
- Reviewer B: run `RUN-epic-193-a5-capability-resolver-spec-spec-reviewer-b-a3r1-seq0771`, host session `SESS-spec-spec-reviewer-b-epic-193-a5-capability-resolver-a3r1-0771`, allowed input manifest: the same plus integrated-summary.json (6 files, see `spec-review-contract.json` for hashes)
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Integrated Summary

Reviewer A: 5 PASS, 1 FAIL (GOAL-AC-TRACE, Critical), 1 SKIP (DOMAIN-CONFORMANCE, no `domain/` directory).

Reviewer B: 3 PASS, 3 FAIL (CONTRADICTION Critical; AMBIGUITY Major; EDGE-CASE-COVERAGE Major; DOWNSTREAM-READINESS Major — four FAIL entries, of which one Critical and three Major), 2 SKIP (APPROVAL-BOUNDARY per its explicit skip condition; DOMAIN-CONFORMANCE, no `domain/` directory).

Finding counts (both reviewers combined): 2 Critical, 3 Major, 0 Minor.

## Findings

Both reviewers independently converge on one root cause: ruling A①'s
"or jointly caused" exception was written into REQ-004's prose sentence only.
The two acceptance-criteria restatements of the same cardinality rule —
requirements.md's own AC-056 table row and acceptance-tests.md's
AC-056/TEST-056 row — still state the unqualified pre-amendment rule
("plus exactly one additional `severity: "block"` entry sharing the identical
id … never fewer, never a second summary entry"), producing an internal
contradiction on a testable pass/fail boundary (A: GOAL-AC-TRACE Critical;
B: CONTRADICTION Critical, DOWNSTREAM-READINESS Major).

Reviewer B additionally finds:

- AMBIGUITY (Major): the amendment introduces the term "evaluation pass"
  exactly once, undefined in Field Definitions and unanchored to REQ-001's
  step vocabulary, leaving the joint-cause boundary open to divergent
  implementations.
- EDGE-CASE-COVERAGE (Major): neither AC-056 fixture description exercises
  the newly-lawful abort-exception output shape (warn entries with a
  different-id block summary and no same-id summary), so the new path has
  no test oracle.

## Disposition

NEEDS_WORK at round 1. Remedy within this attempt: mirror the amended
exception into both AC-056 restatement rows (the propagation the ruling's
own "where a restatement exists, mirror" instruction requires), anchor
"evaluation pass" to REQ-001's own step vocabulary, and extend the
AC-056/TEST-056 fixture description with the abort-exception case — then
round 2 with fresh reviewer identities.
