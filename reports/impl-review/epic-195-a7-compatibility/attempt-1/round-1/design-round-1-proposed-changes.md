# Implementation Policy Review Report: epic-195-a7-compatibility — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-195-a7-compatibility |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | PASS |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | 2026-07-22T10:45:19Z |

## Reviewer-A Findings (Structural Soundness)

- **DATA-COVERAGE (FAIL, Major)**: design.md's `## Data Plan` section
  (lines 148-237) states `Data Entities: none persisted by this task...`
  (line 150) and `Existing Data Affected: none...` (line 154), satisfying
  two of the three required sub-fields. However, no `Migration Strategy:`
  labeled sub-field appears anywhere in design.md — confirmed by grepping
  the file for `migrat`, which returns only an unrelated reference to
  "ADR-0023 (track-selection contract migration)" at line 141, never a
  Migration Strategy statement for this feature's own proposed additive
  schema changes (the `capability_applicability` field on the
  `quality-gate` loop-inventory entry, the new `capability` object in
  `emit-run-record.sh` output, and the new REQ-007
  allowlist-manifest/`compatibility-event-trace/v1` schemas). Although
  these are described elsewhere as additive/optional (Global Constraints,
  Constraint Compliance table), the Data Plan section itself never states
  "no migration required" with rationale for these proposed shape
  changes, as the check requires. A future Phase 2/3 implementer has no
  design-fixed Migration Strategy statement in the Data Plan section to
  follow when landing these additive fields.

All other reviewer-A checks (ARCH-COVERAGE, NO-CIRCULAR-DEPS,
API-COVERAGE, SECURITY-COVERAGE, TEST-STRATEGY-COVERAGE,
NO-UNDEFINED-COMPONENT, ADR-PRESENT) are PASS; FRONTEND-BACKEND-CONSISTENCY
is SKIP (no UI surface — see reviewer-a.json for rationale).

## Reviewer-B Findings (Implementability/Risk)

No FAIL findings. All 10 checks PASS (DECISION-JUSTIFIED,
OPEN-QUESTIONS-RESOLVABLE, ASSUMPTIONS-VALID, NO-REQ-CONTRADICTION,
PERF-ADDRESSED, DEPLOYMENT-CONCRETE, MIGRATION-PLANNED,
INTEGRATION-IDENTIFIED, DESIGN-WITHIN-SCOPE, VERIFICATION-PATH-CONCRETE).
Reviewer-B's own MIGRATION-PLANNED check independently reached PASS
because design.md's Data Plan wording is "functionally equivalent" to a
"No data changes" statement — a lower bar than reviewer-A's
DATA-COVERAGE check, which requires an explicit, separately-labeled
`Migration Strategy:` sub-field. The two checks are not contradictory:
reviewer-A's finding is the binding one for this round's outcome.

## Proposed Changes

Add a `Migration Strategy:` sub-field to design.md's `## Data Plan`
section (immediately after the existing `Existing Data Affected: none.`
sentence), stating "no migration required" with rationale grounded in
the design's own existing additive-only guarantees:

> **Migration Strategy:** No migration required. Every schema-shaped
> change this design proposes for a future implementation task is
> additive and optional with a documented backward-compatible default:
> the `capability_applicability` field on the `quality-gate`
> loop-inventory entry is absent-safe (Data Plan, above); the
> `emit-run-record.sh` `capability` object is gated behind an
> independent `emit_capability` flag with the no-flag heredoc staying
> byte-identical (AC-011); the new `compatibility-event-trace/v1`,
> `skip-allowlist-manifest/v1`, and `structural-fixture-corpus/v1`
> schemas are net-new files with no prior version to migrate from. No
> existing consumer of any touched file's current shape is broken by
> these additions (Constraint Compliance table, above).

## Next Steps

Per this task's orchestrator assignment ("findings が出たら spec を修正して再
attempt"), the orchestrator applies this remedy directly to design.md,
records an `--edit-summary`, and re-invokes the loop at round 2 (same
attempt 1) rather than waiting on separate human action — this is the
orchestrator's own delegated authority for this pipeline, not a
departure from SKILL.md's review-finding integrity rules (no finding is
waived; the remedy directly closes the cited gap).
