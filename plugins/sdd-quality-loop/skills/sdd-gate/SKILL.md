---
name: sdd-gate
description: Independent quality gate for SDD Core with strict perspective parity (G1-G5). Runs run-sdd-gate.mjs (project checks, placeholder scan, SQL/Cloud/Secret sensors, Spec Drift), verifies all 5 canonical perspectives (1 evaluator on low/standard, 2 parallel evaluators on high), writes the gate report, and transitions passed tasks to Done.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `ship` から呼び出される内部スキル。`Status: Done` への遷移権は本スキルのみが持つ。

# SDD Gate

`Status: Implementation Complete` のタスクを機械検証＋独立レビューで検証し、`Done` 可否を判定する。
**設計原則（Perspective Parity）**: 独立レビューで点検する 5 観点（**G1〜G5**）は `Risk: low / standard / high` のすべてで同一とし、対象外の面は `N/A（理由）` を明記する。`Risk: high` では独立 2 視点並列（`sdd-evaluator` A + B）＋ TDD Red→Green 証跡必須＋未確定 `OQ-NNN` 機械ブロックへスケールする。

## Preconditions

- 対象タスクが `Approval: Approved` かつ `Status: Implementation Complete`。
- 実装を担当していない独立コンテキストでレビューを実行すること（自己採点は不可）。
- `specs/<feature>/.spec-baseline.json` が存在すること（`--skip-drift` 指定時を除く）。

## Process

1. **決定論チェックの一括実行（`run-sdd-gate.mjs`）**:
   プロジェクトの lint / typecheck / build / test コマンドを渡し、単一コマンドで以下を実行・記録する:
   - タスク前提確認（`Approval: Approved`, `Status: Implementation Complete`）
   - 対象 feature に `concept-test/v2` の提案・人手判断記録がある場合、同梱の読取専用 `validate-concept-test --require-v2` で現在の入力と判断を照合する。結果は `checks.conceptTest` に保存し、`DEFER`、`REJECT`、`BLOCK` では指定コマンドの実行前に停止する。変更ファイルの絞り込み、drift・sensor の省略はこの判定に影響しない。
   - 対象プロジェクト・featureの現在の作業木とGitインデックスで適用を判定する。祖先にだけある草稿や判断は適用根拠に含めない。現在のv2提案、判断記録、不完全な証拠は配布validatorで照合する。Git CLIが使えず作業木にも対象証拠がなければ `history: GIT_UNAVAILABLE` を記録する。Gitが起動してもインデックスの読取りに失敗した場合は停止する。
   - `concept-test.decision.json` は人が対話確認で作成する。ソフトガードは対応ホストのファイル編集とパッチからの作成・変更・削除・移動を拒否する。端末操作はフックの検査対象外で、記録だけから操作者の本人性は判定できない。
   - Spec Drift 検査（`check-spec-drift.mjs` 統合 — `UNDECLARED_DRIFT` は自動 FAIL）
   - 変更コード（新規未追跡ファイル含む）のプレースホルダー検査および非機能静的センサー（SQL 破壊的 DDL・`WHERE` 欠落・`SELECT *` 性能助言、Cloud ワイルドカード IAM・管理ポート開放、秘密情報）。依存脆弱性チェックが必要な場合は `--cmd "audit=..."` で統合する。
   - `Risk: high` タスクに対する未確定 `OQ-NNN`（非 `Confirmed`）残存ブロック
   - 指定コマンド実行と `reports/quality-gate/<feature>-<task-id>.execution.json` 保存（および `.sdd/factory-metrics.jsonl` への軽量計測追記；FAIL 時は原因工程を `factory-metrics.mjs record-attribution --root-cause <phase>` で記録）

   ```bash
   node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs" \
     --feature "<feature>" --task "<T-NNN>" --root "<repo-root>" \
     --cmd "test=<test-command>"
   ```

   - 非ゼロ終了時は失敗内容（`UNDECLARED_DRIFT` なら仕様を戻すか合意済み理由を `## Spec Amendments` へ追記）を添えて差し戻す。

2. **独立レビュー（統一 5 観点 G1〜G5・1 パス）**:
   `git diff`、`specs/<feature>/{requirements,design,tasks}.md`、`reports/implementation/<feature>/<task-id>.md`、`execution.json` を突き合わせる:

   | ID | 観点 | 検査基準（全リスク階層共通） | `low` / `standard`（1 体） | `high`（2 体並列） |
   |---|---|---|---|---|
   | **G1** | **AC / Done When 実証 & 偽装完了検知** | 全対象 `AC-NNN` / `### Done When` が実コマンド・実テストで証明され、ハードコード・スキップ・空実装がないか（`Risk: high` は TDD Red→Green 証跡も確認） | Evaluator | Evaluator A |
   | **G2** | **Spec Amendment & スコープ整合** | `AMENDED` 時に `## Spec Amendments` の理由と差分が妥当で要件を骨抜きにしていないか、スコープ外変更がないか | Evaluator | Evaluator A |
   | **G3** | **回帰・異常系・エラー処理** | 既存機能（`baseline-behavior.md` 含む）の回帰範囲、異常系・境界条件・例外握りつぶしがないか | Evaluator | Evaluator B |
   | **G4** | **セキュリティ・非機能・移行/ロールバック** | 認証/認可・入力検証・秘密情報・SQL/Cloud 安全性・ロールバック影響に欠陥がないか（無関係時は `N/A（理由）`） | Evaluator | Evaluator B |
   | **G5** | **ドメイン / デザイン規約整合** | `domain/`（用語・概念境界）および `design-system/` 存在時に規約からの逸脱がないか（不在時は `N/A`） | Evaluator | Evaluator A |

   > 並列未対応ホストで `Risk: high` の場合は、Evaluator A と Evaluator B を別コンテキストで順次 1 回ずつ実行し、第 2 視点を省略しない。

3. **品質レポート出力（`reports/quality-gate/<feature>-<task-id>.md`）**:
   `plugins/sdd-quality-loop/templates/sdd-gate-report.md` を使い、G1〜G5 すべての判定（または明示 `N/A` 理由）とテンプレート冒頭の **Non-checks（検査しないもの）** を記録する。全決定論チェック PASS かつ未解決 Blocking Issues（Critical / Major）がゼロのときのみ `VERDICT: PASS` とする。

4. **Done 遷移**:
   `VERDICT: PASS` のときのみ `specs/<feature>/tasks.md` の対象タスクを `Status: Done` に更新する（`FAIL` 時は `Implementation Complete` のまま差し戻す）。

## Boundaries

- `Approval:` は絶対に変更しない。
- PR マージ時のオーナー承認や複数人レビューは GitHub（`CODEOWNERS` / Branch Protection）に委ねる。

## Handoff

`VERDICT`、Spec Drift ステータス（`CLEAN` / `AMENDED` / `UNDECLARED_DRIFT`）、G1〜G5 検証サマリ、および `Status: Done` 遷移結果（または差し戻し理由）を `ship` へ返す。
