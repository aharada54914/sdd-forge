# SDD Domain / DDD Upstream Lane (Gemini CLI)

Gemini CLI 向けの DDD アップストリームレーン拡張です。

- **公開コマンド**: `/sdd-domain:domain-model [new|update|reverse|review] [seed|target]`
- **スキル構成** (`skills/`):
  - `domain-model` → `domain-interviewer` / `domain-reverse` / `domain-review-loop`
  - `domain-review-loop`（`validate-domain-contract` 決定論検証＋戦略/戦術 2 視点独立並列 1 パスレビュー）
  - `concept-test`（`validate-concept-test`、v2 モデルでの feature 概念整合テスト）
  - `domain-sync`（承認済み `domain/` を `sdd-core-spec` 仕様生成へ注入）
- **承認境界**: `domain/context-map.md` の `Domain-Model-Status: Approved` は人間のみ設定可能で、`sdd-quality-loop` の `BeforeTool` フック（`sdd-soft-guard.mjs`）がエージェントによる書換を拒否します。承認する人は `domain-review-loop` の「人による承認と契約の発行」に従い、`domain/domain-contract.json` も発行します（context-map だけの承認では Concept Test が停止します）。
