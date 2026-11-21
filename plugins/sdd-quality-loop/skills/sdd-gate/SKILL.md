---
name: sdd-gate
description: Independent quality gate for SDD Core. Runs run-sdd-gate.mjs (project checks, placeholder scan, and Spec Drift detection), verifies ACs in an independent 1-pass review, writes the gate report, and transitions passed tasks to Done.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `ship` から呼び出される内部スキル。`Status: Done` への遷移権は本スキルのみが持つ。

# SDD Gate

`Status: Implementation Complete` のタスクを機械検証＋独立レビューで検証し、`Done` 可否を判定する。

## Preconditions

- 対象タスクが `Approval: Approved` かつ `Status: Implementation Complete`。
- 実装を担当していない独立コンテキストでレビューを実行すること（自己採点は不可）。
- `specs/<feature>/.spec-baseline.json` が存在すること（`--skip-drift` 指定時を除く）。

## Process

1. **決定論チェックの一括実行（`run-sdd-gate.mjs`）**:
   プロジェクトの lint / typecheck / build / test コマンドを渡し、単一コマンドで以下を実行・記録する:
   - タスク前提確認（`Approval: Approved`, `Status: Implementation Complete`）
   - Spec Drift 検査（`check-spec-drift.mjs` 統合 — `UNDECLARED_DRIFT` は自動 FAIL）
   - 変更コードのプレースホルダー検査
   - 指定コマンド実行と `reports/quality-gate/<feature>-<task-id>.execution.json` 保存

   ```bash
   node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs" \
     --feature "<feature>" --task "<T-NNN>" --root "<repo-root>" \
     --cmd "test=<test-command>"
   ```

   - 非ゼロ終了時は失敗内容（`UNDECLARED_DRIFT` なら仕様を戻すか合意済み理由を `## Spec Amendments` へ追記）を添えて差し戻す。

2. **独立レビュー（1 パス）**:
   `git diff`、`requirements.md`（対象 `AC-*`）、`design.md`、`execution.json` を突き合わせる:
   - `### Done When` と各 `AC-NNN` がどの実測・テストで証明されたか確認する。
   - `AMENDED` の場合、`## Spec Amendments` の理由と差分が妥当であり要件を不当に骨抜きにしていないか確認する。
   - 関連機能の回帰範囲を確認する（`Risk: high` 時はセキュリティ・エラー処理・TDD Red→Green 証跡・ロールバック影響も点検）。
   - `design-system/` / `domain/` 存在時は既存規約からの明らかな逸脱がないか確認する。

3. **品質レポート出力（`reports/quality-gate/<feature>-<task-id>.md`）**:
   `plugins/sdd-quality-loop/templates/sdd-gate-report.md` を使い、全決定論チェック PASS かつ未解決 Blocking Issues がゼロのときのみ `VERDICT: PASS` とする。テンプレート冒頭の **Non-checks（検査しないもの）** を残し、未検証領域がある場合は明記する。

4. **Done 遷移**:
   `VERDICT: PASS` のときのみ `specs/<feature>/tasks.md` の対象タスクを `Status: Done` に更新する（`FAIL` 時は `Implementation Complete` のまま差し戻す）。

## Boundaries

- `Approval:` は絶対に変更しない。
- PR マージ時のオーナー承認や複数人レビューは GitHub（`CODEOWNERS` / Branch Protection）に委ねる。

## Handoff

`VERDICT`、Spec Drift ステータス（`CLEAN` / `AMENDED` / `UNDECLARED_DRIFT`）、AC 検証サマリ、および `Status: Done` 遷移結果（または差し戻し理由）を `ship` へ返す。
