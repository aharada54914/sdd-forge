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

### 人による承認と契約の発行

初回と更新後とも、`PASS` または `PASS_WITH_NOTES` の `reports/domain-review/latest.md` と `Reviewed` の正本を人が確認する。人が承認を選んだら、レビュー時の正本と契約の内容に変更がないことを確認し、本人が次を行う。

1. `domain/context-map.md` の `Domain-Model-Status: Reviewed` を `Approved` に変える。未レビューの `Pending`、`NEEDS_FIX`、またはレビュー後に本文が変わった場合は `domain-model review` へ戻る。
2. 同じ版の `domain/domain-contract.json` を一時ファイルにコピーし、本人が `meta.status` を `Approved`、`meta.version` を次のパッチ版にする。他の内容と `meta.generated_from` の入力がレビュー済みの版に一致することを確認する。すでに同じ承認済み内容が発行済みなら再発行は不要。
3. interviewer の「`domain-contract.json` (v2) 再生成」と同じ配布 `scripts/validate-domain-contract.sh <candidate>`（Windows は `.ps1`）で検証する。入力が同じ版のままで、終了値が 0 の場合だけ、本人が一時ファイルで契約を原子的に置換する。失敗・入力変更なら既存の契約を保持し、先に原因を解決する。
4. 正本と契約の両方が `Approved` の現在の入力から Concept Test 提案を作る。発行前の提案は旧入力に結び付いている。

## Boundaries

- `Domain-Model-Status: Approved` は絶対に書き込まない（人間のみ）。
- レビュアーは `domain/` 成果物本文やステータスを書き換えない（`Reviewed` 遷移およびレポート出力は親オーケストレータの責務）。
- 外部クロスモデル送信や権限昇格トークンによるロック解除は行わない。

## Contract Boundary: Public v2 Single-Pass vs. Historical v1 Scripts

- 本スキル（公開 v2 単一パス経路）は、`domain-reviewer-a` / `domain-reviewer-b` から 4 キー JSON（`schema: "domain-reviewer-{a,b}/v2"`, `role`, `verdict: "PASS" | "PASS_WITH_NOTES" | "NEEDS_FIX"`, `checks`）を並列受領し、統合レポートを `reports/domain-review/latest.md` へ出力する。
- 同梱の旧 v1 互換スクリプト（`plugins/sdd-domain/scripts/domain-review-precheck.{sh,ps1}` および `plugins/sdd-domain/scripts/finalize-domain-review.{py,sh,ps1}`）は **本スキルの現行 v2 出力（`domain-reviewer-{a,b}/v2` JSON や `reports/domain-review/latest.md`）を受理しない**。旧 v1 経路は `reports/domain-review/attempt-<N>/round-<M>/precheck-result.json`（`domain-review-precheck/v1`）、`reports/review-context/identity-ledger.json` による順次予約と `reviewer-{a,b}-invocation.json`、8 キーの `reviewer-{a,b}.json`（`schema: "domain-reviewer-{a,b}/v1"`, `verdict: "PASS" | "NEEDS_WORK" | "BLOCKED"`）、および Reviewer A からの `--mode summary`（`integrated-summary.json`）を要求する別契約であり、v2 単一パス経路と混用しない。
