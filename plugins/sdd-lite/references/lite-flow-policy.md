# Lite Flow Policy (Consolidated into SDD Core in v2.0.0 — ADR-0051)

> **移行案内（ADR-0051）**: `sdd-lite` および旧 `SDD Full` の二極トラック構成は、**SDD Forge v2 の単一トラック `SDD Core` ＋ リスクレベル伸縮（`low` / `standard` / `high`）** へ発展的に統合されました。

## 新しい標準フロー（SDD Core）での対応

| 旧 `sdd-lite` の用途 | 新 `SDD Core` での指定 |
|---|---|
| 小規模バグ修正・1〜2 ファイルの限定変更 | `/sdd-bootstrap:bootstrap bugfix --risk low <source>` → `/sdd-ship:ship`（`spec-check` 自動スキップ） |
| 通常の機能開発・社内アプリ | `/sdd-bootstrap:bootstrap feature <source>`（既定 `Risk: standard`：1 パス `spec-check` + `sdd-gate` + Spec Drift 検知） |
| 認証/決済/DB移行などの高リスク変更 | `/sdd-bootstrap:bootstrap feature --risk high <source>`（強制昇格エラーなし、同じワークフロー内で厳格チェックを加算） |

- 旧 `--lite` / `--full` フラグは互換エイリアスとしてそれぞれ `--risk low` / `--risk high` に安全にマッピングされます（ADR-0023 の `ERROR_STOP` は廃止）。
- `plugins/sdd-lite/` プラグイン本体は Phase 3 クリーンアップで正式に廃止・削除される予定です。詳細は `docs/adr/0051-lightweight-guardrails-and-sdd-core.md` を参照してください。
