# Task Review Report: epic-189-a1-project-context — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-189-a1-project-context |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 4 |
| Minor Findings | 0 |
| Generated | 2026-07-22T11:45:00Z |

## Reviewer-A Findings (Structural Coverage)

None. All 14 checks PASS (PREREQ-AC-IDS, BLOCKERS-FORMAT, REQ-COVERAGE,
AC-COVERAGE, ORPHAN-TASK, ORPHAN-TEST, INITIAL-STATE, RISK-WORKFLOW-FORMAT,
NO-DUPLICATE-AC, DEPENDENCY-COMPLETE, DEPENDENCY-CYCLE, SINGLE-CONCERN,
OBSERVABLE-DONE, TRACEABILITY-SYNC).

## Reviewer-B Findings (Quality/Risk)

1. **RISK-APPROPRIATE (Major) — T-010**: `Risk: medium` is under-classified.
   T-010 implements the identical ADR-0023 track-selection precedence /
   `PROJECT_CONTEXT_INVALID`-stop decision logic that T-011 (`Risk: high`)
   implements for the other 2 of the same 5 REQ-009 consumers. T-010's own
   Risk Rationale claims "no new security-decision logic" but its Goal
   describes exactly the four-case decision branch being added.

2. **TASK-SIZE (Major) — T-004**: bundles a JSON Schema
   (`contracts/approver-registry.schema.json`) and a separate algorithmic
   script (`detect-policy-weakening.py`) under one task; 11 Done-When items
   exceeds the 8-item oversized threshold. T-001 (11 items) and T-003 (9
   items) show the same pattern less severely.

3. **SCOPE-DISJOINT (Major) — T-002 (representative)**: the mandatory
   serialized-append rule for `tests/run-all.sh`/`.ps1` and the staged
   `.github/workflows/test.yml` + `MANIFEST.sha256` is not enforced via the
   `Blockers` field for every task that shares those files.

4. **DEPENDENCY-OVERLAP (Major) — T-010 (representative)**: the
   numeric-order Blockers chain for the same shared files is non-transitive
   at several points (T-008 omits T-001; T-010 omits T-008/T-009; T-011
   omits T-009; plus the SCOPE-DISJOINT gaps above).

## Proposed Changes

1. **T-010**: `Risk: medium` → `Risk: high`, `Required Workflow:
   acceptance-first` → `tdd`, revise Risk Rationale to acknowledge the
   ADR-0023 precedence/`PROJECT_CONTEXT_INVALID` logic as security-decision
   surface (parity with T-011), and add the high-tier Done-When evidence
   items (TDD Red/Green + independent quality-gate verdict).
2. **T-004**: split into two tasks — a schema-only task
   (`contracts/approver-registry.schema.json`, AC-044/045/046) and a
   detector-algorithm task (`detect-policy-weakening.{py,sh,ps1}`,
   AC-016/017/018/030/031) — renumbering T-005 through T-012 by one to keep
   a contiguous numeric sequence, and updating every cross-reference
   (Blockers, Requirements, traceability.md, Global Constraints' numeric
   append order) accordingly. T-001/T-003 are left as-is per the
   orchestrator's own judgment call, recorded below.
3. **Blockers chain**: make the shared-file (`tests/run-all.sh`/`.ps1`,
   staged `test.yml`, `MANIFEST.sha256`) numeric-order chain fully
   transitive — every task that registers a new suite blocks on the
   immediately-preceding numeric-order task that also touches these files,
   so the full chain is unbroken from the first suite-registering task
   through the last.

### Orchestrator judgment on T-001/T-003 (not split)

T-001 (11 Done-When items, REQ-001+REQ-002) and T-003 (9 items,
REQ-004's schema+signer) were flagged by reviewer-b as showing "the same
pattern less severely" but were NOT included in reviewer-b's `findings[]`
array (only T-004 was) — reviewer-b's own check text frames them as
observational parallels supporting the T-004 finding, not independent
Major findings requiring their own fix. Both also have a design-level
single-artifact-pair rationale distinct from T-004's two-unrelated-artifact
bundling: T-001's two schemas share one acceptance-test suite and one
cross-schema semantic check (TEST-040 tests both together) and design.md's
own Technical Summary groups them as "the two YAML schemas"; T-003's
schema+signer are a single content-and-its-signer pair with no independent
downstream consumer of the schema alone. Splitting either would create an
artificial schema-only task with no test suite of its own (T-001) or break
the schema-definition/signer-implementation pairing TDD's Red phase relies
on (T-003). No change made to T-001/T-003 this round; reviewer-a's own
TASK-SIZE-adjacent SINGLE-CONCERN check (a different check, structural
coverage side) already passed both without qualification.

## Next Steps

Round 1 of 3. Apply the changes above to `tasks.md`/`traceability.md`, then
re-invoke task-review-loop with `--edit-summary` describing the changes
made (round 2, `--edit-summary` required per the SKILL).
