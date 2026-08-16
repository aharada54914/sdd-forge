# Requirements: sdd-domain-concept-contract

Spec-Review-Status: Pending
Source Issue: https://github.com/aharada54914/sdd-forge/issues/290
Epic: https://github.com/aharada54914/sdd-forge/issues/290 (Concept Design
Layer — Phase 0: Concept Contract Foundation)
Investigation: specs/sdd-domain-concept-contract/investigation.md
(INV-001..INV-012, OQ-001..OQ-004)

## Overview

sdd-domain の domain-contract に **Concept を一級モデル要素として表現できる
v2 スキーマ**を追加する。現行 v1 は contexts[] / terms[] / aggregates[] /
relations[] のみで、「Order とは何か」「Fulfillment と何が違うのか」
「Fulfillment に価格を持たせてはいけない」という概念境界そのものを表現
できない（INV-001, INV-002）。v1 はすべての階層で
`additionalProperties: false` を宣言しているため in-place 拡張は不可能で
あり（INV-001）、`contracts/domain-contract.v2.schema.json` を**加算的な
別ファイル**として追加する。あわせて、後続 Phase（concept-test の決定論
ゲート、reviewer の記録照合チェック）が前提にする**決定論 validator**
（sh/ps1 twins）と、Purchase/Fulfillment・Book/Bookshelf を核とする
**fixture corpus**、および v2 契約テストを整備する。

v1 の consumer 4 系統（domain-sync / reviewer A / interviewer /
check-domain-conformance — INV-004）は Phase 0 では**一切変更しない**。
owner 決定（2026-08-16）により v1 資産は存在しないものとして扱い、
v1 → v2 のアーティファクト移行設計・二重バージョンローダーは作らない
（INV-009）。

## Target Users

- **後続 Phase の実装者**（Phase 1 concept-test / Phase 2 authoring /
  Phase 3 review v2）— concepts[] の型・検証規則・fixture が先に固定されて
  いることで、各 Phase が契約の再設計なしに積み上げられる。
- **ドメインモデル作成者**（当面は手書きで concepts[] を作成する owner /
  dogfood 利用者）— 手書き契約の妥当性を validator で決定論的に自己検査
  できる。
- **domain-review-loop の将来のレビュアー**（Phase 3）— MULTI-ROLE-CONCEPT
  等の記録照合チェックの入力型が確定する。

## Problems

- P1: v1 契約は概念の責務（responsibilities）・非責務（must_not_own）・
  区別理由（distinguished_from）を表現できず、記事のいう「一概念二役」を
  契約レベルで検出する基盤がない（INV-002）。
- P2: term と concept が未分離のため、「"Order" という語」と「Order という
  概念」を区別できない（INV-002）。
- P3: 契約の決定論 validator が存在せず（INV-011）、Phase 1 の決定論ゲート
  （concept-test 記録の存在検査）を築く土台がない。

## Goals

- G1: `contracts/domain-contract.v2.schema.json` を追加し、concepts[] を
  required のトップレベル配列として定義する（REQ-001, REQ-002）。
- G2: term から concept への連結（`concept_id`）を v2 で表現可能にする
  （REQ-003）。
- G3: JSON Schema では表現できない相互参照整合（重複 ID・宙吊り参照・
  自己矛盾）を検査する決定論 validator を sh/ps1 twins で追加する
  （REQ-004）。
- G4: 後続 Phase が再利用する fixture corpus（正例・負例）をテストと共に
  整備する（REQ-005, REQ-006）。
- G5: v1 スキーマ・v1 consumer・既存テストを一切変更しない加算的変更に
  留める（REQ-007）。

## Non-goals

- concept-test skill / bootstrap 統合（Phase 1）。
- concept-model.template.md / interviewer のステージ変更（Phase 2）。
- reviewer A/B のチェック追加・calibration 変更（Phase 3）。
- reverse mode / C4 分離（Phase 4）。
- v1 → v2 の移行ツール・二重バージョンローダー（owner 決定により恒久的に
  スコープ外。INV-009）。
- `domain/` アーティファクト（Markdown 側）の生成・変更 — Phase 0 は
  契約（JSON スキーマ）とその検証系のみ。

## User Stories

- US-001: 後続 Phase の実装者として、concepts[] の型と検証規則が確定して
  いてほしい。なぜなら concept-test の判定（RESPONSIBILITY_CONFLICT 等）は
  responsibilities / must_not_own の型に直接依存するからだ。
- US-002: ドメインモデルを手書きする owner として、書いた契約が概念
  レベルで自己矛盾していないか（同一責務の二重所属・宙吊り参照）を
  コマンド一発で検査したい。
- US-003: 将来のレビュアー（人間・エージェント双方）として、「同じ名前
  でもコンテキストが違えば別概念」を契約で表現できてほしい。なぜなら
  記事の中核例（受注の Order と出荷の履行）がまさにそれだからだ。

## Acceptance Criteria

REQ-001: `contracts/domain-contract.v2.schema.json` が存在し、draft-07・
`schema` const `domain-contract/v2`・root required は
`schema` / `meta` / `contexts` / `concepts`。meta は v1 と同形
（version / status / generated_from）。contexts / relations は v1 の
boundedContext / contextRelation 定義を維持した上で、term にのみ
`concept_id`（optional）を追加する。

REQ-002: concept 定義は次を持つ。required: `id`（pattern
`^CONCEPT-[A-Z][A-Z0-9-]*$`）、`name`（PascalCase）、`context`
（kebab-case、宣言済み context 名を指すこと — 参照整合は validator が
検査）、`definition`、`essence`、`responsibilities`（minItems 1）、
`evidence`（minItems 1）。optional: `must_not_own[]`、
`stakeholder_perspectives[]`（required: actor / concern）、
`distinguished_from[]`（required: concept_id / reasons、reasons minItems 1）。
concept は**単一コンテキスト所属**とする（設計根拠は design.md DD-1）。

REQ-003: v2 の term 定義は v1 の 4 フィールドに `concept_id`（optional、
pattern は REQ-002 の id と同一）を加えたもの。concept_id を持つ term の
宙吊り参照は validator がエラーにする。

REQ-004: 決定論 validator `plugins/sdd-domain/scripts/
validate-domain-contract.sh` / `.ps1` を追加する。入力は契約 JSON の
パス 1 つ。検査項目: (a) JSON として可読、(b) `schema` 値が
`domain-contract/v2`（それ以外は明示エラー — OQ-004 提案）、(c) スキーマ
必須項目・パターンの構造検査（hand-rolled、外部依存なし — INV-005 の
house pattern）、(d) concept id の重複、(e) `concept.context` の宙吊り、
(f) `distinguished_from.concept_id` の宙吊り、(g) `term.concept_id` の
宙吊り、(h) 同一 concept 内で同一文字列が responsibilities と
must_not_own の両方に出現する自己矛盾、(i) 同一 context 内の concept
`name` 重複（**異なる** context 間の同名は許可 — INV-012）。exit 0 /
非 0 の fail-closed。すべての違反は 1 行 1 件で標準エラーに列挙する。

REQ-005: fixture corpus を v2 契約テスト内に整備する（mktemp スコープ、
INV-006 の規約踏襲）。最低限: (a) Purchase/Fulfillment の正例
（Order concept が purchase 責務のみ・Fulfillment concept が delivery
責務のみ・相互 distinguished_from・Fulfillment.must_not_own に
purchase price）、(b) Book/Bookshelf の正例（Book.must_not_own に
display position、Placement concept が並び責務を持つ）、(c) 同名別概念の
コンテキスト横断正例（2 つの context に同名 concept）、(d) REQ-004 の
検査項目 (d)〜(i) それぞれを 1 つずつ踏む負例。

REQ-006: `tests/sdd-domain/contract-v2-schema.Tests.ps1` を追加し、
REQ-005 の全 fixture を validator（.ps1 側）と構造 assertion の両方で
検証する。加えて sh/ps1 twins の verdict 一致（同一 fixture 集合に対する
exit code / エラー件数の一致）を検査する。

REQ-007: 加算的変更の保証: `contracts/domain-contract.v1.schema.json`・
INV-004 の consumer 4 系統・既存 `tests/sdd-domain/*.Tests.ps1` 11 スイート
は本 feature で 1 バイトも変更しない。既存 `contract-schema.Tests.ps1`
（v1）は変更なしで green のまま。

## Field Definitions

| Field | Type | Required | 意味 |
|---|---|---|---|
| concepts[].id | string `^CONCEPT-[A-Z][A-Z0-9-]*$` | Yes | 概念の安定 ID。distinguished_from / term.concept_id の参照先 |
| concepts[].name | string PascalCase | Yes | canonical name（概念につけた名前。概念そのものではない） |
| concepts[].context | string kebab-case | Yes | 所属する bounded context（単一所属。DD-1） |
| concepts[].definition | string | Yes | その概念が現実の何を切り取ったか |
| concepts[].essence | string | Yes | 概念の本質の 1 行言語化（OQ-003 提案: required） |
| concepts[].responsibilities[] | string[] minItems 1 | Yes | この概念が持ってよい責務 |
| concepts[].must_not_own[] | string[] | No | この概念に載せてはならない責務（明示契約化） |
| concepts[].stakeholder_perspectives[] | {actor, concern}[] | No | 関係者ごとの見え方（概念境界の発見根拠） |
| concepts[].distinguished_from[] | {concept_id, reasons[]}[] | No | 別概念である理由の記録 |
| concepts[].evidence[] | string[] minItems 1 | Yes | domain-story / event / issue 等への根拠参照 |
| contexts[].terms[].concept_id | string | No | この term が名指す concept（v2 で追加） |

## Roles and Permissions

- 契約 JSON の作成・編集: 人間（当面は手書き。Phase 2 以降は
  domain-interviewer が生成）。
- validator の実行: 人間・エージェント・後続 Phase のゲート（読み取り
  専用・stdout/stderr のみ）。
- 本 feature の成果物はいずれも hook-guard 保護対象外（INV-008）で
  agent 編集可能。ただし承認系フィールドは扱わない（meta.status の
  Approved 書込制御は既存どおり v1/v2 共通で hook guard と人間の責務）。

## Main Workflows

1. 作成者が v2 契約 JSON を書く（または後続 Phase のツールが生成する）。
2. `validate-domain-contract.sh <path>`（または .ps1）を実行する。
3. exit 0 なら後続工程（Phase 1 以降のゲート・レビュー）へ。非 0 なら
   標準エラーの違反一覧（1 行 1 件）を直して再実行。

## Edge Cases

- concepts が空配列: v2 では invalid（minItems 1）。concept を持たない
  プロジェクトは v1 に留まる（v2 採用自体が Concept Governance への
  オプトイン — 親計画 §17）。
- 異なる context 間の同名 concept: 有効（INV-012。受注 Order / 出荷側
  概念の同名ケース）。同一 context 内の同名: invalid。
- must_not_own が空/欠落: 有効（初期は責務だけ列挙し、境界事故のたびに
  must_not_own を追記していく運用を許す）。
- distinguished_from が自分自身を指す: invalid（validator (f) の一部と
  して検査）。
- 契約ファイルが 10MB を超える等の異常入力: validator は fail-closed で
  非 0 終了（best-effort パースをしない）。
- validator に v1 契約を渡す: 明示エラー「schema is domain-contract/v1;
  this validator checks v2 only」（OQ-004 提案）。

## Security Boundaries

- 契約 JSON の内容は常に**データ**であり、validator・テストは内容を
  命令として解釈しない（sdd-domain 全体の content-as-data 規約を踏襲）。
- validator は読み取り専用・ネットワークアクセスなし・外部依存なし
  （bash 側は python3 stdlib の json のみ、ps1 側は ConvertFrom-Json のみ
  — design.md DD-4）。
- fixture に秘密情報・実在の個人情報を含めない。

## Assumptions

- 本スペックは hook 未導入セッションで生成された: hook-activation
  handshake は `CAPABILITY_RUNTIME_UNAVAILABLE`（WRITE_EXECUTED）を返した
  （INV-010）。`sdd/project-context.yaml` は物理不在のため track 解決は
  C1 `COMPATIBILITY_FALLBACK`（full profile）であり、capability mode は
  そもそも係属しない。この逸脱は owner の明示指示（2026-08-16、本
  スペック化の直接依頼）に基づき記録の上続行した。spec-review 以降の
  ゲートは hook 有効環境で実行すること。
- v1 契約インスタンスは存在しない（owner 決定、INV-009）。
- 後続 Phase は本 feature の schema / validator を変更せずに積み上げる
  （変更が必要になった場合は当該 Phase で本契約の改版を明示的に扱う）。

## Open Questions

investigation.md の OQ-001..OQ-004 を参照（それぞれ提案つき）。
spec-review までに人間が確定する。

## Risks

- R1（低）: concepts[] の型が後続 Phase の実装で不足と判明し、v2 の改版が
  必要になる。緩和: fixture corpus を先に書き、Phase 1 の判定 4 種
  （FITS/NEW_CONCEPT/CONFLICT/HUMAN_DECISION）が必要とするフィールドを
  受け入れテストで先取り検証する。
- R2（低）: hand-rolled validator と JSON Schema ファイルの乖離ドリフト。
  緩和: REQ-006 のテストが schema ファイルの required/pattern 宣言と
  validator の挙動を同一 fixture で突き合わせる（WFI-028 と同型の
  drift lock を負例 fixture で実現）。
- R3（低）: sh/ps1 twins の判定不一致。緩和: REQ-006 の twin parity
  検査（同一 fixture・同一 verdict）。
