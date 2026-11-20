---
name: sdd-gate
description: Unified, lightweight independent quality gate for SDD Core. Runs deterministic project checks + check-spec-drift (goalpost-moving detection) via run-sdd-gate.mjs, verifies ACs in an independent pass, writes a concise report, and transitions passed tasks to Done.
disable-model-invocation: false
user-invocable: false
---

# SDD Gate（統合品質ゲート）

SDD Forge v2（ADR-0051）の統合品質ゲート。実装者自身による甘い自己採点を防ぎつつ、旧 `quality-gate`（689 行・HMAC 署名・6-Pass 契約・クロスモデル必須）の過剰な儀式を廃止し、旧 `lite-gate` に不足していた **Spec Drift 検知（ゴールポスト移動防止）** と **AC 対照検証** を軽量に統合する。

## Preconditions

- 対象タスクが `Approval: Approved` かつ `Status: Implementation Complete`。
- 実装者とは別の独立コンテキスト（または独立レビュー実行）で検証すること。独立した確認を行わずに `VERDICT: PASS` を記録しない。
- `specs/<feature>/.spec-baseline.json` が存在すること（未作成なら `ship` が実装前に記録済みであることを確認する）。

## Process

1. **決定論的ゲートの一括実行（`run-sdd-gate.mjs`）**:
   プロジェクトの lint / typecheck / build / test コマンド（`AGENTS.md` または `package.json` 等から判定）を渡し、単一コマンドで以下を自動検証する:
   - タスク状態前提確認（`Approval: Approved`, `Status: Implementation Complete`）
   - **Spec Drift 検査**（`check-spec-drift.mjs` 統合 — `CLEAN` / `AMENDED` は通過、`UNDECLARED_DRIFT` は自動 FAIL）
   - 変更ファイルに対するプレースホルダー検査（`TODO` / `FIXME` / `NotImplemented` 等）
   - 指定された検証コマンドの実測実行と `reports/quality-gate/<feature>-<task-id>.execution.json` 保存

   ```bash
   node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs" \
     --feature "<feature>" --task "<T-NNN>" --root "<repo-root>" \
     --cmd "test=<test-command>"
   ```

   - `run-sdd-gate.mjs` が非ゼロ終了（`FAIL`）した場合:
     - `UNDECLARED_DRIFT` なら「無断で改変された仕様を元に戻すか、ユーザー合意のうえ `## Spec Amendments` に理由を追記する」よう差し戻す。
     - テスト失敗・プレースホルダー検出なら失敗出力を添えて実装者へ差し戻す。

2. **独立レビュー（1 パス・AC 対照と回帰確認）**:
   実装コードの `git diff`、`requirements.md`（対象 `AC-*`）、`design.md`、および `execution.json` を突き合わせて確認する:
   - タスクの `### Done When` および参照 `AC-NNN` ごとに、どの実測結果・テストで充足を確認したか明記する。
   - `spec-drift` が `AMENDED` の場合、`## Spec Amendments` に記録された理由と変更内容が妥当であり、要件を不当に骨抜きにしていないか確認する。
   - 関連機能の回帰リスク、および `Risk: high` 時はセキュリティ・エラー処理・TDD Red→Green 確認・ロールバック影響を点検する。
   - `design-system/` や `domain/` がある場合は、既存方針からの明らかな逸脱がないか確認する（不在時はスキップ）。

3. **品質レポート作成（`reports/quality-gate/<feature>-<task-id>.md`）**:
   `plugins/sdd-quality-loop/templates/sdd-gate-report.md` を使用して簡潔なレポートを書き出す。
   - すべての決定論チェックが PASS かつ独立レビューで未解決の重大指摘がゼロのときのみ `VERDICT: PASS` とする。
   - 1 つでも未解決の失敗・不足があれば `VERDICT: FAIL` とし、`Status` は `Implementation Complete` のまま残して差し戻す。

4. **Done 遷移**:
   - `VERDICT: PASS` のときのみ、`specs/<feature>/tasks.md` の対象タスクを `Status: Done` に更新する（`sdd-soft-guard.mjs` は `tasks.md` の `Status:` 更新のみ自動許可する）。

## Boundaries

- `Approval:` は絶対に変更しない（人間のみ）。
- 外部署名鍵・HMAC 署名付き `evidence.json`・`contract.json` 6-Pass・`workflow-state-registry.json`・`cross-model-verify` 強制は行わない。
- PR マージ時の最終境界（CODEOWNERS・複数人承認・CI `check-spec-drift`）は GitHub 側に委ねる。

## Handoff

`VERDICT`、Spec Drift ステータス（`CLEAN` / `AMENDED` / `UNDECLARED_DRIFT`）、AC 検証サマリ、および `Status: Done` 遷移結果（または差し戻し理由）を `ship` へ返す。
