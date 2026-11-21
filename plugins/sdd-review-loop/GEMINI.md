# SDD Review Loop (Gemini CLI)

Gemini CLI 向けの着工前レビュー拡張です（`skills/spec-check/SKILL.md`）。

- **リスク連動 1 パスレビュー（`spec-check`）**:
  - `Risk: low`: 自動スキップ
  - `Risk: standard`（既定）: 独立 1 体・1 パスで REQ↔AC・設計整合・タスク粒度・基本リスクを点検
  - `Risk: high`: Reviewer A（仕様・AC・エッジケース網羅）＋ Reviewer B（設計・セキュリティ・移行批判）の 2 視点並列 1 パスを実行し、`reports/spec-check/<feature>.md` へ統合（並列未対応時は順次 2 パス）
- `Approval:` や仕様本文は編集せず、Blocker があれば修正後に再実行する。
