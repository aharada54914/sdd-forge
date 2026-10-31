# Specification Review Report: epic-191-a3-path-ownership

- Attempt: 2
- Round: 1
- Input hashes: requirements `7b6dfba99151b0205288323b914075761a04b5dff747ffa89c1458f51e0f09c5`, acceptance tests `cb577b7f86364b505bb258c747058f39f458b60c862f3fd3d122f69652cd10d5`
- Reviewer A: run `RUN-epic-191-a3-path-ownership-spec-spec-reviewer-a-a2r1-seq0662`, host session `SESS-spec-spec-reviewer-a-epic-191-a3-path-ownership-a2r1-0662`
- Reviewer B: run `RUN-epic-191-a3-path-ownership-spec-spec-reviewer-b-a2r1-seq0663`, host session `SESS-spec-spec-reviewer-b-epic-191-a3-path-ownership-a2r1-0663`
- Verdict: `NEEDS_WORK`
- Warning count: 0

Attempt 2 was opened with `--reset` after the terminal attempt-1 round-3 PASS,
because requirements.md and design.md were amended on 2026-08-11 under an
explicit human ruling: the conditional tier-minimum activation staged as the
human-copy candidate (commit `eb427d60`) supersedes the previously prescribed
94-contract backfill as the sanctioned remedy for the NEW-001
required-check-set incompatibility. acceptance-tests.md and investigation.md
were not changed.

## Findings

1. Critical — `CONTRADICTION` (reviewer B): Security Boundaries
   (requirements.md, first bullet: "REQ-004's registration into
   `check-contract`'s protected required-check-set (INV-017) is the boundary
   that additionally prevents an unprotected `quality-gate/SKILL.md` edit from
   bypassing invocation") and Main Workflows step 4 ("so deleting the SKILL.md
   invocation, or substituting an unregistered script, does not bypass it")
   still state the reachability guarantee unconditionally, with no 2026-08-11
   supersession annotation — while the amended REQ-004 registration
   sub-bullet, AC-035, and Dependencies now state the same required-check-set
   membership activates only once `sdd/project-context.yaml` exists. In the
   `disabled-legacy` state (this repository's current state), an unprotected
   SKILL.md edit would not be caught by the mechanism Security Boundaries
   describes as unconditional. Internal contradiction within requirements.md.
2. Major — `RISK-VALIDATION-SURFACE` (reviewer A): the amended predicate's
   safety-critical properties (activation on presence, fail-closed on a
   malformed config, no YAML-parser participation) have no validation surface
   in acceptance-tests.md — no occurrence of `sdd/project-context.yaml` or
   "malformed" anywhere in that file; TEST-035 is unrevised and never varies
   config presence. No TEST id would catch a stuck-open (parser-exception →
   silently inactive minimum) or stuck-shut regression.
3. Major — `EDGE-CASE-COVERAGE` (reviewer B): the amendment introduces new
   load-bearing behavior (present/absent activation boundary), but
   acceptance-tests.md (unchanged from attempt 1) has no fixture variant for
   it, and requirements.md's own Edge Cases section has no entry for the
   transition; a Phase-2 task author has no acceptance-test anchor for the
   core mechanism of the remedy.

All other checks from both reviewers (REQ-TESTABILITY, GOAL-AC-TRACE,
AC-OBSERVABLE, SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT, AMBIGUITY,
ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY, DOWNSTREAM-READINESS) passed;
DOMAIN-CONFORMANCE was SKIP for both (no `domain/` directory).

## Observed validator/role-document discrepancy (unresolved; needs a human)

Reviewer B returned overall verdict `NEEDS_WORK` while reporting
`CONTRADICTION` as FAIL/Critical. The deterministic validator
`plugins/sdd-review-loop/scripts/spec-review-precheck.sh` (function
`validate_reviewer_output`, lines 185-186) derives an expected verdict from a
reviewer's own checks — `BLOCKED` when any check is FAIL with severity
Critical — and rejects a reviewer output whose declared verdict differs.
Observed read-only, 2026-08-11:

```
$ jq -r 'if ([.checks[] | select(.result == "FAIL" and .severity == "Critical")] | length) > 0
         then "BLOCKED" elif ([.checks[] | select(.result == "FAIL")] | length) > 0
         then "NEEDS_WORK" else "PASS" end' reviewer-b.json
BLOCKED
$ jq -r .verdict reviewer-b.json
NEEDS_WORK
$ jq -e '.verdict == (…derivation…)' reviewer-b.json >/dev/null; echo $?
1
```

Neither `plugins/sdd-review-loop/agents/spec-reviewer-b.md` nor
`plugins/sdd-review-loop/references/review-context-boundary.md` states this
severity-to-verdict derivation; the boundary reference enumerates BLOCKED
conditions as launch-boundary/manifest-integrity failures only. Reviewer B,
asked about the shape, declined to restate its verdict on the grounds that the
rule is absent from its role documents and that a validator/role-document
conflict belongs in front of a human. reviewer-b.json is persisted exactly as
the reviewer returned it. Consequence, stated factually: any future
`spec-review-precheck.sh` invocation that validates this round's contract
(round 2 of this attempt, or a later `--reset` into attempt 3) will fail its
`validate_reviewer_output` call against this reviewer-b.json until a human
resolves the discrepancy between the validator and the role documents.

## Transition

Round 2 requires human-directed specification edits and a non-empty
`--edit-summary`, and is additionally blocked by the validator/role-document
discrepancy documented above. The findings, and that discrepancy, go to the
human as they are.
