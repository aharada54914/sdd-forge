# 要件（lite）: p0-hardening

- **Issue/出典**: 内部監査レポート `sdd-forge-audit.md`（2026-07-01、Workflow 11エージェント・敵対的検証済み）の P0 指摘
- **目的**: sdd-forge を「新規作成・機能追加・バグ修正」の個人標準として日常運用できる水準にするため、監査で確認された P0（収束保証の穴2件 + 実装並列化1件）を最小差分で塞ぐ。

## ユーザーストーリー / 要求

- REQ-001: 運用者として、`wfi-audit-cycle` が BLOCKED を人間の忍耐に依存して無限反復しないよう、**試行回数の上界**と**未改訂（NO-CHANGE）停止**がほしい。（監査 P0-1）
- REQ-002: 運用者として、`sdd-ship` の quality-gate 回数上限が invocation/セッションを跨いでも実効するよう、**ディスク上のレポート数に基づく上限判定**がほしい。（監査 P0-2）
- REQ-003: 運用者として、`implement-tasks` が依存の無い独立タスクを**並列実装**でき、N 個の独立タスクで実装時間が N 倍になる逐次固定を解消してほしい。安全性は既存 `SCOPE-DISJOINT`（`task-reviewer-b.md:140-151`）の判定基準で担保する。（監査 P0-3 / critical）

## スコープ外

- P1/P2 の全項目（a11y 前段ゲート、cross-model/quality-gate 並列発火手段、オーケストレーター文脈抑制、Codex ルーティング、Required Reading 分割、総量ガード）。
- **item② のバグ修正実行スキルの実装**（本 spec では設計のみ。設計書は `specs/sdd-diagnose/design.md`）。
- **既存 `BUGFIX-DIAGNOSTIC-PATH` チェックの変更**（HEAD の `task-reviewer-b.md:167-181` に既に存在。維持する）。
- `sdd-hook-guard.*`・gate スクリプト・hooks の変更（sdd-ship の Security Boundaries と同じく不可侵）。

## Open Questions

- 上限値は `3` で妥当か。`wfi-audit-cycle` の `Audit-Attempt` 上限と `sdd-ship` の gate 回数上限を、review-loop の `round==3→BLOCKED`（`impl-review-loop/SKILL.md:200-205` 等）と揃える案を採る想定。→ 承認時に確定。
- 並列実装の同時実行数上限（Claude Code = 1メッセージ内の Task 数、Codex = 並列プロセス数）。既定の上限を明記すべきか。
- 監査は stash 済み WIP（`task-reviewer-b.md` を48行削減）に対して実行されたため BUGFIX-DIAGNOSTIC を「未実装」と誤検出した。その WIP が当該チェックを削除している可能性 → リコンサイル時に要確認（本 spec の対象外）。
