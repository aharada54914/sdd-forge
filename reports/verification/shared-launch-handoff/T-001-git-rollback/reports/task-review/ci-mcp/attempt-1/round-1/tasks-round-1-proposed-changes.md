# Proposed Changes — task-review ci-mcp attempt-1 round-1

Findings addressed (reviewer B, both Major):

## Change 1 — RISK-APPROPRIATE: T-005 / T-007 を high / tdd に再分類

T-005(tools/actions.ts、5 ツールの request/response 形)と T-007
(contracts/ci-mcp-tools.v1.schema.json、正準契約)は外部クライアントが直接
消費する公開 API 契約であり、risk-classification-policy.md の sentinel surface
(public API contracts)に該当する。両タスクを `Risk: high` /
`Required Workflow: tdd` に変更し、Risk Rationale を sentinel 根拠で書き換え、
high tier の Done When 3 項目(Red→Green evidence 記録 / 独立レビュー verdict
PASS の記録 / provenance(spec_revision 含む)付き evidence bundle)を追加した。
Rollback フィールドは両タスクとも既存。

## Change 2 — DEPENDENCY-OVERLAP: T-004 の Blockers T-002 → T-001

repo-resolve.ts は自己完結モジュールで github-client.ts の成果物に依存しない
(実消費関係は T-005 の Blockers: T-002, T-003, T-004 が既に捕捉)。T-004 の
Blockers を scaffold(T-001)のみに変更し、T-002/T-003 と並行実施可能にした。

## Disposition

Orchestrator applied both changes exactly as recommended by reviewer B's
findings (risk re-classification per policy sentinel; spurious blocker
removal). No product decision was involved; OQ-001..004 remain open and
unchanged. Round 2 re-review invoked with `--edit-summary`.
