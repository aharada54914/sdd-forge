# Implementation Policy Review Report: epic-194-a6-lite-integration — Round 2 / Attempt 2

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Round | 2 of 3 |
| Attempt | 2 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical / Major / Minor | 0 / 1 / 0 |

Both of round 1 findings were remediated, and because the remediation changed
requirements.md it went through a full spec re-review (attempt 5 round 1, clean
PASS from both spec reviewers). The precheck reports DESIGN-REQ-DRIFT for that
reason.

**DEPLOYMENT-CONCRETE is closed.** Both reviewers verified the new scoping
paragraph in design.md Deployment / CI Plan independently and both accepted it.

**ASSUMPTIONS-VALID is not closed.** Reviewer B found a twelfth
INV-013-dependent site that every prior sweep missed.

## Reviewer-A Results

| Check | Result | Severity |
|---|---|---|
| `ARCH-COVERAGE` | PASS | Critical |
| `NO-CIRCULAR-DEPS` | SKIP | Major |
| `DATA-COVERAGE` | PASS | Major |
| `API-COVERAGE` | PASS | Major |
| `SECURITY-COVERAGE` | PASS | Major |
| `FRONTEND-BACKEND-CONSISTENCY` | SKIP | Major |
| `TEST-STRATEGY-COVERAGE` | PASS | Major |
| `NO-UNDEFINED-COMPONENT` | PASS | Critical |
| `ADR-PRESENT` | PASS | Major |
| `DESIGN-SYSTEM-CONFORMANCE` | PASS | Major |
| `DOMAIN-CONFORMANCE` | PASS | Major |

## Reviewer-B Results

| Check | Result | Severity |
|---|---|---|
| `DECISION-JUSTIFIED` | PASS | Major |
| `OPEN-QUESTIONS-RESOLVABLE` | PASS | Major |
| `ASSUMPTIONS-VALID` | FAIL | Major |
| `NO-REQ-CONTRADICTION` | PASS | Critical |
| `PERF-ADDRESSED` | PASS | Major |
| `DEPLOYMENT-CONCRETE` | PASS | Major |
| `MIGRATION-PLANNED` | PASS | Major |
| `INTEGRATION-IDENTIFIED` | PASS | Major |
| `DESIGN-WITHIN-SCOPE` | PASS | Major |
| `VERIFICATION-PATH-CONCRETE` | PASS | Major |
| `DOMAIN-CONFORMANCE` | SKIP | Major |

## Findings, verbatim

### ASSUMPTIONS-VALID (Major) — reviewer B

The 2026-08-25 repair of the falsified INV-013 premise (investigation.md, Amendment record extension, third entry) missed one site: design.md's own Assumptions section, first bullet, still reads (design.md:1168-1171, verbatim): A2's design.md text (the source for this feature's own lite_policy/catalog schema fragments, since no live contracts/capability-registry.schema.json exists yet) will not change in a way that breaks this design's own citations before this feature's own spec review completes. This directly contradicts the same document's own corrected Cross-Layer Dependencies section (design.md:346-354): A2's own Phase 2 has landed, contracts/capability-registry.schema.json, contracts/capability-registry.json and contracts/lite-upgrade-reason-catalog.json are live as of e48c9008 (2026-07-23), independently re-verified against the live file per the same paragraph. A repo-wide grep for the residual phrase (since no live contracts/capability-registry...exists yet) across every manifest document returns exactly this one hit; every other site the third amendment entry enumerated (design.md header, Components table row 1, Protected-File Statement, Cross-Layer Dependencies, Layer Specifications; requirements.md Dependencies/Non-goals/Assumptions; traceability.md; frontend-spec.md) is correctly corrected, and the three further sites named for this round (design.md lite-check-catalog.json registration scheduling at :307-323, security-spec.md Authorization row at :108, infra-spec.md Rollback bullet at :163-177) are also all correctly repaired and internally consistent with investigation.md's own recorded live-file verification. design.md's own Assumptions section -- the literal site this check is named for -- was not in the enumerated Sites-amended-by-this-entry list and still asserts the withdrawn premise as a live fact grounding a still-open assumption. Concrete failure mode: an implementer or later reviewer reading only this section is told the Registry schema file does not exist, when design.md's own Cross-Layer Dependencies section says it is live and content-verified -- an internal self-contradiction inside the same, already-remediated document, of exactly the class this round exists to close out. Fix: apply the same correction pattern used at the other sites (state that the file is live as of e48c9008/2026-07-23, cite investigation.md INV-013 as superseded by the Amendment Re-Review Context's third entry, and restate that this design's citations are grounded in A2's design.md text, independently re-verified to match the shipped file) to design.md:1168-1171.

## Proposed Changes

Not applied. design.md is a frozen, human-approved document and the decision
belongs upstream.

The site reviewer B found, design.md ## Assumptions first bullet, still reads
"since no live contracts/capability-registry.schema.json exists yet", which
contradicts the same document own corrected Cross-Layer Dependencies section.

An orchestrator sweep run after the round, joining wrapped lines before
matching, confirmed that site and surfaced one more: tasks.md quotes the
superseded requirements.md Assumptions text ("No Capability Pack exists yet
anywhere in this repository... every fixture...") which the per-fixture split
replaced. tasks.md is frozen and hash-bound; the quotation is of a prior state.

## Why the earlier sweeps missed it

The phrase spans a line break inside a backticked path — the source reads
"contracts/capability-registry." then a newline then "  schema.json` exists
yet". Every sweep so far matched line by line, so no single-line pattern could
ever hit it. A sweep must join wrapped lines before matching. An intermediate
version of the joined sweep also split sentences on ".", which the dots inside
filenames defeated; the working form flattens whitespace and matches trigger
phrases with a fixed window, without sentence-splitting or filtering.

## Next Steps

1. Upstream decision on the design.md Assumptions bullet and the tasks.md
   quotation.
2. Round 3 is the last round of this attempt.
