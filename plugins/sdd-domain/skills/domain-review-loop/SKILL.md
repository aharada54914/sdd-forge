---
name: domain-review-loop
description: Independent 2-perspective parallel review of a domain/ model (strategic domain-reviewer-a + tactical domain-reviewer-b). Validates boundaries, ubiquitous language, aggregate invariants, and message flows before human approval of Domain-Model-Status: Approved.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `domain-model` から呼び出される内部スキル。`domain/context-map.md` の `Domain-Model-Status: Approved` は絶対に書き込まない（人間承認のみ、`sdd-soft-guard.mjs` が保護）。

# Domain Review Loop

`domain/` 配下のドメインモデル成果物を独立した 2 視点でレビューし、人間承認前の欠陥を検出する。

## Preconditions

1. `domain/context-map.md`・`domain/domain-contract.json` および対象モデル成果物が存在すること。
2. まず `plugins/sdd-domain/scripts/validate-domain-contract.sh`（または `.ps1`）でスキーマ・整合性の決定論チェックを実行し、エラーがあれば修正を促して停止する。
3. 承認済みモデル（`Domain-Model-Status: Approved`）に対して更新レビューを行う場合は、人間が `Domain-Model-Status: Pending` へ戻していることを確認する。

## Review Perspectives（2 視点並列・1 パス）

独立した 2 コンテキストで並列レビューを実行し、1 枚のレポートへ統合する（並列未対応ホストでは順次 2 パス実行、第 2 視点を省略しない）:

- **`domain-reviewer-a`（戦略観点）**: コンテキスト境界の妥当性、Context Map の関係パターン整合性、イベント網羅性、ユビキタス言語の一意性・禁止同義語の明確さ。
- **`domain-reviewer-b`（戦術観点）**: 集約（Aggregate）の不変条件の検証可能性、トランザクション境界の現実性、God Aggregate / Anemic Model リスク、メッセージフローの一貫性。

## Verdict & Output

統合判定（`PASS` / `PASS_WITH_NOTES` / `NEEDS_FIX`）を `reports/domain-review/latest.md` に記録する:
- 両レビュアーとも Blocker なし → `PASS`（軽微な指摘のみなら `PASS_WITH_NOTES`）。`Domain-Model-Status: Reviewed` へ更新し、人間へ `Domain-Model-Status: Approved` への承認を依頼する。
- いずれかに Blocker あり → `NEEDS_FIX`。Blocker と修正案を人間へ提示し、`domain/` 修正後に再度 `domain-review-loop` を実行する。

## Boundaries

- `Domain-Model-Status: Approved` は絶対に書き込まない（人間のみ）。
- 外部クロスモデル送信や権限昇格トークンによるロック解除は行わない。
- `domain/` 成果物本文をレビュアー自身が勝手に書き換えない。
