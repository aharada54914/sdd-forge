# SDD Quality Loop (Gemini CLI — v2 Lightweight Guardrails)

Gemini CLI 向けの軽量ソフトガードレールおよび統合品質ゲート拡張です（ADR-0051）。

- **BeforeTool ソフトガード**: `hooks/hooks.json` が `../scripts/v2/sdd-soft-guard.mjs --emit gemini` を実行します。責務は ① `AGENT_STOP` 緊急停止 ② `tasks.md` の `Approval: Approved` 自己追加抑止 ③ 承認済み `specs/<feature>/*.md` 本文変更のソフト保護（既定 `confirm`、`sdd/guardrails.yaml` で `warn`/`confirm`/`strict` 設定可）の 3 点のみです。`run_shell_command` 等の通常探索・テストは妨げません。
- **スキル配置**: 親ディレクトリ `../skills/` 配下に `sdd-gate`、`fix-by-review-ticket`、`workflow-retrospective` 等があります。
- **決定論ツール**: `../scripts/v2/{record-spec-baseline,check-spec-drift,run-sdd-gate}.mjs`（Node.js >= 20 LTS、外部依存なし）。
