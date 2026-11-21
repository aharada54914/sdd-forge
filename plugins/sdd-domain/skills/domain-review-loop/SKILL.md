---
name: domain-review-loop
description: Independent 2-perspective parallel review of a domain/ model (strategic domain-reviewer-a + tactical domain-reviewer-b). Validates boundaries, concepts, ubiquitous language, aggregate invariants, and message flows before human approval of Domain-Model-Status: Approved.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `/sdd-domain:domain-model review`（および `new` / `reverse` / `update` 完了後の確認）から呼び出される内部スキル。`Domain-Model-Status: Approved` は絶対に書き込まない（人間承認専用、`sdd-soft-guard.mjs` が保護）。

# Domain Review Loop

`domain/` 配下のドメインモデル成果物を決定論検証＋独立 2 視点並列レビューで点検し、人間承認前の欠陥を検出する。

## Preconditions

1. 7 ステージの正本成果物（`domain/{domain-story,event-storming,concept-model,ubiquitous-language,context-map,message-flow}.md`, `domain/aggregates/*.md`）および `domain/domain-contract.json` が存在すること。
2. まず `plugins/sdd-domain/scripts/validate-domain-contract.sh domain/domain-contract.json`（Windows は `.ps1`）で v2 スキーマ・参照整合の決定論チェックを実行し、非ゼロ終了ならエラー内容を示して停止する。
3. `domain/context-map.md` が既に `Domain-Model-Status: Approved` の場合、モデル変更の再レビューを行う前に人間が `Domain-Model-Status: Pending` へ戻していることを確認する。

## Review Perspectives（2 視点独立並列・1 パス）

独立した 2 コンテキスト（Read-Only）で並列レビューを実行し、1 枚のレポートへ統合する（並列未対応ホストでは別コンテキストで順次実行し、第 2 視点を省略しない）。各レビュアーには他方の生出力を見せない:

- **`domain-reviewer-a`（戦略・概念モデル観点）**:
  - コンテキスト境界の明確さ（`CONTEXT-BOUNDARY-CLARITY`）、Context Map 関係パターンの妥当性（`RELATION-PATTERN-VALID`）、コンテキスト横断イベント網羅性（`EVENT-COVERAGE`）、ユビキタス言語のコンテキスト内一意性・禁止同義語衝突（`TERM-UNIQUENESS`）、集約の単一コンテキスト所有（`AGGREGATE-CONTEXT-OWNERSHIP`）、`Domain-Model-Status` 宣言（`DOMAIN-MODEL-STATUS-PRESENT`）
  - v2 Concept Model 整合: 概念区別の根拠一致（`CONCEPT-DISTINCTION-JUSTIFIED`）、多重責務・`must_not_own` 矛盾（`MULTI-ROLE-CONCEPT`）、ステークホルダー視点カバレッジ（`STAKEHOLDER-PERSPECTIVE-COVERAGE`）、命名適合（`NAME-SEMANTIC-FIT`）
- **`domain-reviewer-b`（戦術・実装可能性観点）**:
  - 集約不変条件のテスト可能性（`INVARIANT-VERIFIABLE`）、トランザクション境界の現実性（`TRANSACTION-BOUNDARY-REALISTIC`）、God Aggregate 防止（`NO-GOD-AGGREGATE`）、Anemic Model 防止（`NO-ANEMIC-MODEL`）、ライフサイクル定義（`LIFECYCLE-DEFINED`）、集約サイズの妥当性（`AGGREGATE-SIZE-PROPORTIONATE`）

下流仕様の欠陥ではなく承認済み概念モデル自体の見直しが必要な指摘は `UPSTREAM_CONCEPT_ISSUE` として扱い、人間へ `domain-model update` を案内する。

## Verdict & Output

統合レポートを `reports/domain-review/latest.md` に書き出し、ファイルの実在と非空を確認してから返す:
- 両レビュアーとも Critical / Major（Blocker）なし → `PASS`（Minor のみなら `PASS_WITH_NOTES`）。`domain/context-map.md` の `Domain-Model-Status:` を `Reviewed` に更新し、人間へ `Domain-Model-Status: Approved` への承認を依頼する。
- いずれかに Critical / Major あり → `NEEDS_FIX`。Blocker と修正案を人間へ提示して停止（`domain/` 修正後に再度 `/sdd-domain:domain-model review` を実行）。

## Boundaries

- `Domain-Model-Status: Approved` は絶対に書き込まない（人間のみ）。
- レビュアーは `domain/` 成果物本文やステータスを書き換えない（`Reviewed` 遷移およびレポート出力は親オーケストレータの責務）。
- 外部クロスモデル送信や権限昇格トークンによるロック解除は行わない。
