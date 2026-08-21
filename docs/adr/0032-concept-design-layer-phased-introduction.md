# ADR 0032: Concept Design Layer — Concept を一級モデル要素として段階導入する

## Status

Accepted

## Context

sdd-domain の domain-contract/v1 は contexts / terms / aggregates /
relations を表現するが、概念そのもの — 「その世界に何が存在するか」
「何と何を同じ/別のものとして扱うか」「その概念が持ってよい責務と
持ってはならない責務」 — を表現できない。Zenn 記事「概念設計が、その後の
コードの命運を左右する」(2026-08-14) を仕様上の基準とし、記事本体と
導入計画原案の 2 段階の敵対的レビューを実施した
(`reports/notes/concept-design-article-adversarial-review.md`,
`reports/notes/concept-design-layer-plan-adversarial-review.md`)。
レビューの結果、原案の中核は堅牢と確認される一方、実装順の価値逆転・
LLM 判定への直接 fail-closed・レビュー契約への破壊半径などの構造問題を
修正した 5 フェーズ計画に再構成した（tracking: issue #290）。

## Decision

- Concept を Context / Aggregate と同格の一級モデル要素にする。
  Term ≠ Concept: term は概念につけた canonical name であり、v2 で
  `term.concept_id` により概念へ連結する。
- `contracts/domain-contract.v2.schema.json` を v1 と共存する別ファイル
  として追加する（v1 は全階層 `additionalProperties: false` のため
  in-place 拡張不能）。concept は id / name / context（単一所属）/
  definition / essence / responsibilities / must_not_own /
  stakeholder_perspectives / distinguished_from / evidence を持つ。
- 概念の same / different / undecided 判断は常に人間確認必須。仮想の
  未来シナリオのみを根拠とする概念の自動追加は禁止する。
- v2 プロジェクトのゲート BLOCK 条件は決定論（concept-test 記録と
  human decision の存在）とし、LLM 判定そのものでは BLOCK しない。
  LLM による概念整合チェックは既存の LLM レビューゲート（spec-review、
  concept-test）に載せ、決定論 quality-gate へは入れない。
- 導入は 5 フェーズ（Phase 0 contract → 1 concept-test → 2 authoring →
  3 review v2 → 4 reverse/C4 分離）。各フェーズは独立 feature として
  3 段階レビューを通す。「Concept Test 完成」をもって最小完成とする。
- owner 決定（2026-08-16）: v1 契約インスタンスは存在しないため、
  v1 → v2 の移行ツール・二重バージョンローダー・versioned stage table は
  作らない。consumer の v2 切替は各フェーズで一括に行う。

## Consequences

- Phase 0 は加算のみ（schema + validator twins + テスト）で、既存
  プラグイン挙動・保護ファイル・リリース面に触れない。
- Phase 1 以降で skill 追加（三重マニフェスト・marketplace・
  validate-repository 期待値の更新）とレビュー契約の拡張が発生する。
  concept artifact のレビュー入力追加は audit-against-the-record 方式
  （WFI-027 の裁定）に従う。
- v2 採用自体が Concept Governance へのオプトインとなる（`domain/` 不在
  プロジェクトと v1 は挙動不変）。
- C4 Container は Problem Space の canonical stage から段階的に外れ、
  bootstrap の architecture 責務へ移る（Phase 4、2 リリース互換期間）。
