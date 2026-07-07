# Proposed Changes — task-review ci-mcp attempt-1 round-2

Finding addressed: TASK-SIZE (Major) — T-005 が 5 ツール契約(AC-001..005)+
ジョブログ truncation を単一タスクに束ね、Done When 11 項目で 8 項目閾値超過。

## Change — T-005 を 3 タスクに分割

- **T-005** tools/actions.ts(run 系 2 ツール): `list_workflow_runs` /
  `get_workflow_run`(AC-001/AC-002、REQ-002)。Done When 8 項目。
- **T-012** tools/actions.ts(jobs / artifacts 系 2 ツール): `list_run_jobs` /
  `list_run_artifacts`(AC-003/AC-005、REQ-002)。Done When 8 項目。
- **T-013** tools/actions.ts(get_job_log + 256 KiB 末尾優先 truncation):
  AC-004、REQ-002 + REQ-008。Done When 7 項目。

3 タスクとも Risk: high / Required Workflow: tdd(公開 API 契約 sentinel)・
Blockers: T-002, T-003, T-004 を維持。依存側は T-006 / T-007 の Blockers を
`T-005, T-012, T-013` に、T-011 の Blockers に T-012, T-013 を追加。
併せて reviewer B の非ブロッキング指摘(T-004 Rollback の古い文言)を修正。

traceability.md の Task→REQ / AC→TEST→Task 表を同期(AC-003/005 → T-012、
AC-004 → T-013)。traceability.json は REQ→AC 中心スキーマのため変更不要
(JSON valid 確認済み)。

## 検証

- check-risk: 13 タスク PASS
- validate-layer-traceability: PASS
- AC-001..019 が Done When にちょうど 1 タスクずつ出現
- 分割後の Done When 項目数: T-005=8 / T-012=8 / T-013=7(全て ≤ 8)

## Disposition

Orchestrator applied the split exactly as recommended by reviewer B's TASK-SIZE
finding. No product decision involved. Round 3 (final) invoked.
