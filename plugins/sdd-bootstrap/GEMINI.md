# SDD Bootstrap (Gemini CLI)

Gemini CLI 向けの SDD Core 仕様化・調査・デザイン同期拡張です。

- **公開コマンド**: `/sdd-bootstrap:bootstrap <mode> <source>`（`feature` / `bugfix` / `refactor` / `project` / `adopt` / `investigate`、`--feature` / `--risk low|standard|high` / `--skip-check` 対応）。
- **フロー**:
  1. `sdd-core-spec` で `specs/<feature>/{requirements,design,tasks}.md`（必須 `AC-NNN`・`Risk:`・`## Spec Amendments` 付き）を生成する。
  2. `spec-check` をリスク連動 1 パスで実行する（`low` 省略 / `standard` 1 体 / `high` 2 視点並列）。
  3. `tasks.md` は必ず `Approval: Draft` で停止し、人間承認を依頼する。
