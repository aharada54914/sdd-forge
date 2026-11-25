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

- 対象タスクが `Approval: Approved` かつ `Status: Implementation Complete`。仕様変更後の再検証では `Done` のタスクも対象にする（`PASS` なら証跡を更新するだけで状態は変えず、`FAIL` は人間へ報告する）。
- 実装を担当していない独立コンテキストでレビューを実行すること（自己採点は不可）。
- `specs/<feature>/.spec-baseline.json` が存在すること（`--skip-drift` 指定時を除く）。

## Process

1. **決定論チェックの一括実行（`run-sdd-gate.mjs`）**:
   プロジェクトの lint / typecheck / build / test コマンドを渡し、単一コマンドで以下を実行・記録する:
   - タスク前提確認（`Approval: Approved`, `Status: Implementation Complete`、または仕様変更後の再検証では `Done`）
   - 対象 feature に `concept-test/v2` の提案・人手判断記録がある場合、同梱の読取専用 `validate-concept-test --require-v2` で現在の入力と判断を照合する。結果は `checks.conceptTest` に保存し、`DEFER`、`REJECT`、`BLOCK` では指定コマンドの実行前に停止する。変更ファイルの絞り込み、drift・sensor の省略はこの判定に影響しない。
   - 対象プロジェクト・featureの現在の作業木とGitインデックスで適用を判定する。祖先にだけある草稿や判断は適用根拠に含めない。現在のv2提案、判断記録、不完全な証拠は配布validatorで照合する。Git CLIが使えず作業木にも対象証拠がなければ `history: GIT_UNAVAILABLE` を記録する。Gitが起動してもインデックスの読取りに失敗した場合は停止する。
   - `concept-test.decision.json` は人が対話確認で作成する。ソフトガードは対応ホストのファイル編集とパッチからの作成・変更・削除・移動を拒否する。端末操作はフックの検査対象外で、記録だけから操作者の本人性は判定できない。
   - Spec Drift 検査（`check-spec-drift.mjs` 統合 — `UNDECLARED_DRIFT` と `UNVERIFIABLE`（読取上限超で未判定の仕様ファイルあり）は自動 FAIL。ベースライン後に承認されたタスクは `APPROVED_AFTER_BASELINE` 警告になるため、独立レビューで人間の承認であることを確認する）
   - 変更コード（新規未追跡ファイル含む）のプレースホルダー検査および非機能静的センサー（SQL 破壊的 DDL・`WHERE` 欠落・`SELECT *` 性能助言、Cloud ワイルドカード IAM・管理ポート開放、秘密情報）。依存脆弱性チェックが必要な場合は `--cmd "audit=..."` で統合する。
   - `Risk: high` タスクに対する未確定 `OQ-NNN`（非 `Confirmed`）残存ブロック
   - 指定コマンド実行と `reports/quality-gate/<feature>-<task-id>.execution.json` 保存（および `.sdd/factory-metrics.jsonl` への軽量計測追記；FAIL 時は原因工程を 1 試行につき 1 回だけ `factory-metrics.mjs record-attribution --root-cause <phase> --run-id <execution.json の runId>` で記録する。ゲート実行時に `--root-cause` を渡した場合は記録済みなので重ねない）

   ```bash
   node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs" \
     --feature "<feature>" --task "<T-NNN>" --root "<repo-root>" \
     --cmd "test=<test-command>"
   ```

   - 並列実行で作業ツリーを共有している場合、既定の検査は他タスクの未完了の変更も拾う（検出結果は `inTaskScope: false`、`scope.outOfScopeFiles`、警告 `OUT_OF_SCOPE_CHANGES` で区別される。判定は緩めない）。他人の変更を消さずに自タスクだけ検証するには、自タスクの `### Scope` に属する変更ファイルを `--changed-files "a.js,b.js"` で明示する。
   - 検査対象の変更ファイルは既定で「HEAD に対する未コミット差分＋未追跡ファイル」。タスクの途中でコミットしてから再開した場合は、タスク開始時点のコミットを `--base <git-ref>` で渡し、コミット済みの変更も検査対象に戻す（履歴を自動では広げない）。
   - 非ゼロ終了時は失敗内容（`UNDECLARED_DRIFT` なら仕様を戻すか合意済み理由を `## Spec Amendments` へ追記）を添えて差し戻す。

2. **独立レビュー（統一 5 観点 G1〜G5・1 パス）**:
   `git diff`、`specs/<feature>/{requirements,design,tasks}.md`、`reports/implementation/<feature>/<task-id>.md`、`execution.json`、対象 feature・タスクの `docs/review-tickets/*.yml` を突き合わせる（未解決の `critical` / `major` チケットは `execution.json` の `checks.reviewTickets.blocking` に列挙され、機械判定も FAIL になる）:

   | ID | 観点 | 検査基準（全リスク階層共通） | `low` / `standard`（1 体） | `high`（2 体並列） |
   |---|---|---|---|---|
   | **G1** | **AC / Done When 実証 & 偽装完了検知** | 全対象 `AC-NNN` / `### Done When` が実コマンド・実テストで証明され、ハードコード・スキップ・空実装がないか（`Risk: high` は TDD Red→Green 証跡も確認） | Evaluator | Evaluator A |
   | **G2** | **Spec Amendment & スコープ整合** | `AMENDED` 時に `## Spec Amendments` の理由と差分が妥当で要件を骨抜きにしていないか、スコープ外変更がないか（機械判定は理由の件数増加のみ。`changedIdsWithoutAmendment` に挙がった ID は理由が書かれていない差分として個別に判断する） | Evaluator | Evaluator A |
   | **G3** | **回帰・異常系・エラー処理** | 既存機能（`baseline-behavior.md` 含む）の回帰範囲、異常系・境界条件・例外握りつぶしがないか | Evaluator | Evaluator B |
   | **G4** | **セキュリティ・非機能・移行/ロールバック** | 認証/認可・入力検証・秘密情報・SQL/Cloud 安全性・ロールバック影響に欠陥がないか（無関係時は `N/A（理由）`） | Evaluator | Evaluator B |
   | **G5** | **ドメイン / デザイン規約整合** | `domain/`（用語・概念境界）および `design-system/` 存在時に規約からの逸脱がないか（不在時は `N/A`） | Evaluator | Evaluator A |

   > 並列未対応ホストで `Risk: high` の場合は、Evaluator A と Evaluator B を別コンテキストで順次 1 回ずつ実行し、第 2 視点を省略しない。

3. **品質レポート出力（`reports/quality-gate/<feature>-<task-id>.md`）**:
   `plugins/sdd-quality-loop/templates/sdd-gate-report.md` を使い、G1〜G5 すべての判定（または明示 `N/A` 理由）とテンプレート冒頭の **Non-checks（検査しないもの）** を記録する。全決定論チェック PASS かつ未解決 Blocking Issues（Critical / Major）がゼロのときのみ `VERDICT: PASS` とする。`execution.json` の `coverage.complete` が `false`（`--cmd` 0 件、または `--skip-drift` / `--skip-sensors`）の機械 PASS は検証範囲が欠けているため Done の根拠にせず、不足した検証を実行してから判定する（MCP `sdd_gate_audit` も `readyForDone: false` を返す）。

4. **最終判定の計測記録**:
   レポートの最終 `VERDICT` を計測へ戻す（機械ゲートの PASS だけが合格率に入らないようにするため）:
   ```bash
   node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs" record-final-verdict --feature <feature> --task <task-id> --verdict <PASS|FAIL> --root "<repo-root>"
   ```

5. **Done 遷移**:
   `VERDICT: PASS` のときのみ `specs/<feature>/tasks.md` の対象タスクを `Status: Done` に更新する（`FAIL` 時は状態を変えずに差し戻す。`Implementation Complete` はそのまま、再検証した `Done` タスクも `Done` のまま人間へ報告し、開き直すかは人間が決める）。

## Boundaries

- `Approval:` は絶対に変更しない。
- PR マージ時のオーナー承認や複数人レビューは GitHub（`CODEOWNERS` / Branch Protection）に委ねる。

## Handoff

`VERDICT`、Spec Drift ステータス（`CLEAN` / `AMENDED` / `UNDECLARED_DRIFT` / `UNVERIFIABLE`）、G1〜G5 検証サマリ、および `Status: Done` 遷移結果（または差し戻し理由）を `ship` へ返す。
