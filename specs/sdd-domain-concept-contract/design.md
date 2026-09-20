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
- **fixture 衛生**: 全 fixture は Purchase/Fulfillment・Book/Bookshelf 等の
  合成ドメイン語彙のみで構成し、資格情報・トークン・実在の個人情報・実顧客
  データを含めない（requirements.md Security Boundaries 第 3 項）。負例も
  構造違反・参照整合違反のみで検査経路を踏み、秘密情報を模した文字列を
  用いない。契約 JSON は untrusted data であり（security-spec.md の
  Threat Considerations）、interview / seed 由来の外部テキストを fixture に
  そのまま持ち込まない。
- 新スイートの CI/run-all 登録は行わない（INV-007 の現状規約。OQ-002）。

## Deployment / CI Plan

- **デプロイ対象**: デプロイされるサービス・環境はない。成果物は
  リポジトリ内の 3 ファイル（v2 スキーマ・validator twins・テストスイート）
  であり、配布は既存のプラグインリリース同梱に乗る。実行ホスト要件は
  `bash` + `python3`（`.sh` 側）または Windows PowerShell 5.1+ / pwsh
  （`.ps1` 側）。詳細は
  [Infrastructure specification](infra-spec.md#execution-environments)。
- **Feature-flag 戦略**: 不要。段階的ロールアウトをしない。Phase 0 では
  consumer を 1 つも接続しないため（Technical Summary）、追加した 3 点は
  明示的に呼ばれるまで既存挙動に一切影響しない。オプトインの単位は
  「その契約が v2 を名乗るかどうか」であり、フラグではなく契約の `schema`
  値そのものが担う（DD-6）。
- **CI パイプライン変更**: なし。新規ジョブ・環境変数・シークレットの追加
  はない。新スイートの `run-all` / CI 登録も行わない（INV-007 の現状規約。
  OQ-002）。詳細は
  [Infrastructure specification](infra-spec.md#ci--release-impact)。
- **マイグレーション実行順序**: 該当なし。スキーマ変更を伴うデータストアが
  存在しない（DB・永続ストアなし、既存テーブル/カラムの読み書きなし）ため、
  migrate-before-deploy / deploy-before-migrate の選択自体が発生しない。
- **ロールバック**: 3 ファイルの削除のみ。Phase 0 では consumer が未接続な
  ので、巻き戻すデータ・状態・登録がない。詳細は
  [Infrastructure specification](infra-spec.md#rollback)。

## Constraint Compliance

requirements.md が課す制約を漏れなく列挙する。出典を各行に明記する。

| 制約（requirements.md の出典） | 遵守 |
|---|---|
| v1 無変更（REQ-007） | 成果物 3 点はすべて新規ファイル。TEST-002/TEST-015 が拘束 |
| content-as-data（Security Boundaries 第 1 項） | validator は契約内容を命令として解釈しない。文字列比較・構造走査のみで、`eval` / `Invoke-Expression` を使わず、契約値からコマンド組み立て・パス解決もしない |
| 読み取り専用・ネットワークなし・外部依存なし（Security Boundaries 第 2 項） | DD-4。validator は引数のパスを読むだけで一切書き込まず、ネットワーク I/O を持たない。jq / ajv / Test-Json / 新規 pip 依存なし（bash 側は python3 stdlib の json、ps1 側は `ConvertFrom-Json` のみ） |
| fixture に秘密情報・実在の個人情報を含めない（Security Boundaries 第 3 項） | Test Strategy の fixture corpus は Purchase/Fulfillment・Book/Bookshelf 等の合成ドメイン語彙のみで構成し、資格情報・トークン・実在の個人情報・実顧客データを一切含めない。負例も構造違反・参照整合違反のみで検査経路を踏み、秘密情報を模した文字列を用いない。REQ-005 が corpus を所有し、TEST-003..TEST-026 が内容を固定する |
| fail-closed（Edge Cases: best-effort パースをしない） | Error Handling。引数なし・ファイル不存在・JSON パース不能・巨大入力はいずれも非 0 + 1 行の原因表示。部分判定・推測解釈を返さない |
| 承認強制機構を新設しない（Non-goals / Roles and Permissions） | v2 スキーマは `meta.status` を単なる列挙値フィールドとして定義するに留め、hook-guard 保護パスへの登録・承認 sidecar・書込検査のいずれも追加しない。INV-008 の非保護状態を変更しない |
| 二重バージョンローダーを作らない（Non-goals、owner 決定 INV-009） | DD-2。validator は v2 専用（DD-6）で、v1 との共存はファイル分離のみ。v1 を渡されたら `V2-WRONG-SCHEMA` で明示拒否する |
| `domain/` アーティファクトを生成・変更しない（Non-goals） | 成果物は契約スキーマ・validator・テストの 3 点のみで、`domain/` 配下への書き込み経路を持たない |
| hook-guard 保護 | 対象パスはすべて保護外（INV-008）。human-copy フロー不要 |
| ASCII/改行規約 | 新規 .ps1 は既存 hygiene スイートの対象規約（ASCII / no-BOM / LF）に従う |

## Open Questions

### OQ-001: v1 スキーマファイルの最終処遇

`contracts/domain-contract.v1.schema.json` を最終的に削除するか恒久共存
させるかは未確定。本設計はどちらにも耐える — DD-3 により v2 は v1 の定義
（boundedContext / term / aggregate / contextRelation）を複製して内包し、
v1 ファイルへの `$ref` を持たないため、v1 削除で v2 が壊れる結合はない。

Owner: repository owner (human)
Blocks Implementation: no
Resolution Path: Phase 3（reviewer 記録照合）で INV-004 の consumer 4 系統
の v2 切替が完了した時点で、owner が削除か恒久共存かを決定する。Phase 0 の
成果物はどちらの決定でも変更を要さない。

### OQ-002: 新スイートの run-all / CI 登録

`tests/sdd-domain/contract-v2-schema.Tests.ps1` を `run-all` および CI に
登録するかは未確定。本 feature では既存 `tests/sdd-domain/` の現状規約
（run-all 外で実行）に従い、登録しない（INV-007）。

Owner: repository owner (human)
Blocks Implementation: no
Resolution Path: `tests/sdd-domain/` 全体の登録方針として別 WFI を起票し、
承認後に既存 11 スイートと本スイートをまとめて登録する。本 feature 単独で
方針を変更しない。

### OQ-003: `essence` を required にするか（解決済み）

提案どおり required で**確定**。spec-review attempt 4 で PASS し、
REQ-002 / Field Definitions / AC-014 に反映済み。

Owner: repository owner (human)
Blocks Implementation: no
Resolution Path: 解決済み — 未着手の作業はない。

### OQ-004: v1 契約を渡されたときの挙動（解決済み）

提案どおり「明示エラーで拒否」で**確定**。DD-6 に反映し、RULE-ID
`V2-WRONG-SCHEMA` として Error Handling に定義済み。REQ-004(b) が
requirements.md 側の根拠。

Owner: repository owner (human)
Blocks Implementation: no
Resolution Path: 解決済み — 未着手の作業はない。
