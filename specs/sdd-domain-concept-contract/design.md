# Design: sdd-domain-concept-contract

Impl-Review-Status: Passed
Feature Type: additive contract + deterministic validator + test corpus
（プラグイン挙動の変更なし）

## Technical Summary

3 つの加算的成果物を追加する: (1) `contracts/domain-contract.v2.schema.json`
— concepts[] を一級要素とする新スキーマファイル（v1 は無変更で共存）、
(2) `plugins/sdd-domain/scripts/validate-domain-contract.{sh,ps1}` — JSON
Schema では表現できない相互参照整合まで検査する決定論 validator twins、
(3) `tests/sdd-domain/contract-v2-schema.Tests.ps1` — fixture corpus を
内蔵する契約テスト。v1 consumer（domain-sync / reviewer A / interviewer /
check-domain-conformance — INV-004）には触れない。後続 Phase はこの契約を
前提に積み上がる: Phase 1 の concept-test は responsibilities /
must_not_own を判定材料に、Phase 3 の reviewer 記録照合チェックは
distinguished_from / evidence を照合対象にする。

## Design Decisions

| ID | 決定 | 根拠 |
|---|---|---|
| DD-1 | concept は**トップレベル配列 + required `context` フィールド**で単一コンテキスト所属（aggregates のようなネストにしない） | `distinguished_from` はコンテキスト横断参照を持つ（受注 Order vs 出荷側概念）。ネストだと横断参照の解決規則が二段になる。単一所属の強制は validator (e) が担う。plan レビュー P-7 の解決。参照整合は JSON Schema (draft-07) では表現できないため、所属もスキーマではなく validator の責務とする（INV-003） |
| DD-2 | 二重バージョンローダーは作らない。consumer の v2 切替は各 Phase で一括 | owner 決定（2026-08-16）: v1 資産は存在しない。v1 スキーマファイルの削除判断は最後の consumer が切り替わる Phase 3 で行う（OQ-001） |
| DD-3 | v2 スキーマファイルは v1 の定義（boundedContext / term / aggregate / contextRelation）を**複製して内包**し、v1 ファイルへの `$ref` はしない | 2 ファイル間 `$ref` は hand-rolled 検証の house pattern（INV-005）と相性が悪く、v1 削除（OQ-001）時に v2 が壊れる結合を作る。複製ドリフトは TEST-001/TEST-002 の構造 assertion で拘束 |
| DD-4 | validator の実装: bash 側は `python3` stdlib（json）を 1 回起動して全検査を実行、ps1 側は `ConvertFrom-Json` + 構造走査。外部依存（jq / ajv / Test-Json）を導入しない | INV-005 の house pattern（外部 schema エンジン不使用）。python3 は本リポジトリの既存スクリプト群が既に前提とするランタイム。PS5.1-safe（Test-Json は PS6+） |
| DD-5 | fixture は suite 内ヒアストリング + mktemp 展開。恒久 fixtures ディレクトリを作らない | INV-006 の既存規約。Phase 3 での corpus 共有化はそのとき判断 |
| DD-6 | validator は v2 専用。`schema` 値が `domain-contract/v2` 以外は名指しの明示エラー | OQ-004 提案。v1 検証は既存系（LLM 手続き + contract-schema.Tests.ps1）が既に担っており、二重化しない |
| DD-7 | 違反出力は「1 行 1 件、機械可読な `RULE-ID: message` 形式」で標準エラーへ。exit 0/1 のみ | Phase 1 のゲートが件数・種別を機械消費できる形にしておく。fail-closed（パース不能・引数不正も非 0） |

## v2 Schema Shape

```json
{
  "schema": "domain-contract/v2",
  "meta": { "version": "1.0.0", "status": "Pending", "generated_from": ["..."] },
  "concepts": [
    {
      "id": "CONCEPT-FULFILLMENT",
      "name": "Fulfillment",
      "context": "shipping",
      "definition": "注文という約束のうち「何を、いくつ届けるか」を表す履行の単位",
      "essence": "what and how much is delivered",
      "responsibilities": ["delivery quantity", "delivery state", "delivery attempt"],
      "must_not_own": ["purchase price", "customer purchase intent", "sales amount"],
      "stakeholder_perspectives": [
        { "actor": "warehouse", "concern": "what remains to be delivered" },
        { "actor": "customer-support", "concern": "whether another delivery is required" }
      ],
      "distinguished_from": [
        { "concept_id": "CONCEPT-ORDER",
          "reasons": ["different reason for change", "different lifecycle",
                       "different stakeholder perspective"] }
      ],
      "evidence": ["domain-story:activity-4", "event:FulfillmentFailed"]
    }
  ],
  "contexts": [
    {
      "name": "shipping",
      "description": "...",
      "terms": [
        { "canonical": "Fulfillment", "ja": "履行", "definition": "...",
          "forbidden_synonyms": ["Shipment", "DeliveryOrder"],
          "concept_id": "CONCEPT-FULFILLMENT" }
      ],
      "aggregates": []
    }
  ],
  "relations": []
}
```

スキーマ宣言（draft-07・全階層 `additionalProperties: false`・required と
pattern は requirements.md Field Definitions のとおり）。concepts は
`minItems: 1` — concept を持たないプロジェクトは v1 に留まる（v2 採用が
Concept Governance へのオプトイン）。

## Architecture

```
契約 JSON (手書き / 将来は interviewer 生成)
        │
        ▼
validate-domain-contract.sh / .ps1     ← Phase 0 で新設（決定論）
  1. JSON parse (fail-closed)
  2. schema 値 dispatch (v2 以外は明示エラー)
  3. 構造検査 (型適合 → required / pattern / minLength / minItems。
     REQ-004(c) の先行規定どおり、型不一致の値には後続検査を適用しない)
  4. 相互参照検査 (d)〜(i)
        │ exit 0
        ▼
後続 Phase の消費者（Phase 1: concept-test ゲート /
Phase 3: reviewer 記録照合）— 本 feature ではまだ接続しない
```

## Error Handling

- 引数なし / ファイル不存在 / JSON パース不能 / 想定外の巨大入力:
  非 0 + 1 行の原因表示（fail-closed、best-effort 解釈をしない）。
- 検査違反: 検出した**全件**を `RULE-ID: message` 形式で列挙してから
  非 0 終了（最初の 1 件で打ち切らない — 手書き作成者の修正ループを
  1 回で済ませるため）。RULE-ID:
  - 相互参照系: `V2-DUP-CONCEPT-ID` / `V2-DANGLING-CONTEXT` /
    `V2-DANGLING-DISTINCTION` / `V2-DANGLING-TERM` /
    `V2-SELF-CONTRADICTION` / `V2-DUP-NAME-IN-CONTEXT`
  - 構造系（検査経路ごとに別 ID — AC-014/016/018/019/021/023/024 が
    エラー文言での経路判別を要求するため）: `V2-TYPE-MISMATCH`（型不一致。
    フィールド名と期待型を message に含め、型検査は他の構造検査に先行）/
    `V2-MISSING-KEY`（required キー欠落）/ `V2-PATTERN`（pattern 不適合）/
    `V2-EMPTY-ARRAY`（minItems 違反）/ `V2-EMPTY-STRING`（minLength 違反）
  - バージョン: `V2-WRONG-SCHEMA`（v1 等の明示拒否 — DD-6）

## Test Strategy

acceptance-tests.md の TEST-001..026。設計上の要点:

- **drift lock 2 種**: TEST-002（v1 ファイルの SHA-256）と TEST-001 の
  構造 assertion（v2 スキーマ宣言と validator 挙動の突き合わせ）。
  WFI-028（template と validator の乖離）と同型の事故を負例 fixture で
  先回りして拘束する。
- **非空虚性**: 負例は 1 検査 1 fixture で計 73 件
  （TEST-006..012/014/016..024。キー欠落・空配列・空文字列・pattern・
  型不一致・参照整合の各経路を個別に踏む）。どの検査が効いたかを RULE-ID
  で判別する。網羅性の判定基準は acceptance-tests.md の 2 枚のマトリクス
  （Positive-capability / Negative-path）の空白セル不在。
- **正例 5 系統**: TEST-003（全 optional populate + pattern 境界値
  `APIOrder` / `order-taking-2`）/ TEST-004（REQ-005(b) 指定内容）/
  TEST-005（同名別概念）/ TEST-025（term→concept 連結）/ TEST-026
  （optional 全欠落）。正例の「値が保持されている」確認は suite 側の
  構造 assertion が担う（validator は exit code と stderr のみを出力し、
  パース結果を出力しない — DD-7）。
- **twin parity**: TEST-013 が全 fixture で sh/ps1 の verdict 一致を検査。
  bash 不在ホストは named SKIP（既存規約）。
- 新スイートの CI/run-all 登録は行わない（INV-007 の現状規約。OQ-002）。

## Constraint Compliance

| 制約 | 遵守 |
|---|---|
| v1 無変更（REQ-007） | 成果物 3 点はすべて新規ファイル。TEST-002/TEST-015 が拘束 |
| hook-guard 保護 | 対象パスはすべて保護外（INV-008）。human-copy フロー不要 |
| content-as-data | validator は契約内容を命令として解釈しない。文字列比較・構造走査のみ |
| 外部依存禁止（house pattern） | DD-4。jq / ajv / Test-Json / 新規 pip 依存なし |
| ASCII/改行規約 | 新規 .ps1 は既存 hygiene スイートの対象規約（ASCII / no-BOM / LF）に従う |

## Open Items

- OQ-001（v1 ファイルの最終処遇）は Phase 3 で判断 — 本設計は削除にも
  恒久共存にも耐える（DD-3 の非結合）。
- OQ-003（essence required）は提案どおり required で**確定**
  （spec-review attempt 4 で PASS。REQ-002 / Field Definitions / AC-014 に
  反映済み）。
