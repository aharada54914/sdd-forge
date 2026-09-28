# Implementation Policy Review Report: sdd-domain-concept-test — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | sdd-domain-concept-test |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | PASS |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | 2026-09-27T23:41:00Z |

## Reviewer-A Findings (Structural Soundness)

TEST-STRATEGY-COVERAGE (Major): design.md:26-28の既存Test Strategy節はacceptance fixture、Phase0回帰、sh/ps1 parityを挙げるが、unit-test対象moduleとmock対象・非mock対象を定義していない。同:14,18-20で変更する契約検査、署名検証連携、実行結果の分岐をどこまで独立検証するかが不明で、実装者ごとに検証範囲が変わるMajorの設計不足。既存節の内容不足であり、legacyの欠落テンプレートフィールド免除には該当しない。unit scopeとmock方針を明記する必要がある。

## Reviewer-B Findings (Implementability/Risk)

FAILなし。PASSは設計評価であり、実装・CI・実ホスト起動の証明ではない。

## Proposed Changes

design.md の Test Strategy に1段落のみ追加する。独立した契約判定の単体検証と実署名検証の統合検証を区別し、後続処理だけをspyで置換する。暗号・登録承認者・content hashは置換しない。既存acceptance fixture、Phase0回帰、twins検証は保持する。

## Next Steps

人間が hash固定の human-apply-test-strategy.py --apply を実行する。設計以外・レビュー判定・Git履歴は変更しない。その後、編集概要を付けて attempt 1 / round 2 の独立レビューを実施する。
