# WFI Audit Report — Cycle 1

## Header

| Field | Value |
|---|---|
| WFI-ID | WFI-045 |
| Category | app-dev-efficiency |
| Cycle | 1 of 2 |
| Auditor Agent | wfi-auditor-a |
| Verdict | NEEDS_REVISION |
| Critical Findings | 0 |
| Major Findings | 3 |
| Minor Findings (Advisory) | 1 |
| Generated | 2026-08-23T14:05:00Z |

## Verdict: NEEDS_REVISION

The mechanism is correctly identified and the derivation-based fix is the right shape.
Three findings, all of which make the WFI's own case stronger once corrected: the
incident was four discovery rounds rather than three, the baseline is presented as
continuing a retrospective series that has no row for it (and whose site count does
not match the tree), and the negative control nominates a suite that recursively
copies the whole scripts directory -- so it would have controlled for nothing.

---

## Check Results

| Check | Result | Severity |
|---|---|---|
| EVIDENCE-CITED | **FAIL** | Major |
| ROOT-CAUSE-PLAUSIBLE | PASS | Major |
| WHY-CHAIN-VALID | PASS | Major |
| CATEGORY-LANGUAGE-MATCH | PASS | Critical |
| CHANGE-CONCRETE | PASS | Major |
| EFFECT-MEASURABLE | PASS | Major |
| VERIFICATION-METRIC-DEFINED | **FAIL** | Major |
| VERIFICATION-PLAN-SPECIFIC | **FAIL** | Major |
| NO-PLUGIN-SCOPE-CREEP | PASS | Critical |

## Findings

### EVIDENCE-CITED — Major

Two evidence defects. (1) ROUND TABLE WRONG -- there were FOUR rounds, not three. The table places generate-registry-digest.tests.ps1 in round 2 alongside the capability-registry and facet-manifest twins, attributing all four files to 30449b41. The file's own history contradicts this: `git log -S'py-dispatch' -- tests/generate-registry-digest.tests.ps1` returns only 5aadb5de, and 30449b41's own subject line reads 'Stage lib/py-dispatch into the TWO remaining fixture-staging suites' -- two, not three. Author dates give four distinct events on 2026-08-22: d478775c 09:29, 5aadb5de 13:01 (PR #328 external review), 30449b41 13:12 (CI), 6a441c2b 13:25 (CI). All four are reachable from main. The correction strengthens the WFI's own argument -- four independent detection channels, with one suite's .sh and .ps1 twins split across two of them -- so the round count must be raised everywhere it appears, including the baseline. (2) UNREACHABLE SHA IN WHY-4. The chain's level 4 cites 915d1067 for the probe-then-source hardening. `git merge-base --is-ancestor 915d1067 HEAD` reports it is not an ancestor; the branch was rebased and the commit rewritten as 5aadb5de, which carries the identical subject and IS reachable. Cite the reachable SHA.

### VERIFICATION-METRIC-DEFINED — Major

Two defects. (1) The Baseline reads '3 rounds', which the round-table correction makes 4. (2) The metric is presented as though continuing an existing measurement series, but none exists: the Retention Check at reports/retrospective/2026-08-23T125111Z-wfi-application-horizon-check.md:126 records this class only as 'fixture-staging class | 2026-08-22 audit session (8 sites, CHANGELOG record)' with NO round-count row -- and its site count of 8 does not match the tree, which has 7. A baseline this WFI establishes from commit history should say so, and the 8-vs-7 discrepancy must be reconciled in writing rather than left for a reader to trip over. Live measurement by this audit: exactly seven files under tests/ mention py-dispatch, one staging reference each -- capability-registry-parity.tests.{sh,ps1} :146/:122, facet-manifest-parity.tests.{sh,ps1} :289/:297, generate-registry-digest.tests.{sh,ps1} :24/:23, ownership-digest.tests.ps1 :285. No eighth site exists.

### VERIFICATION-PLAN-SPECIFIC — Major

Step 4's negative control is vacuous. It nominates tests/guard-parity.tests.sh as 'a suite that copies a wrapper with no lib/ dependency'. That suite does not copy a wrapper: at :654-655 it does `cp -R "${REPO_ROOT}/plugins/sdd-quality-loop/scripts" ...` -- a recursive copy of the entire scripts directory, which carries lib/ along with everything else. It has no per-file staging list for the check to inspect, so it would be skipped for a reason unrelated to the property being controlled for, and the control would demonstrate nothing about discrimination. Two separate things are needed: a genuine negative control (a suite that names a file with no lib/ dependency and must not be flagged), and a distinct probe for the recursive-copy shape, which satisfies the invariant without declaring it and must therefore be classified satisfied rather than missing. The second is a real blind spot -- narrowing that cp -R to a file list later would drop the dependency silently -- and belongs in the suite's header comment. Steps 1-3 and 5-6 are specific and runnable.

## Proposed Revisions

Applied verbatim by the orchestrator, which is the only entity that writes WFI
content during an audit cycle.

**1. [Major] ## Problem Evidence (round table)**

Rewrite the round table as four rounds with author times: d478775c 09:29 (local), 5aadb5de 13:01 (PR #328 review, generate-registry-digest.tests.ps1), 30449b41 13:12 (CI, the capability-registry and facet-manifest twins), 6a441c2b 13:25 (CI, ownership-digest.tests.ps1). Renumber the masking narrative accordingly and note the correction strengthens rather than weakens the argument.

**2. [Major] ## Verification Metric**

Raise the Baseline to 4 rounds and list all four commits. Add a provenance paragraph stating this baseline is established here from commit history because the retrospective has no round-count row, and reconcile the retrospective's '8 sites' against the tree-measured 7, naming all seven with line numbers and stating plainly that no eighth was found.

**3. [Major] ## Verification Plan (step 4)**

Split the vacuous negative control into (a) a genuine control using a suite that stages a named file with no lib/ dependency, and (b) a separate recursive-copy probe asserting that the cp -R shape at guard-parity.tests.sh:654-655 is classified satisfied, with the blind spot recorded in the new suite's header comment.

**4. [Minor] ## Why-Why Analysis (level 4)**

Replace the unreachable SHA 915d1067 with 5aadb5de and add a note recording that the former was rewritten by a rebase.

---

## Bridge to Cycle 2

`WFI-045-integrated-summary.json` carries counts and check IDs only. The Cycle-2
auditor (`wfi-auditor-b`) is a fresh isolated agent and does not read this report
or the raw Cycle-1 output.
