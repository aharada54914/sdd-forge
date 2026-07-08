# Task Review Report: evidence-deep-verify — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | evidence-deep-verify |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 3 |
| Minor Findings | 0 |
| Generated | 2026-07-08T14:35:00Z |

## Reviewer-A Findings (Structural Coverage)

None — all 14 checks PASS (findings: []).

## Reviewer-B Findings (Quality/Risk)

### RISK-APPROPRIATE | T-004 | Major

T-004 is Risk: medium but its Scope modifies the externally-visible MCP tool
contract (contracts/sdd-forge-mcp-tools.v1.schema.json, evidenceDeepVerifyData)
and registers a new externally-callable tool in server.ts (REQ-012).
risk-classification-policy.md lists 'public API contracts' as a high-tier
sensitive surface; T-004's own Risk Rationale acknowledges client-facing impact
but stops short of Risk: high, leaving the high-tier
tdd/independent-review/requirement-traceability minimum unmandated for the task
that ships the contract change.

### TASK-SIZE | T-001 (and T-002) | Major

T-001's Done When list has 11 distinct verifiable items (AC-002/003, AC-004,
AC-005, AC-017, AC-018, canonical-digest formula match, Red→Green evidence,
independent review verdict, provenance bundle, implementation report, quality
gate pass), exceeding the '>8 distinct verifiable items' oversized-task
indicator. T-002's Done When list is likewise 11 items (AC-006, AC-007, AC-008,
AC-009/010, AC-019, spec_revision formula match, plus the same 5 process
items), same defect.

### SCOPE-DISJOINT | T-002 vs T-003 | Major

T-002 and T-003 both list 'mcp/sdd-forge-mcp/src/tools/evidence.ts' as scope
but neither blocks the other (both Blockers: T-001 only), permitting
uncoordinated parallel edits to the same production source file.

## Proposed Changes

1. **T-004 re-classification (RISK-APPROPRIATE)**: `Risk: medium` →
   `Risk: high`, `Required Workflow: acceptance-first` → `tdd` (risk-gate-matrix:
   high → tdd). Update Risk Rationale to name the public-API-contract sentinel
   surface. Add the high-tier mandatory Done When items (Red→Green evidence,
   independent review verdict, provenance evidence bundle) per
   HIGH-CRITICAL-EVIDENCE.

2. **T-001 / T-002 Done When consolidation (TASK-SIZE)**: merge semantically
   adjacent verification items without dropping any observable criterion:
   - T-001: fold AC-004 / AC-005 / AC-017 (read-failure and invalid-recorded-sha
     classification family) into one item; fold provenance bundle +
     implementation report + quality gate into one gate item. 11 → 7 items.
   - T-002: fold AC-007 / AC-008 (git_commit shape family) into one item; fold
     provenance bundle + implementation report + quality gate into one gate
     item. 11 → 8 items.

3. **T-003 serialization (SCOPE-DISJOINT)**: change T-003 `Blockers: T-001` →
   `Blockers: T-001, T-002` so edits to
   `mcp/sdd-forge-mcp/src/tools/evidence.ts` are strictly ordered
   T-001 → T-002 → T-003 → T-004 (same serial-Blockers-chain remedy as the
   ci-mcp T-005/T-012/T-013 precedent).

## Next Steps

Apply the proposed edits to specs/evidence-deep-verify/tasks.md, then re-invoke
the task-review loop as round 2 with an edit summary describing the changes.
