# Specification Review Report: epic-194-a6-lite-integration — Attempt 4 / Round 2

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Attempt | 4 |
| Round | 2 of 3 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 1 |
| Major Findings | 3 |
| Minor Findings | 0 |
| warningCount | 0 |

Round 1 returned NEEDS_WORK on three findings; all three were remediated and
re-reviewed here. Two remediations hold. The third introduced a new defect,
and both reviewers found it independently while blind.

`Spec-Review-Status` remains `Pending` because this round did not pass.

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
| `CONTRADICTION` | FAIL | Critical |
| `EDGE-CASE-COVERAGE` | PASS | Major |
| `ASSUMPTIONS-RESOLVABLE` | FAIL | Major |
| `APPROVAL-BOUNDARY` | PASS | Critical |
| `DOWNSTREAM-READINESS` | PASS | Major |
| `DOMAIN-CONFORMANCE` | SKIP | Major |

## Findings, verbatim

### CONSTRAINTS-EXPLICIT (Major) — reviewer A

requirements.md:972-986 (Roles and Permissions, 'Epic A2's own Phase 2 implementer' bullet) names four target files in its intro sentence (contracts/capability-registry.schema.json, contracts/capability-registry.json, contracts/lite-check-catalog.json, contracts/lite-upgrade-reason-catalog.json) but its protection-status accounting covers only 'three paths' -- two already-protected (naming only the schema file and the reason-catalog) plus one needing new registration (lite-check-catalog.json) -- and never states contracts/capability-registry.json's protection status at all. This directly contradicts the Non-goals bullet in the same document (requirements.md:683-694, this same round's remediation), which explicitly lists contracts/capability-registry.json as one of exactly three R-10-protected contracts/ paths, grounded in the same investigation.md Amendment Re-Review Context (third entry, 2026-08-25) citation confirming all three -- capability-registry.schema.json, capability-registry.json, and lite-upgrade-reason-catalog.json -- are listed in guard-invariants.json's protected_gate_suffixes and phase2_human_copy_targets. Downstream failure mode: the Epic A2 Phase 2 implementer -- the role this bullet is written for -- cannot determine from this section alone whether contracts/capability-registry.json needs human-copy staging, fresh registration, or is out of scope, and would reasonably drop it from applied scope, contradicting Non-goals elsewhere in the same reviewed package. This belongs to spec review because it is a Phase-1 internal-consistency defect within requirements.md itself. Calibrated Major rather than Critical because the correct fact is fully recoverable from Non-goals in the same document and does not fall into spec-review-calibration.md's narrower Critical categories (contradictory goals / impossible AC / unsafe workflow boundary / missing approval boundary).

### AMBIGUITY (Major) — reviewer B

requirements.md Roles and Permissions (Epic A2 Phase 2 implementer bullet) names four contracts/ paths in its opening sentence (capability-registry.schema.json, capability-registry.json, lite-check-catalog.json, lite-upgrade-reason-catalog.json) but then refers to 'the three paths that edit touches' and enumerates only two as already-protected plus one needing new registration -- contracts/capability-registry.json is never accounted for again, leaving a reader unable to determine whether it is bundled under the schema.json mention or silently dropped.

### CONTRADICTION (Critical) — reviewer B

The same Roles and Permissions passage's literal enumeration of 'two...already R-10 protected' (capability-registry.schema.json, lite-upgrade-reason-catalog.json) omits contracts/capability-registry.json, contradicting Non-goals bullet 1's explicit, investigation.md-grounded claim (investigation.md lines ~1439-1448, Amendment Re-Review Context third entry) that all three named contracts/ paths, including capability-registry.json, are already R-10 protected under both protected_gate_suffixes and phase2_human_copy_targets.

### ASSUMPTIONS-RESOLVABLE (Major) — reviewer B

The REQ-006 fixture-grounding Assumption's 'must be synthetic' bucket groups fixtures (a), (d), (e) under the rationale that the live Registry lite_policy schema's additionalProperties:false blocks required_lite_checks, but (d) and (e) (per REQ-006's own text and acceptance-tests.md TEST-016/TEST-018) exercise lite-gate's consumption of contracts/capability-summary.schema.json's own required_lite_checks field -- an A4-owned field already shipped as required (investigation.md INV-005) and unrelated to the Registry lite_policy boundary cited. The bullet omits the actual reason (d)/(e) can't be grounded: no capability-summary.yaml exists anywhere yet because Epic A5's Resolver has not shipped/run.

## Proposed Changes

Not applied. Round 3 is the last permitted round of this attempt, and the
decision on how to close these belongs to the orchestrator/human.

1. **Roles and Permissions omits `contracts/capability-registry.json`**
   (A Major, B Major + B Critical — found independently, blind). The round-1
   remediation replaced a wrong claim with an unenumerated count: "Of the
   three paths that edit touches" against an opening sentence that names
   four. This is the same failure mode as round 1 finding 1 — a reference
   that does not carry its own referents — one notch over, from positional
   ("the first three of those named") to bare count ("the three paths").
   The fix is to enumerate all four paths and give each its own protection
   status.
2. **The fixture split cites the wrong mechanism for (d) and (e)**
   (B Major). Both exercise `capability-summary.schema.json` s own
   `required_lite_checks` — an A4-owned field already shipped as required
   (investigation.md INV-005) — not the Registry `lite_policy` boundary the
   bullet cites. The bucket assignment is right; the reason is wrong. The
   actual reason is that no `capability-summary.yaml` exists anywhere
   because Epic A5 s Resolver has not shipped, a separate and still-Pending
   prerequisite the bullet never states.

Both remediations that held: Non-goals bullet 1 (explicit three-path naming,
verified against the cited investigation.md entry) and the (b)/(c)/(j)/(f)/
(g)/(h)/(i)/(k)/(l) portions of the fixture split, which reviewer A checked
fixture-by-fixture and found correct and exhaustive.

Reviewer B was also asked directly whether the deliberately-omitted
test-isolation rationale left the split incomplete, and answered no: the
per-fixture split is strictly more precise than a blanket rule, and the
defect is in its execution, not in declining the fallback.

## Next Steps

1. Decision required before round 3, which is the last round of attempt 4.
2. `requirements.md` remains `Spec-Review-Status: Pending`; impl and task
   stay blocked behind it.
