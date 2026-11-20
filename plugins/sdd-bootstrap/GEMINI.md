# SDD Bootstrap (Gemini CLI)

Gemini CLI 向けの仕様化・調査・デザイン同期ワークフロー拡張です。

- **公開コマンド**: `/sdd-bootstrap:bootstrap <mode> <source>`（`feature` / `bugfix` / `refactor` / `project` / `adopt` / `investigate`、`--lite` / `--feature` / `--reset` 対応）。
- **必須フロー**:
  1. 新規対話セッションでは `model-selection` でメインと役割別モデルを確認する。
  2. トラック選択前に `check-hook-activation-handshake --emit-challenge` → `write_file` カナリア試行 → `--verify-response --runtime gemini-cli` を実行し、`HOOK_ACTIVE` を確認する（Capability Mode プロジェクトでは非 `HOOK_ACTIVE` で `CAPABILITY_RUNTIME_UNAVAILABLE` 停止）。
  3. Full トラックでは Phase 1 → `spec-review-loop` → `impl-review-loop` → Phase 2 → `task-review-loop` の 3 段階独立レビューを通す。
  4. `tasks.md` は必ず `Approval: Draft` で停止し、人間承認を依頼する。
