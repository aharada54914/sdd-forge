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

- ルートに `AGENTS.md` が存在すること（不在時は `/sdd-bootstrap:sdd-adopt` を案内して停止）。
- `sdd/guardrails.yaml`（または `sdd/guardrails.json`）が存在すれば読み、不在時は既定値（`default_tier: standard`）を使用する。

## Process

1. **要件整理と既存コード調査**:
   - 出典（Issue / 要件テキスト / `investigation.md` / `reports/diagnosis/*.md`）と関連コードを確認する。
   - 重要な設計分岐や曖昧な要件は推測せず、2〜3 案の比較表と推奨案を提示して人間へ確認する（未決事項は `Open Questions` に残す）。
   - `domain/` がプロジェクトルートに存在する場合のみ、`concept-test` および `domain-sync` で承認済みコンテキスト・用語を同期する（`domain/` 不在時は `domain-sync skipped: no domain/ directory` としてオーバーヘッドゼロでスキップ）。`design-system/` が存在する場合も既存規約へ整合させる。SQL / DB 変更を含む場合は `sdd-implementation` の `sql-develop` 参照ポリシーを確認する。

2. **タスク単位のリスク判定（`Risk: low | standard | high`）**:
   - `--risk` 指定があればそれを優先（`--lite` → `low`、`--full` → `high`）。
   - 未指定時は `sdd/guardrails.yaml` の `risk_defaults` と変更内容から判定する:
     - `low`: 小規模バグ修正（`diagnose` 経由等）、ドキュメント、限定リファクタ
     - `standard` *(既定)*: 通常の新機能・API/UI 追加・中規模変更
     - `high`: `high_risk_paths` 該当、または認証/認可・決済・PII・DB 移行・破壊的契約変更

3. **3 ファイル生成（`specs/<feature>/`）**:
   - `templates/requirements.md` → `specs/<feature>/requirements.md`:
     全 `REQ-NNN` に観測・テスト可能な `AC-NNN` を紐付け、末尾に `## Spec Amendments` を置く。
   - `templates/design.md` → `specs/<feature>/design.md`:
     方針・変更ファイル・IF/データ契約・影響範囲・テスト方針・`## Spec Amendments` を記載する（`Risk: high` を含む場合はセキュリティ・移行・ロールバック方針を明記し、必要に応じ `docs/adr/` へ ADR を作成）。
   - `templates/tasks.md` → `specs/<feature>/tasks.md`:
     各タスクに `Approval: Draft`、`Status: Planned`、`Risk: low|standard|high`、`### Scope`、`### Done When`（対応 `AC-NNN` 参照）、`### Blockers`、末尾に `## Spec Amendments` を記載する。

## Boundaries

- `Approval: Approved` は絶対に書き込まない。
- アプリケーションの実装コードは編集しない。
- 追加の設計文書（ADR や詳細テスト表）は `Risk: high` など必要時のみ作成する。

## Handoff

生成パス、各タスクの `Risk:`、未解決の `Open Questions` を `bootstrap` へ返す。
