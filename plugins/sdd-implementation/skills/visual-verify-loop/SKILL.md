---
name: visual-verify-loop
description: Implementation-phase visual verification loop for UI tasks. Launches the app (Claude Preview MCP / Playwright for web, wpf-visual-verify for WPF desktop), compares rendered UI against design.md states, approved mockups, and design-system/ tokens/patterns, iterates fixes up to five times, and saves screenshots under reports/visual-evidence/. Non-blocking; verdicts stay with sdd-gate and human review.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `implement-task` から UI タスクの実装後に呼び出される助言的・非ブロッキング内部スキル。

# Visual Verify Loop

UI タスクの実装結果を実画面で目視検証し、スクリーンショット証跡を `reports/visual-evidence/<task-id>/` へ残す。合否判定は後段の `sdd-gate` と人間レビューに委ねる。

## Trigger Condition

以下の両方を満たす場合のみ実行する（非該当時は実装レポートへスキップ理由を記録して戻る）:
- プロジェクトに `design-system/` または `specs/<feature>/mockups/` が存在する
- タスクの `### Scope` に UI レイヤーファイル（画面・コンポーネント・スタイル・テンプレート）が含まれる

## App-Type Detection

- **Web**: 開発サーバーを起動可能な場合、Claude Preview MCP（`preview_start`, `preview_screenshot`, `preview_snapshot`, `preview_inspect`, `preview_resize`）を優先。利用不可時は Playwright 等の実ブラウザツールで同等のスクリーンショット・アクセシビリティスナップショット・計算済みスタイル・desktop/mobile ビューポートを取得し、使用ツール名を正確に記録する（起動したサーバーは終了時に停止）。
- **WPF Desktop**: `wpf-visual-verify` スキルでオフスクリーン PNG レンダリングを使用。
- **ツール利用不可**: 実装レポートに `visual verification unavailable — skipped: <reason>` を記録して戻る（ブロッカーにしない）。

## Loop（最大 5 回）

1. 対象ビューをビルド・起動（または再描画）する。
2. スクリーンショットおよび（Web では）アクセシビリティスナップショット・主要計算スタイル（色・フォント・余白）を取得する。
3. `specs/<feature>/design.md`・`specs/<feature>/mockups/`（存在時）・`design-system/{design-tokens.json,ui-patterns.md}`（存在時）と照合する（default / empty / loading / error 状態およびブレークポイント）。
4. タスク承認スコープ内の不一致のみ修正して再確認する（スコープ外は修正せず finding として記録）。
5. 一致または 5 回到達で終了し、最終スクリーンショットを `reports/visual-evidence/<task-id>/` に保存して実装レポートの `Visual Evidence` セクションへ追記する。

## Boundaries

- 非ブロッキング: タスク状態（`Status:` / `Approval:`）は変更しない。合否判定は `sdd-gate` の責務。
- 視覚一致のために承認スコープ外のファイルを変更しない。
