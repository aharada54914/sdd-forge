# SDD Ship (Gemini CLI)

Gemini CLI 向けの承認済みタスク実装・品質ゲート・ステータス観測拡張です。

- **公開コマンド**:
  - `/sdd-ship:ship [specs/<feature>/tasks.md[#T-NNN]] [--skip-drift] [--retro]`
  - `/sdd-ship:status [options]`
- **フロー**:
  1. 対象フィーチャー・承認済みタスク（`Approval: Approved`）を選定する。
  2. `record-spec-baseline.mjs` で承認済み仕様のベースラインを記録する（未作成時）。
  3. `implement-task` / `implement-tasks` で実装し、`Implementation Complete` まで進める（承認済み仕様本文は `sdd-soft-guard.mjs` が保護）。
  4. `sdd-gate`（`run-sdd-gate.mjs` + 独立 1 パスレビュー）が全合格したときのみ `Status: Done` へ遷移する。
