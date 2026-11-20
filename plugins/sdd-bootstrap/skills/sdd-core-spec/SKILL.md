---
name: sdd-core-spec
description: Generate concise, implementation-ready SDD Core specifications (requirements with testable ACs, design, and risk-tiered tasks) under specs/<feature>/. Invoked internally by /sdd-bootstrap:bootstrap.
disable-model-invocation: false
user-invocable: false
---

# SDD Core Spec

SDD Forge v2（ADR-0051）の標準仕様生成スキル。旧 `sdd-bootstrap-interviewer`（7層フル仕様）と旧 `lite-spec`（簡易3ファイル）を統合し、過不足のない 3 ファイル構造（必要時のみ `acceptance-tests.md` / ADR を追加）を生成する。

## Preconditions

- リポジトリルートに `AGENTS.md` が存在すること（未整備時は `/sdd-bootstrap:sdd-adopt` を案内）。
- `sdd/guardrails.yaml`（または `sdd/guardrails.json`）が存在すれば読み、不在時は既定値（`default_tier: standard`）を使用する。
- カナリアハンドシェイクや `project-context.approval.json` の検証は不要。

## Process

1. **要件の整理と不明点の確認**:
   - 出典（Issue / 要件テキスト / `investigation.md` / `reports/diagnosis/*.md`）を読み、既存コードベースの関連箇所を確認する。
   - 重要な設計判断・曖昧な要件がある場合は、推測で決めず 2〜3 案の比較表＋推奨案を示して人間に確認する（未決事項は `Open Questions` に残す）。
   - `design-system/` や `domain/` が存在するプロジェクトでは、既存のトークン・ユビキタス言語に整合させる（不在時はオーバーヘッドゼロでスキップ）。
   - SQL / DB スキーマ変更を含む場合は、`sdd-implementation` の `sql-develop` 参照ポリシーを確認する。

2. **リスク階層の判定（タスク単位）**:
   - 既定は `sdd/guardrails.yaml` の `risk_defaults.default_tier`（既定 `standard`）。
   - 以下の目安でタスクごとの `Risk:` を設定する:
     - `low`: 小規模バグ修正（`diagnose` 経由等）、ドキュメント、限定的なリファクタ
     - `standard`: 通常の新機能・API/UI 追加・中規模変更
     - `high`: `risk_defaults.high_risk_paths` に該当する変更、または認証/認可・決済・PII・DB マイグレーション・公開契約の破壊的変更
   - `--risk low|standard|high` が明示指定された場合はそれを優先する（旧 `--lite` は `low`、旧 `--full` は `high` のヒントとして扱う）。

3. **SDD Core 成果物の生成（`specs/<feature>/`）**:
   - `templates/requirements.md` に従い `specs/<feature>/requirements.md` を生成:
     - `REQ-NNN` と、すべての要件に対応する観測・テスト可能な `AC-NNN` を必ず記載する。
     - `## Spec Amendments` セクションを末尾に含める。
   - `templates/design.md` に従い `specs/<feature>/design.md` を生成:
     - 方針・変更ファイル一覧・IF/データ契約・影響範囲・テスト方針を簡潔に記載する。
     - `Risk: high` のタスクを含む場合は、セキュリティ・移行・ロールバック観点と必要に応じた ADR (`docs/adr/`) を記載する。
   - `templates/tasks.md` に従い `specs/<feature>/tasks.md` を生成:
     - 各タスクに `Approval: Draft`、`Status: Planned`、`Risk: low|standard|high`、`### Scope`、`### Done When`（対応する `AC-NNN` を明記）、`### Blockers` を記載する。
     - アプリの実装コードはまだ書かない。

## Boundaries

- `Approval: Approved` は絶対に書き込まない（人間のみが承認する）。
- `traceability.md`・`ux-spec.md`・`frontend-spec.md`・`infra-spec.md`・`security-spec.md` の強制生成は行わない（必要な場合のみ任意追加）。
- 実装フェーズのファイル編集は行わない。

## Handoff

生成した `specs/<feature>/{requirements,design,tasks}.md` と各タスクの `Risk:`、未解決の `Open Questions` を呼び出し元（`bootstrap`）へ返す。
