---
name: sdd-core-spec
description: Generate implementation-ready SDD Core specifications (requirements with testable ACs, design, and risk-tiered tasks) under specs/<feature>/. Invoked internally by /sdd-bootstrap:bootstrap.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `bootstrap` から呼び出される内部スキル。実装コードは書かない。

# SDD Core Spec

要件から実装可能な 3 ファイル仕様（`requirements.md` / `design.md` / `tasks.md`）を生成する。

## Preconditions

- ルートに `AGENTS.md` が存在すること（不在時は `/sdd-bootstrap:bootstrap adopt` を案内して停止）。
- `sdd/guardrails.yaml`（または `sdd/guardrails.json`）が存在すれば読み、不在時は既定値（`default_tier: standard`）を使用する。

## Process

1. **要件整理と既存コード調査**:
   - 出典（Issue URL の場合は `gh issue view` / 要件テキスト / `investigation.md` / `reports/diagnosis/*.md`）と関連コードを確認する。
   - `sdd/knowledge/INDEX.md`（および `sdd/knowledge/review-perspectives.yaml`）が存在する場合は作業前に参照し、既存仕様・ルール・プロダクト固有の観点をコンテキストへ取り込む。
   - 重要な設計分岐や曖昧な要件は推測せず、2〜3 案の比較表と推奨案を提示して人間へ確認する（未決事項は 4 分類の `Open Questions` に残す）。
   - `domain/` がプロジェクトルートに存在する場合のみ、`concept-test` および `domain-sync` で承認済みコンテキスト・用語を同期する（`domain/` 不在時は `domain-sync skipped: no domain/ directory` としてオーバーヘッドゼロでスキップ）。`design-system/` が存在する場合も既存規約へ整合させる。SQL / DB 変更を含む場合は `sdd-implementation` の `sql-develop` 参照ポリシーを確認する。

2. **タスク単位のリスク判定と試作/本番昇格モード（`--proto` / `--harden`）**:
   - `--risk` 指定があればそれを優先（`--lite` / `--proto` → `low`、`--full` / `--harden` → `high` または既存確定仕様を引き継いだ `standard|high`）。
   - **`--proto`（仕様探索・試作モード）**: `Risk: low` 相当で高速に動くプロトタイプ仕様を生成する。AI が仮決めした判断はすべて `OQ-NNN`（`Provisional`）に残し、人間が実物確認後に判断できるよう整理する。
   - **`--harden`（本番品質昇格モード）**: 既存仕様をゼロから作り直さず、確定済み `OQ-NNN`（`Confirmed`）を引き継いだうえで、`design.md` に非機能・セキュリティ・SQL 移行・Cloud 監視・回帰テスト設計を追記して `Risk: standard|high` タスクへ再構成する。前提コンテキストに根本的な不整合が見つかった場合は躊躇なく **Scrap & Build** を人間へ提案する。
   - 未指定時は `sdd/guardrails.yaml` の `risk_defaults` と変更内容から判定する:
     - `low`: 小規模バグ修正（`diagnose` 経由等）、ドキュメント、限定リファクタ
     - `standard` *(既定)*: 通常の新機能・API/UI 追加・中規模変更
     - `high`: `high_risk_paths` 該当、または認証/認可・決済・PII・DB 移行・破壊的契約変更

3. **3 ファイル生成（`specs/<feature>/`）**:
   - `templates/requirements.md` → `specs/<feature>/requirements.md`:
     全 `REQ-NNN` に観測・テスト可能な `AC-NNN` を紐付け、末尾に `## Spec Amendments` を置く。
   - `templates/design.md` → `specs/<feature>/design.md`:
     **SSoT はソースコード**（詳細設計をソースと二重管理しない）。概要設計として方針・変更ファイル・モジュール跨ぎ契約・**採らなかった設計（Alternatives Rejected）**・影響範囲・テスト方針・`## Spec Amendments` のみを記載する（`Risk: high` を含む場合はセキュリティ・移行・ロールバック方針を明記し、必要に応じ `docs/adr/` へ ADR を作成）。
   - `templates/tasks.md` → `specs/<feature>/tasks.md`:
     各タスクに `Approval: Draft`、`Status: Planned`、`Risk: low|standard|high`、`### Scope`（実装ファイルおよび対応テストファイル）、`### Done When`（対応 `AC-NNN` 参照）、`### Blockers`、末尾に `## Spec Amendments` を記載する。

## Boundaries

- `Approval: Approved` は絶対に書き込まない。
- アプリケーションの実装コードは編集しない。
- 追加の設計文書（ADR や詳細テスト表）は `Risk: high` など必要時のみ作成する。

## Handoff

生成パス、各タスクの `Risk:`、未解決の `Open Questions` を `bootstrap` へ返す。
