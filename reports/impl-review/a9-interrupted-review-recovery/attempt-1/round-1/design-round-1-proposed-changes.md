# Implementation Policy Review Report: a9-interrupted-review-recovery — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | a9-interrupted-review-recovery |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | PASS |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-09-27T16:29:47.545Z |

## Reviewer-A Findings (Structural Soundness)

- DATA-COVERAGE (Major): design.md:52-62 の Data Plan / API Contract Plan は新規record、既存precheckへのrecovery追加、移行なしを説明するが、必須の Data Entities:、Existing Data Affected:、Migration Strategy: 各フィールドがない。legacy_design=false のため免除対象ではない。既存データの読取・変更・不変対象を独立した必須フィールドとして確定できず、実装のデータ影響範囲を照合する契約が欠ける。3フィールドに新規schema、既存precheck/履歴/入力/ledgerへの影響、移行不要の理由を明記する必要がある。必須データ計画の欠落としてMajor。
- TEST-STRATEGY-COVERAGE (Major): design.md:73-75 は両runtimeのmatrix実行とregression suiteを列挙するが、unit test対象モジュールとmock対象を定義していない。acceptance-tests.md:3 も全行をcontract/integration fixturesと位置付けており、unit scopeを補完しない。design.md:24,58-69 の純粋なschema/path/digest検証と既存verifier・lock・writer連携について、どこを単体検証し何をmockするか未確定のため、integration fixtureだけでunit-level検証を満たしたと扱える。必須test levelの欠落としてMajor。unit対象とmock方針（mockなしならその理由）を明記する必要がある。実テスト実行は要求していない。

## Reviewer-B Findings (Implementability/Risk)

No FAIL findings. PASS: 10; SKIP: 1 (DOMAIN-CONFORMANCE).

## Proposed Changes

Add explicit Data Entities, Existing Data Affected, Migration Strategy fields; specify pure-validation unit targets, mocks policy, and actual verifier/lock/writer integration scope. Await orchestrator-approved design remediation; no design edits made in this integration.

## Next Steps

Keep Impl-Review-Status: Pending. After approved remediation run normal attempt 1 round 2 precheck and independent reviews; no waiver or PASS transition.
