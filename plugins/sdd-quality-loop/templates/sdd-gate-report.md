# SDD Gate Report: <feature> / <T-NNN>

- **Task ID**: <T-NNN>
- **Feature**: <feature>
- **Risk Tier**: low | standard | high
- **VERDICT**: FAIL

> 初期値は FAIL。決定論チェック・Spec Drift 検査・独立レビューのすべてを確認してから判定を更新する。

## Deterministic Checks

- **Execution Evidence**: `reports/quality-gate/<feature>-<T-NNN>.execution.json`
- **Spec Drift**: CLEAN | AMENDED | UNDECLARED_DRIFT
- **Placeholder Scan**: PASS | FAIL
- **Project Commands**: <コマンドごとの PASS / FAIL 要約>

## Acceptance Criteria Verification

| AC ID | 検証手段（テスト / 実測） | 結果 |
|---|---|---|
| AC-001 | <テスト名・コマンド> | PASS / FAIL |

## Independent Review Findings

- **Reviewed Scope**: <確認した差分・関連回帰範囲>
- **Spec Amendments Check**: <AMENDED 時の理由妥当性、CLEAN 時は N/A>
- **Blocking Issues**: None（または修正必須項目）
- **Advisory Notes**: None（または任意の改善提案）
