---
name: wfi-audit-cycle
description: Orchestrator for the 2-cycle independent WFI proposal audit (wfi-auditor-a quality audit + wfi-auditor-b impact/risk audit) before human approval of a Draft WFI-NNN.md.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `workflow-retrospective` から Draft WFI の品質監査が必要な場合のみ呼び出される内部スキル。`Status: Approved` は絶対に書き込まない（人間承認専用）。

# WFI Audit Cycle

`docs/workflow-improvements/WFI-NNN.md`（`Status: Draft`）に対し、独立した 2 サイクルの監査（Cycle 1: 提案品質 / Cycle 2: 影響・リスク）を実行し、人間レビュー前の品質を引き上げる。

## Preconditions

1. `docs/workflow-improvements/WFI-NNN.md` が存在し、`Status: Draft` であること。
2. `Audit-Status:` が `Human-Pending` または `Human-Blocked` なら何もせず停止する。
3. 収束ガード: `Audit-Attempt >= 3` なら `Audit-Status: Human-Blocked` にして停止する（人間による根本解決と `Audit-Attempt: 0` リセットが必要）。
4. 未変更ガード: 前回 `BLOCKED` 後に WFI 本文の SHA-256 が `Audit-Content-Hash:` から変わっていなければ再実行せず停止する。

## Process

1. **Cycle 1 (`wfi-auditor-a` — 提案品質)**:
   - `Audit-Status: Cycle-1-In-Progress` に更新。
   - 独立 Read-Only コンテキストで `wfi-auditor-a` を起動し、`WFI-NNN.md`・最新回顧レポート・`plugins/sdd-quality-loop/references/wfi-category-guide.md` を渡す。
   - 返却 JSON を親オーケストレータが `docs/workflow-improvements/WFI-NNN-auditor-a.json` に保存し、`WFI-NNN-audit-cycle-1.md` を出力。
   - `BLOCKED` → `Audit-Attempt` を +1、`Audit-Content-Hash` を記録、`Audit-Status: Not-Started`（3 回到達時は `Human-Blocked`）にして停止。
   - `NEEDS_REVISION` → 親が `proposed_revisions` を適用して `WFI-NNN.md` を改訂。
   - Cycle 1 のチェック ID・件数のみ（生コメントなし）を `WFI-NNN-integrated-summary.json` へ書き出す。

2. **Cycle 2 (`wfi-auditor-b` — 影響・リスク)**:
   - `Audit-Status: Cycle-2-In-Progress` に更新。
   - 独立 Read-Only コンテキストで `wfi-auditor-b` を起動し、改訂後 `WFI-NNN.md`・最新回顧レポート・`wfi-category-guide.md`・`WFI-NNN-integrated-summary.json` のみを渡す（Cycle 1 生レポートは渡さない）。
   - 返却 JSON を親オーケストレータが `docs/workflow-improvements/WFI-NNN-auditor-b.json` に保存し、`WFI-NNN-audit-cycle-2.md` を出力。
   - `BLOCKED` → 収束ガード同様に停止。`NEEDS_REVISION` → 親が安全に反映できる指摘のみ適用。

3. **完了遷移**:
   - Cycle 2 完了後、`Category: plugin-improvement` でユーザー同意があれば追跡 Issue を起票し、`Audit-Status: Human-Pending` を設定して人間承認を依頼する。

## Boundaries

- `Status: Approved` は絶対に書き込まない（人間専用）。
- `wfi-auditor-a` と `wfi-auditor-b` を同一コンテキストで実行しない・生出力を相互共有しない。
- `wfi-auditor-{a,b}` 自身はファイル書き込みを行わず JSON を返すのみ。全ファイル保存と WFI 改訂は親オーケストレータが担う。
- `reports/` や `specs/`、インストール済み `plugins/`、タスク状態や `sdd-gate` は変更しない。
