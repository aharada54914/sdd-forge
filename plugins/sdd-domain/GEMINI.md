# SDD Domain / DDD Upstream Lane (Gemini CLI)

Gemini CLI 向けの DDD アップストリームレーン拡張です。

- **公開コマンド**: `/sdd-domain:domain-model [new|update|reverse] [seed|target]`
- **スキル構成** (`skills/`):
  - `domain-model` → `domain-interviewer` / `domain-reverse`
  - `domain-review-loop`（`domain-review-precheck` + 2 体独立レビュー + `finalize-domain-review`、最大 3 ラウンド）
  - `concept-test`（`validate-concept-test`、v2 モデルでの feature 概念整合テスト）
  - `domain-sync`（承認済み `domain/` を `sdd-bootstrap` Phase 1 へ注入）
- **承認境界**: `domain/context-map.md` の `Domain-Model-Status: Approved` は人間のみ設定可能で、`sdd-quality-loop` の `BeforeTool` フックがエージェントによる書換を拒否します。
