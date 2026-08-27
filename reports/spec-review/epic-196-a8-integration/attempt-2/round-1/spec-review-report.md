# Specification Review Report: epic-196-a8-integration

- Attempt: 2
- Round: 1
- Lane: amendment re-review (reset lane, `--reset`; previous attempt terminal verdict: PASS). The
  package carries a conforming `## Amendment Re-Review Context` entry in
  `specs/epic-196-a8-integration/investigation.md`; both reviewers recognized it and applied the
  calibration's scoped suppression. The findings below stand on their own defect basis and are not
  of the suppressed phase-sequencing class.
- Input hashes: requirements `2e3b141c051d7a198530635ad409f4616bd717d2fe3f6dfeff6632954e15562e`, acceptance tests `eccb74b87747529947540ff290184b5bc7f3111f49d18252b2f8b1bbc5d872cb`, investigation `6bd0c353f774d4c736965fe39e33b8df62bb895c46fa5de1950b028a6bd40209`
- Reviewer A: run `RUN-epic-196-a8-integration-spec-reviewer-a-a2r1-seq773`, host session `SESS-spec-a-epic-196-a8-integration-a2r1-seq773`, allowed input manifest: `specs/epic-196-a8-integration/requirements.md`, `specs/epic-196-a8-integration/acceptance-tests.md`, `specs/epic-196-a8-integration/investigation.md`, `plugins/sdd-review-loop/references/spec-review-calibration.md`, `reports/spec-review/epic-196-a8-integration/attempt-2/round-1/precheck-result.json`
- Reviewer B: run `RUN-epic-196-a8-integration-spec-reviewer-b-a2r1-seq774`, host session `SESS-spec-b-epic-196-a8-integration-a2r1-seq774`, allowed input manifest: same 5 files as Reviewer A plus `reports/spec-review/epic-196-a8-integration/attempt-2/round-1/integrated-summary.json` (sanitized counts/IDs only)
- Verdict: `NEEDS_WORK`
- Warning count: `0`
- Finding counts: Critical 2, Major 1, Minor 0

## FAIL findings

Both reviewers independently converged on the same root defect from blind contexts.

### Reviewer A — REQ-TESTABILITY (Critical)

requirements.md's own Assumptions section (requirements.md:720-724) states Epic A1 "remains
unmerged... its own hook-activation handshake script (`check-hook-activation-handshake.{py,sh,ps1}`)
and five migrated consumer entry points (INV-007) do not exist on `main` yet. AC-006/AC-015/AC-016's
own `SKIP` status is the direct consequence" — directly contradicted by investigation.md's own
Amendment Re-Review Context (amendment commit `66d5bdde4cea01b2345f41eee2b4cfcbcf529301`), which
records Epic A1 merged on 2026-08-08 with those artifacts existing on `main` (independently
confirmed against the repository). A Phase 2/3 task author cannot determine from requirements.md
alone whether the SKIP status has already crossed AC-015's stated un-skip trigger, which gates
AC-028, a Foundation-wide Done and release gate.

### Reviewer B — CONTRADICTION (Critical)

Same defect, from B's independent context: the amendment completing commit fixed design.md's
Assumptions only; requirements.md:720-724 still asserts the false premise, a live factual
contradiction inside the Phase-1 reviewable surface governing a release-gate computation.

### Reviewer B — ASSUMPTIONS-RESOLVABLE (Major)

The Epic A1 assumption is neither resolved-and-true nor marked as a decision needed; it is silently
stale relative to investigation.md's own recorded fact.

## Next steps

Round 1 of 3: NEEDS_WORK. The prescribed remediation is an amendment to requirements.md's
Assumptions section stating Epic A1's actual merged status (flagging the original assumption as
superseded rather than silently rewriting it), mirroring the design.md remediation
`66d5bdde4cea01b2345f41eee2b4cfcbcf529301` — a frozen-document change requiring the human-approved
amendment lane, with the investigation.md Amendment Re-Review Context entry extended to cover the
new commit. Re-invoke round 2 with `--edit-summary` after the edit.
