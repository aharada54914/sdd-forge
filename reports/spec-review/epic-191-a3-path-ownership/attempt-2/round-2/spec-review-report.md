# Specification Review Report: epic-191-a3-path-ownership

- Attempt: 2
- Round: 2
- Input hashes: requirements `ae87f0f246de8d2c3fdccafe71545bd6f5d4f40c4fba19aa8192134a57d0658c`, acceptance tests `d455fd5f8596c43b79fb92e42b6e18a95ac493d0789a61087679b657669b93e8`
- Reviewer A: run `RUN-epic-191-a3-path-ownership-spec-spec-reviewer-a-a2r2-seq0665`, host session `SESS-spec-spec-reviewer-a-epic-191-a3-path-ownership-a2r2-0665`
- Reviewer B: run `RUN-epic-191-a3-path-ownership-spec-spec-reviewer-b-a2r2-seq0666`, host session `SESS-spec-spec-reviewer-b-epic-191-a3-path-ownership-a2r2-0666`
- Verdict: `NEEDS_WORK`
- Warning count: 0

Round 2 was opened after the human applied the staged candidate set (commit
`710d6746`), including the narrowed `spec-review-precheck.{sh,ps1}` whose
`validate_reviewer_output` accepts a declared NEEDS_WORK or BLOCKED whenever
FAIL findings exist (a declared PASS carrying a FAIL is still rejected). That
narrowing lifted the round-2 deadlock documented in the a2r1 report: this
round's precheck validated the a2r1 reviewer-b record without error. The
specification amendment under review is `ec45cd29`, which addressed all three
a2r1 findings; the `--edit-summary` in `precheck-result.json` describes it.

## Findings

Reviewer A: verdict `PASS` — 6 PASS, 0 FAIL, 1 SKIP (DOMAIN-CONFORMANCE, no
`domain/` directory). Reviewer A found all three a2r1 findings resolved,
including RISK-VALIDATION-SURFACE, whose gap is now bound to the
TEST-035a/b/c three-way fixture.

Reviewer B: verdict `NEEDS_WORK` — 4 PASS, 2 FAIL (both Major), 1 SKIP.
Reviewer B confirmed the a2r1 Critical CONTRADICTION and Major
EDGE-CASE-COVERAGE findings resolved, but surfaced one new gap reported under
two check IDs:

1. Major — `AMBIGUITY` (reviewer B): requirements.md REQ-004's applicability
   derivation ties the Gate's config read to "the ADR-0016 file-absence
   fallback" only; investigation.md INV-016 confirms that fallback applies
   ONLY when `project-context.yaml` itself is absent — never to a file that
   is present but malformed. The 2026-08-11 amendment pins down the
   fail-closed rule for check-contract's own tier-minimum predicate (file
   presence, no YAML parser), but requirements.md never states the
   equivalent rule for the Gate itself: if the Gate's own YAML read throws
   on a malformed `sdd/project-context.yaml`, one implementer could
   hard-crash (no evidence, correctly failing check-contract) while another
   could catch the exception and reuse the file-absence fallback path,
   emitting a genuine `passes:true` / `state: "not-applicable
   (disabled-legacy)"` record. AC-055's producer-digest check verifies
   script identity, not config validity, so that genuine record would
   satisfy AC-035's active tier-minimum requirement even though the config
   was broken — silently reopening, for the Gate's own config read, the
   exact "caught parse exception... disarms the minimum" regression that
   Problems/AC-035 explicitly guard against for check-contract.
2. Major — `DOWNSTREAM-READINESS` (reviewer B): the same gap leaves a
   security-relevant product decision unmade — what
   `check-component-coverage.py` itself must do when its own `--config
   project-context.yaml` is present but malformed (crash vs. reuse the
   file-absence disabled-legacy fallback). A design/implementation-policy
   reviewer inheriting this spec would have to invent this behavior rather
   than verify an implementation against a stated requirement, and the
   choice determines whether AC-035's "fail-closed for a malformed config"
   guarantee holds end-to-end.

All other checks from both reviewers (REQ-TESTABILITY, GOAL-AC-TRACE,
AC-OBSERVABLE, SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE,
CONTRADICTION, EDGE-CASE-COVERAGE, ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY)
passed; DOMAIN-CONFORMANCE was SKIP for both (no `domain/` directory).

## Transition

Merged verdict `NEEDS_WORK` with zero Critical findings. Round 3 of this
attempt remains available and requires a human-directed specification edit
resolving the Gate-side malformed-config behavior, plus a non-empty
`--edit-summary`. Per the state table, a round-3 Major/Critical finding
produces BLOCKED, so the amendment must state the Gate's own
present-but-malformed contract (and, if warranted, an acceptance surface for
it) before round 3 is invoked. `Spec-Review-Status` remains `Pending`; no
status field was modified this round.
