# SDD Ship (Gemini CLI)

Gemini CLI 向けの承認済みタスク実装・品質ゲート・ステータス観測ワークフロー拡張です。

- **公開コマンド**:
  - `/sdd-ship:ship [specs/<feature>/tasks.md[#T-NNN]] [--lite|--full|--verify|--retro]`
  - `/sdd-ship:status [options]`
- **必須フロー**:
  1. 新規対話セッションでは `model-selection` でメインと役割別モデルを確認する。
  2. Track Detection 前に `check-hook-activation-handshake --emit-challenge` → `write_file` カナリア試行 → `--verify-response --runtime gemini-cli` を実行する。
  3. Lite ルートは必ず `check-risk-upgrade.sh`（または `.ps1`）を実行し、昇格判定時は Full トラックへ切り替える。
  4. `Approval: Approved` のタスクのみ実装し、`Done` 遷移は `quality-gate`（または Lite 時の `lite-gate`）のみが行う。
