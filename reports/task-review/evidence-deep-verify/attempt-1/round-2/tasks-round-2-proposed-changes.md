# Task Review Report: evidence-deep-verify — Round 2 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | evidence-deep-verify |
| Round | 2 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | 2026-07-08T15:10:00Z |

## Reviewer-A Findings (Structural Coverage)

None — all 14 checks PASS (findings: []). Round-1 fixes (T-004 high+tdd,
Done When consolidation, T-003 serialization) verified against the current
bytes.

## Reviewer-B Findings (Quality/Risk)

### TASK-SIZE | T-004 | Major

Scope spans 6 distinct implementation areas (server.ts, evidence.ts, contracts
schema, dist/, tests/tools/, tests/smoke/) exceeding the 3-area
single-coherent-unit threshold; title joins 4 concerns with '+' (tool
registration + contract + determinism + smoke), matching the multi-phase-title
oversized indicator.

## Proposed Changes

Split T-004 into three serial tasks (same remedy as the ci-mcp
T-005 → T-005/T-012/T-013 precedent):

1. **T-004 (narrowed)** — evidence_deep_verify ツール登録と統合応答。
   Scope: server.ts, evidence.ts, tests/tools (3 areas). AC-001 +
   error-envelope mapping. Risk: high / tdd (externally-callable tool
   registration). Blockers: T-001, T-002, T-003.

2. **T-007 (new)** — evidenceDeepVerifyData 契約加算(v1 後方互換)。
   Scope: contracts/sdd-forge-mcp-tools.v1.schema.json, tests/tools (2 areas).
   AC-015 (ajv conformance + error-envelope conventions). Risk: high / tdd
   (public API contract sentinel surface). Blockers: T-004.

3. **T-008 (new)** — 統合検証(決定論・tools/list スモーク)と dist 再ビルド。
   Scope: tests/tools, tests/smoke, dist (3 areas). AC-013 + AC-016 +
   dist-parity. Risk: medium / acceptance-first (verification + mandatory
   dist housekeeping; no new contract surface). Blockers: T-007.

Dependency chain becomes T-001 → T-002 → T-003 → T-004 → T-007 → T-008 →
T-005 → T-006. Update T-005 Blockers (T-004 → T-008) and T-006 Blockers
(add T-007, T-008). Update traceability.md: Task→REQ rows (T-004: REQ-001,
REQ-012; T-007: REQ-012; T-008: REQ-010, REQ-013) and AC→TEST→Task rows
(AC-013 → T-008, AC-015 → T-007, AC-016 → T-008); task count 6 → 8.

## Next Steps

Apply the split to specs/evidence-deep-verify/tasks.md and traceability.md,
then re-invoke the task-review loop as round 3 with an edit summary.
