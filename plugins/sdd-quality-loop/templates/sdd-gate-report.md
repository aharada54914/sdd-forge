# SDD Gate Report: <feature> / <T-NNN>

- **Task ID**: <T-NNN>
- **Feature**: <feature>
- **Risk Tier**: low | standard | high
- **VERDICT**: FAIL

> 初期値は FAIL。決定論チェック・Spec Drift 検査・独立レビューのすべてを確認してから判定を更新する。

## Non-checks（検査しないもの）

> `VERDICT: PASS` は本レポートに記載された決定論コマンド・Spec Drift・独立レビュー境界内での合格を意味し、本番環境の実稼働状態・未定義の要件妥当性・外部サービスの挙動までは保証しない。

## Deterministic Checks

- **Execution Evidence**: `reports/quality-gate/<feature>-<T-NNN>.execution.json`
- **Spec Drift**: CLEAN | AMENDED | UNDECLARED_DRIFT | UNVERIFIABLE
- **Placeholder Scan**: PASS | FAIL
- **Non-Functional Sensors (SQL / Cloud / Secrets)**: PASS | FAIL | SKIPPED
- **Open Questions Gate (`Risk: high`)**: PASS | BLOCKED (Provisional OQ)
- **Project Commands**: <コマンドごとの PASS / FAIL 要約>
- **Evaluator Model**: <ホストが実際に使ったモデル ID> — floor `strong`: MEETS | BELOW (<tier>) | UNCLASSIFIED

## Acceptance Criteria Verification

| AC ID | 検証手段（テスト / 実測） | 結果 |
|---|---|---|
| AC-001 | <テスト名・コマンド> | PASS / FAIL |

## Independent Review Findings

- **Reviewed Scope**: <確認した差分・関連回帰範囲>
- **Spec Amendments Check**: <AMENDED 時の理由妥当性、CLEAN 時は N/A>
- **Blocking Issues**: None（または修正必須項目）
- **Advisory Notes**: None（または任意の改善提案）
