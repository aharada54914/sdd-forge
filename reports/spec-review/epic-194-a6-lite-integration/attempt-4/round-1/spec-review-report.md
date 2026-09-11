# Specification Review Report: epic-194-a6-lite-integration — Attempt 4 / Round 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-194-a6-lite-integration |
| Attempt | 4 |
| Round | 1 of 3 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 1 |
| Major Findings | 2 |
| Minor Findings | 0 |
| warningCount | 0 |

This round was opened with `spec-review-precheck.sh epic-194-a6-lite-integration
4 1 --reset` after `requirements.md` was corrected under the 2026-08-25 human
ruling on INV-013's falsified Phase-1 premise. The reset set
`Spec-Review-Status: Pending`; because this round did not pass, **the header
remains `Pending`** and is reported as an open item rather than restored.

The two reviewers ran blind. Reviewer B received only `integrated-summary.json`
— reviewer A's seven check IDs, results and severities, with no finding text —
and never reviewer A's report.

**Both reviewers independently found the same defect in the amended Non-goals
bullet.** That convergence, reached without shared context, is the strongest
signal in this round.

## Reviewer-A Results (requirements and acceptance coverage)

| Check | Result | Severity |
|---|---|---|
| `REQ-TESTABILITY` | PASS | Critical |
| `GOAL-AC-TRACE` | PASS | Major |
| `AC-OBSERVABLE` | PASS | Major |
| `SCOPE-BOUNDARY` | PASS | Major |
| `CONSTRAINTS-EXPLICIT` | FAIL | Critical |
| `RISK-VALIDATION-SURFACE` | PASS | Major |
| `DOMAIN-CONFORMANCE` | SKIP | Major |

## Reviewer-B Results (risk and ambiguity)

| Check | Result | Severity |
|---|---|---|
| `AMBIGUITY` | PASS | Major |
| `CONTRADICTION` | FAIL | Major |
| `EDGE-CASE-COVERAGE` | PASS | Major |
| `ASSUMPTIONS-RESOLVABLE` | FAIL | Major |
| `APPROVAL-BOUNDARY` | PASS | Critical |
| `DOWNSTREAM-READINESS` | PASS | Major |
| `DOMAIN-CONFORMANCE` | SKIP | Major |

## Findings, verbatim

#### CONSTRAINTS-EXPLICIT (Critical) — reviewer A

requirements.md's amended Non-goals, first bullet, states: 'all four exist today and belong to Epic A2/A4 ..., and the first three of those named are R-10 protected in the live guard-invariants.json (protected_gate_suffixes and phase2_human_copy_targets)' -- the four named files, in listed order, are contracts/capability-registry.schema.json, contracts/capability-registry.json, contracts/capability-summary.schema.json, contracts/facet-manifest.schema.json, so 'the first three' asserts capability-summary.schema.json is R-10 protected. The same sentence cites 'the Amendment Re-Review Context's third entry, 2026-08-25' as its authority. But that entry's own 'What changed is access, not shape' paragraph (investigation.md, Amendment Re-Review Context, third entry) states the actual three R-10-protected files are 'contracts/capability-registry.schema.json, contracts/capability-registry.json and contracts/lite-upgrade-reason-catalog.json' -- a materially different third file (lite-upgrade-reason-catalog.json is not even one of the four files this Non-goals bullet enumerates), and capability-summary.schema.json is never described anywhere in investigation.md as R-10/guard-invariants-protected (grepped: it is only ever 'content-frozen'/A4-owned, INV-005). Downstream failure mode: a future implementation task deciding which of the four now-existing contracts files require human-copy staging vs. a direct/other application path, relying on this bullet's cited authority, will be told capability-summary.schema.json is protected by a citation that, read directly, says something else. This is a self-contained contradiction between two Phase-1 documents this gate owns (requirements.md and its own cited investigation.md section), discoverable by reading them side by side -- not an implementation-time question, and not resolvable by later-phase evidence. Separately, and not part of this FAIL: the Assumptions bullet's INV-013-citation withdrawal ('No Capability Pack exists yet ... its former citation ... is withdrawn ... a Capability Pack is a distinct artifact from the Registry instance (ADR-0018)') was reviewed as the flagged judgment call. Its conclusion is defensible on the terms it states (Capability Pack vs. Registry-instance is a real, pre-existing distinction the package already uses elsewhere, e.g. 'Target Users'), and it honestly discloses the weakening ('synthetic is a weaker claim than when this bullet was written') rather than overclaiming; it does not independently justify a FAIL, though the argument would be stronger if it noted that the live durable-workflow Capability's lite_policy cannot yet carry required_lite_checks (the v1.1 field this feature designs), which is the sharper reason every REQ-006 fixture remains synthetic.


#### CONTRADICTION (Major) — reviewer B

requirements.md Non-goals, first bullet (:683-697, as amended 2026-08-25) asserts 'the first three of those named [capability-registry.schema.json, capability-registry.json, capability-summary.schema.json] are R-10 protected,' citing investigation.md's Amendment Re-Review Context third entry. That cited entry (investigation.md:1439-1448) instead names capability-registry.schema.json, capability-registry.json, and lite-upgrade-reason-catalog.json (not capability-summary.schema.json, and not in this bullet's four-file list at all) as the three files actually listed under protected_gate_suffixes/phase2_human_copy_targets. Separately, requirements.md's Roles and Permissions section (:964-972), which investigation.md's own 'Sites amended by this entry' enumeration (:1480-1526) does not list as touched, still directs the future Epic A2 implementer to 'register' lite-upgrade-reason-catalog.json and the capability-registry.schema.json edit 'as protected,' implying they are not protected today -- directly conflicting with the corrected Non-goals/Dependencies text and investigation.md's own evidence that both are already R-10 protected. Downstream failure: a future Epic A2 Phase 2 implementer or a task author scoping the guard-invariants.json diff for this feature's revision would receive two internally conflicting signals about which contracts/ files require fresh protection registration versus already carry it, and cannot resolve the conflict from requirements.md alone. This is a defect in the Phase 1 package's own corrected text (calibration: 'the cited implementation artifact does not actually contain what the amendment claims it contains' is not suppressed by the amendment-context declaration), not a later-phase concern. Major rather than Critical because the live guard-invariants.json mechanism enforces protection independently of this prose, so no actual safety bypass results -- only implementer-facing confusion about registration scope.

#### ASSUMPTIONS-RESOLVABLE (Major) — reviewer B

requirements.md Assumptions, 'No Capability Pack exists yet' bullet (:1184-1194, amended 2026-08-25) retains its conclusion ('every fixture this feature's REQ-006 names is synthetic') after withdrawing its INV-013 citation, substituting a Capability-Pack-vs-Registry-instance distinction (ADR-0018) as the new grounding. It concedes 'synthetic is a weaker claim than when written' but does not state which REQ-006 fixtures that weakening affects or resolve whether it still holds for all of them. investigation.md's own third-entry 'Shape verification' subsection (:1456-1462), cited nowhere in this Assumptions bullet, contains the actually dispositive fact -- the live lite_policy schema is still exactly the two-key {eligible, upgrade_reasons} shape, so no live Capability (including the real durable-workflow entry now shipped in contracts/capability-registry.json) can yet carry required_lite_checks -- which would fully justify why fixtures needing that field must stay synthetic, but says nothing about fixtures needing only eligible/upgrade_reasons (e.g. REQ-006 fixture (b), ineligible-Capability-forces-full-required). Downstream failure: whoever authors the REQ-006 tests/*.tests.sh fixtures at implementation time cannot tell from this Assumptions bullet alone whether any fixture could or should now be grounded in the real durable-workflow Capability instead of synthetic data, since the bullet's own concession is left unresolved rather than turned into a checkable boundary. This is a Phase 1 resolution gap in the requirements text itself, precisely the kind of assumption-resolution this amendment round exists to perform.


## Proposed Changes

Not applied in this round. All three findings land on text authored under the
2026-08-25 ruling, and one of them contests a judgment call that was the
orchestrator's rather than the human's, so none is remediated without a
decision.

1. **The Non-goals protected-file claim is factually wrong** (reviewer A
   Critical, reviewer B Major — same defect, found independently). The bullet
   enumerates four files and says "the first three of those named are R-10
   protected", which asserts `contracts/capability-summary.schema.json` is
   protected. The live `guard-invariants.json` lists
   `contracts/capability-registry.schema.json`,
   `contracts/capability-registry.json` and
   `contracts/lite-upgrade-reason-catalog.json` — the third is a file this
   bullet does not enumerate at all, and `capability-summary.schema.json`
   appears nowhere in `protected_gate_suffixes`. The correct fix is to name the
   three protected files explicitly instead of using a positional reference
   ("the first three of those named") carried over from a different list.

2. **A left-behind sibling in Roles and Permissions** (reviewer B, Major).
   `requirements.md`'s Roles and Permissions section still directs the future
   Epic A2 implementer to register `lite-upgrade-reason-catalog.json` and the
   `capability-registry.schema.json` edit "as protected", implying they are not
   protected today. Both already are. This site was not in the orchestrator's
   pre-write enumeration for the third amendment entry, and it is therefore a
   left-behind sibling of the very correction that was meant to close the class.

3. **The Assumptions bullet's unresolved concession** (reviewer B, Major). The
   `Capability Pack` bullet kept its conclusion while withdrawing its INV-013
   citation, and conceded that "synthetic" is now a weaker claim without saying
   which REQ-006 fixtures the weakening touches. Reviewer B does not call the
   reasoning unsound; it calls the concession unresolved, and points at a
   sharper available argument — the live `lite_policy` is still the two-key
   shape, so no shipped Capability can carry `required_lite_checks` yet.

   **This is a contested judgment call and must not be settled by the
   orchestrator editing it.** The withdrawal of the citation while retaining
   the conclusion was the orchestrator's own reading, not the human's ruling.

## Next Steps

1. Decision required on finding 3 before any round 2. Findings 1 and 2 are
   unambiguous factual corrections; finding 3 is a judgment the orchestrator
   made and a reviewer has now contested.
2. `requirements.md` currently reads `Spec-Review-Status: Pending`. It returns
   to `Passed` only on a clean merged PASS. Until then the impl and task stages
   stay blocked: `impl-review-precheck.sh` requires
   `Spec-Review-Status: Passed`.
3. Round 2 of attempt 4 is the permitted next invocation, with
   `--edit-summary`, reserving fresh ledger identities for both reviewers.
