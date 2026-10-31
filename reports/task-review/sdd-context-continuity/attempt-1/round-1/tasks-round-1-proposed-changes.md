# Task Review Report: sdd-context-continuity — Round 1 / Attempt 1

## Verdict: BLOCKED

| Field | Value |
|---|---|
| Feature | sdd-context-continuity |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | BLOCKED |
| Reviewer-B Verdict | BLOCKED |
| Critical Findings | 2 |
| Major Findings | 3 |
| Minor Findings | 0 |
| Generated | 2026-09-27T05:18:43Z |

## Reviewer-A Findings (Structural Coverage)

- Critical / AC-COVERAGE: specs/sdd-context-continuity/tasks.md T-001–T-006 Requirements fields contain no AC identifiers; T-006 does not explicitly reference an AC either. AC-001–AC-018 in acceptance-tests.md therefore lack the task-level Requirements or explicit test-task AC coverage required by this check. traceability.md's indirect mapping does not declare deferrals. Add explicit, scope-differentiated task AC references; this Critical coverage gap blocks progression.
- Major / ORPHAN-TEST: specs/sdd-context-continuity/tasks.md T-006 explicitly owns full acceptance verification, but its Requirements field is REQ-001–012 and it contains no AC-NNN reference. TEST ranges alone do not meet the test-task AC-reference requirement. Add explicit AC ownership to prevent ambiguous verification linkage; this is a blocking Major structural gap.

## Reviewer-B Findings (Quality/Risk)

- Critical / HIGH-CRITICAL-EVIDENCE: tasks.md T-001–006 Done When and Global constraints require generic Red→Green/independent review but omit the mandatory pre-implementation failing-test commit and recording a named reviewer distinct from the implementer. A downstream task can satisfy the written completion items without those required high/critical controls. Add explicit planned completion evidence for both; this is a Critical mandatory-evidence omission.
- Major / ROLLBACK-PLAN: tasks.md T-001–005 have no Rollback field or rollback-related Done When item. infra-spec.md Rollback is not referenced as task-level completion evidence. Require safe-reversion evidence appropriate to each change, preserving expiry filtering and residual cleanup; otherwise high/critical completion lacks a verifiable rollback consideration.
- Major / DEPENDENCY-OVERLAP: tasks.md T-005 blocks on T-004 lifecycle adapters without identifying a consumed adapter artifact. Its cleanup/registry/shared-lock scope depends on T-001–003, and design.md Architecture gives the OS oneshot a direct cleanup invocation. The blocker unnecessarily postpones retention implementation until both hosts' lifecycle work completes. Bind the blocker to actual required producer artifacts or state the missing logical dependency.

## Proposed Changes

候補は tasks-round-1-human.patch。実際の tasks.md は変更していません。

1. 各タスクの Requirements に AC を明記。共通 AC は実装範囲を分け、T-006 は全 AC の検証担当として区別します。
2. 共通完了条件に、実装前の失敗テストのコミットと Red 結果、実装者とは別の名前付きレビュアー・run ID を追加します。
3. T-001〜T-005 に既存 infra-spec.md#rollback の安全な復旧・データ保護の検証を明記します。期限切れデータの復活や第三者データの削除は認めません。
4. T-005 は実際に利用する T-003 へ依存し、T-006 は T-004 と T-005 の両方へ依存します。同時実装の許可ではありません。

要件・設計・レイヤー・traceability の凍結内容、Approval: Draft、Status: Planned、過去の判定は維持します。

## Next Steps

task-review-loop Step 6 / Re-Invocation After Human Edits に従い、人間が候補を適用した後、上記差分を edit-summary として attempt 1 / round 2 を実行します。候補適用だけでは合格・実装承認・Done になりません。
