# Acceptance Tests: sdd-domain-concept-contract

TEST IDs (TEST-001..TEST-024) are namespaced to this feature
(`specs/sdd-domain-concept-contract/`) and do not collide with any other
spec folder's own TEST numbering (different suite file, different fixture
namespace).

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | structural (schema file) | `tests/sdd-domain/contract-v2-schema.Tests.ps1`: `contracts/domain-contract.v2.schema.json` が存在し、draft-07・`schema` const `domain-contract/v2`・root required `schema`/`meta`/`contexts`/`concepts` を宣言し、meta 定義が v1 と同形（version/status/generated_from）である | Planned |
| AC-002 | REQ-001, REQ-007 | TEST-002 | non-regression (byte 比較) | 同 suite: `contracts/domain-contract.v1.schema.json` の SHA-256 が本 feature 開始時点の値と一致（v1 無変更の drift lock） | Planned |
| AC-003 | REQ-002, REQ-005(a) | TEST-003 | positive fixture | 同 suite: Purchase/Fulfillment 正例 fixture（Order=purchase 責務のみ / Fulfillment=delivery 責務のみ / 相互 distinguished_from / Fulfillment.must_not_own に purchase price）が構造 assertion と validator (.ps1) の両方を exit 0 で通過 | Planned |
| AC-004 | REQ-005(b) | TEST-004 | positive fixture | 同 suite: Book/Bookshelf 正例 fixture（Book.must_not_own に display position / Placement concept が並び責務）が通過 | Planned |
| AC-005 | REQ-002, REQ-005(c) | TEST-005 | positive fixture (P-7 representability) | 同 suite: 2 つの context に同名 concept（例: order-taking の Order と shipping の Order）を持つ fixture が通過し、両 concept の id は異なる | Planned |
| AC-006 | REQ-004(d) | TEST-006 | negative fixture | 同 suite: concept id 重複 fixture を validator が非 0 で拒否し、標準エラーに重複 id を名指しする | Planned |
| AC-007 | REQ-004(e) | TEST-007 | negative fixture | 同 suite: `concept.context` が宣言されていない context を指す fixture を拒否 | Planned |
| AC-008 | REQ-004(f) | TEST-008 | negative fixture | 同 suite: `distinguished_from.concept_id` の宙吊り参照 fixture（自分自身への参照ケースを含む）を拒否 | Planned |
| AC-009 | REQ-003, REQ-004(g) | TEST-009 | negative fixture | 同 suite: `term.concept_id` の宙吊り参照 fixture を拒否 | Planned |
| AC-010 | REQ-004(h) | TEST-010 | negative fixture (自己矛盾) | 同 suite: 同一 concept の responsibilities と must_not_own の両方に同一文字列が出現する fixture を拒否 | Planned |
| AC-011 | REQ-004(i) | TEST-011 | negative fixture | 同 suite: 同一 context 内の concept name 重複 fixture を拒否（TEST-005 の正例と対をなし、単一 context 内でのみ重複が違反であることを証明） | Planned |
| AC-012 | REQ-004(b) | TEST-012 | negative fixture (version 誤り) | 同 suite: `schema: domain-contract/v1` の契約を v2 validator に渡すと、v2 専用である旨の明示エラーで非 0 終了（OQ-004 提案の確定形） | Planned |
| AC-013 | REQ-004, REQ-006 | TEST-013 | twin parity | 同 suite: 全 fixture（正例・負例）に対し `validate-domain-contract.sh` と `.ps1` の exit code と違反件数が一致（bash が PATH に無い環境では named SKIP — 既存 twin 検査の縮退規約に従う） | Planned |
| AC-014 | REQ-002, REQ-004(c) | TEST-014 | negative fixture (concept required キー欠落) | 同 suite: concept の required 7 フィールド（`id` / `name` / `context` / `definition` / `essence` / `responsibilities` / `evidence`）それぞれについて、当該キーを丸ごと欠いた fixture を validator が非 0 で拒否し、標準エラーに欠落フィールド名を名指しする。7 fixture、1 fixture 1 欠落とし、どの required 検査が効いたか判別可能にする。値が不正な場合（AC-018 の pattern 違反・AC-023 の空文字列）とは検査経路が異なることを、キー欠落側のエラー文言で区別する | Planned |
| AC-015 | REQ-007 | TEST-015 | non-regression (既存スイート) | 既存 `tests/sdd-domain/contract-schema.Tests.ps1`（v1）を無変更のまま実行して green。加えて review 時チェックとして、本 feature の diff が INV-004 の consumer 4 系統・既存 11 スイートに触れていないことを確認 | Planned |
| AC-016 | REQ-001, REQ-004(c) | TEST-016 | negative fixture (空配列) | 同 suite: `concepts` が空配列（`[]`）の fixture を validator が非 0 で拒否し、標準エラーに `concepts` が最低 1 件必要である旨を名指しする。root required を満たす（`concepts` キー自体は存在する）状態で minItems 1 が効くことを示し、キー欠落の検査と区別する | Planned |
| AC-017 | REQ-004(a) | TEST-017 | negative fixture (fail-closed) | 同 suite: 異常入力に対し validator が fail-closed で非 0 終了し、部分的な検査結果を標準出力に出さない（best-effort パースをしない）。2 fixture で個別に証明する — (1) 構文的に壊れた JSON（途中で切れた本文）、(2) 10MB を超えるファイル。いずれも標準エラーは 1 行 1 件の違反列挙形式を保ち、スタックトレースや処理系の生例外を出さない | Planned |
| AC-018 | REQ-002, REQ-004(c) | TEST-018 | negative fixture (pattern 違反) | 同 suite: REQ-002 の 3 パターンそれぞれに違反する fixture を validator が非 0 で拒否し、標準エラーに違反フィールド名を名指しする。3 fixture で個別に証明する — (1) `id` が `^CONCEPT-[A-Z][A-Z0-9-]*$` に不適合（例 `concept-order`）、(2) `name` が `^[A-Z][A-Za-z0-9]*$` に不適合（例 `order_item`）、(3) `context` が `^[a-z][a-z0-9]*(-[a-z0-9]+)*$` に不適合（例 `Order-Taking`）。あわせて境界の正例として `APIOrder`（連続大文字）と `order-taking-2`（数字セグメント）が AC-003 の正例 fixture 系で受理されることを示し、パターンが過剰に厳しくないことを証明する | Planned |
| AC-019 | REQ-002, REQ-004(c) | TEST-019 | negative fixture (minItems 違反) | 同 suite: minItems 1 を宣言する 3 配列について空配列 fixture を拒否し、標準エラーに当該配列名を名指しする。3 fixture — (1) `responsibilities` 空配列、(2) `evidence` 空配列、(3) `distinguished_from[].reasons` 空配列。キー欠落（AC-014）と空配列が別経路であることを、エラー文言で区別する | Planned |
| AC-020 | REQ-002, REQ-004(c) | TEST-020 | negative fixture (optional 内 nested required 欠落) | 同 suite: optional なオブジェクト配列を**持つ場合に**その内側で required となるフィールドの欠落を拒否する。4 fixture — (1) `stakeholder_perspectives[].actor` 欠落、(2) `stakeholder_perspectives[].concern` 欠落、(3) `distinguished_from[].concept_id` 欠落、(4) `distinguished_from[].reasons` 欠落。あわせて、当該 optional 配列自体を持たない fixture（AC-004 の正例系）が exit 0 で通過することを示し、optional が誤って required 化されていないことを証明する | Planned |
| AC-021 | REQ-001, REQ-004(c) | TEST-021 | negative fixture (root/meta required キー欠落) | 同 suite: root の required 4 キーと meta の required 3 キーそれぞれの欠落を拒否し、標準エラーに欠落キー名を名指しする。7 fixture — (1) `schema` 欠落、(2) `meta` 欠落、(3) `contexts` 欠落、(4) `concepts` 欠落、(5) `meta.version` 欠落、(6) `meta.status` 欠落、(7) `meta.generated_from` 欠落。`concepts` キー欠落（本 AC (4)）と `concepts` 空配列（AC-016）が別経路であることを、エラー文言で区別する | Planned |
| AC-022 | REQ-002, REQ-003, REQ-004(c) | TEST-022 | negative fixture (参照フィールドの pattern 違反) | 同 suite: concept id と同一 pattern を共有する 2 つの参照フィールドについて、pattern 不適合値（例 `concept-order`）を持つ fixture を拒否する。2 fixture — (1) `distinguished_from[].concept_id`、(2) `contexts[].terms[].concept_id`。宙吊り参照（AC-008 / AC-009）は参照先が存在しないケースであり、本 AC は値の形式自体が不正なケースであることを、エラー文言で区別する | Planned |
| AC-023 | REQ-002, REQ-004(c) | TEST-023 | negative fixture (minLength 違反) | 同 suite: REQ-002 が minLength 1 を宣言する string 対象**すべて**について、それぞれ独立した空文字列 fixture を拒否し、標準エラーに当該フィールド名を名指しする。8 fixture — (1) `definition`、(2) `essence`、(3) `responsibilities[]` の要素、(4) `evidence[]` の要素、(5) `must_not_own[]` の要素、(6) `stakeholder_perspectives[].actor`、(7) `stakeholder_perspectives[].concern`、(8) `distinguished_from[].reasons[]` の要素。(1)(2) はスカラ、(3)(4)(5)(8) は配列要素、(6)(7) はネストしたオブジェクトのフィールドであり、required 側（(1)〜(4)）と optional 配列の内側（(5)〜(8)）を個別に踏むことで、validator が両者を別ブランチで実装した場合の片側漏れを検出する。配列自体は非空のまま要素だけが空文字列であるケースを (3)(4)(5)(8) で扱い、minItems 検査（AC-019）と別経路であることを証明する | Planned |
| AC-024 | REQ-001, REQ-002, REQ-003, REQ-004(c) | TEST-024 | negative fixture (型不一致) | 同 suite: 構文的には妥当な JSON でありながら、Field Definitions が宣言する型と実際の JSON 型が一致しない fixture を validator が非 0 で拒否し、標準エラーに当該フィールド名と期待型を 1 行で名指しする。**生例外・スタックトレースを出力しないこと**を各 fixture で assert する（AC-017 の fail-closed 規定を、構文エラーではなく型エラーの経路について証明する）。型を宣言するフィールドそれぞれに 1 fixture を割り当て、29 fixture とする — root: (1) `schema` が非 string、(2) `meta` が非 object、(3) `contexts` が非 array、(4) `concepts` が非 array / meta: (5) `version`、(6) `status`、(7) `generated_from` が非 string / concept 構造: (8) `concepts[]` の要素が非 object / concept スカラ: (9) `id`、(10) `name`、(11) `context`、(12) `definition`、(13) `essence` が非 string / concept 配列: (14) `responsibilities`、(15) `evidence`、(16) `must_not_own` が非 array、(17)(18)(19) 同 3 配列の要素が非 string / stakeholder_perspectives: (20) 非 array、(21) 要素が非 object、(22) `actor`、(23) `concern` が非 string / distinguished_from: (24) 非 array、(25) 要素が非 object、(26) `concept_id` が非 string、(27) `reasons` が非 array、(28) `reasons` の要素が非 string / term: (29) `contexts[].terms[].concept_id` が非 string。**型検査が pattern / minLength / minItems に先行すること**を、(9)(10)(11) が pattern 違反ではなく型違反として報告されること、および (17)(18)(19) が minLength 違反ではなく型違反として報告されることで証明する | Planned |

## Negative-path coverage matrix

この表は「requirements.md が宣言するすべての制約」×「その制約を破る様態」の
直積であり、AC 表の網羅性はこの表の空白セルが無いことで判定する。新しい制約
を requirements.md に加えたときは、まずこの表に行を足し、埋まらないセルを AC
にしてから AC 表を更新する。

| 宣言された制約 | キー欠落 | 型不一致 | 空配列 (minItems) | 空文字列 (minLength) | pattern 違反 | 参照整合 |
|---|---|---|---|---|---|---|
| root `schema` / `meta` / `contexts` / `concepts` | AC-021 | AC-024 | — | — | — | — |
| `meta.version` / `.status` / `.generated_from` | AC-021 | AC-024 | — | — | — | — |
| `concepts[]` の要素 (object) | AC-021 | AC-024 | AC-016 | — | — | — |
| `concepts[].id` | AC-014 | AC-024 | — | pattern が排除 | AC-018 | 重複=AC-006 |
| `concepts[].name` | AC-014 | AC-024 | — | pattern が排除 | AC-018 | context 内重複=AC-011 |
| `concepts[].context` | AC-014 | AC-024 | — | pattern が排除 | AC-018 | 宙吊り=AC-007 |
| `concepts[].definition` | AC-014 | AC-024 | — | AC-023 | 制約なし | — |
| `concepts[].essence` | AC-014 | AC-024 | — | AC-023 | 制約なし | — |
| `concepts[].responsibilities[]` (配列と要素) | AC-014 | AC-024 | AC-019 | AC-023 | 制約なし | 自己矛盾=AC-010 |
| `concepts[].evidence[]` (配列と要素) | AC-014 | AC-024 | AC-019 | AC-023 | 制約なし | — |
| `concepts[].must_not_own[]` (optional、配列と要素) | optional | AC-024 | — | AC-023 | 制約なし | 自己矛盾=AC-010 |
| `stakeholder_perspectives[]` (配列と要素) | optional | AC-024 | — | — | — | — |
| `stakeholder_perspectives[].actor` / `.concern` | AC-020 | AC-024 | — | AC-023 | 制約なし | — |
| `distinguished_from[]` (配列と要素) | optional | AC-024 | — | — | — | — |
| `distinguished_from[].concept_id` | AC-020 | AC-024 | — | pattern が排除 | AC-022 | 宙吊り=AC-008 |
| `distinguished_from[].reasons[]` (配列と要素) | AC-020 | AC-024 | AC-019 | AC-023 | 制約なし | — |
| `contexts[].terms[].concept_id` (optional) | optional | AC-024 | — | pattern が排除 | AC-022 | 宙吊り=AC-009 |
| `schema` の値が v2 であること | — | 型は上段 root 行 | — | — | — | v1 拒否=AC-012 |
| 入力が JSON として可読であること | — | — | — | — | — | fail-closed=AC-017 |

凡例と充足規則:

- **AC 番号**: 当該 AC が、このセルの対象フィールドを名指しした fixture を
  持つ。AC の本文にフィールド名が現れないセルにこの記法を使ってはならない。
- **「pattern が排除」**: 当該フィールドが pattern を持ち、その pattern が
  空文字列に一致しないため、空文字列は pattern 検査（AC-018 / AC-022）で
  弾かれる。requirements.md 側の宣言による排除であり、実装の構造に依存しない。
- **「制約なし」**: requirements.md が当該様態の制約を宣言していない。
  AC は不要である。
- **「optional」**: 当該フィールドが optional であり、キー欠落は違反でない。
  ただし**キーが存在する場合の型不一致は違反**であり、型不一致列は
  AC-024 で個別に充足する。
- **「型は上段 root 行」**: `schema` フィールドの型（string）は root 行の
  AC-024(1) が扱い、当該行は値が `domain-contract/v2` であるかという別の
  制約を表すため型列を重複させない。

型不一致列は、REQ-004(c) が宣言する JSON 型適合検査に対応する。AC-024 は
型を宣言する全フィールドに 1 fixture ずつを割り当てており、型検査が
pattern / minLength / minItems に先行するという REQ-004(c) の順序規定も
同 AC が証明する。

セルを埋める根拠として **validator の内部構造に関する仮定を用いてはならない**。
「別のフィールドと同じ検査ルーチンを通るはず」という理由でセルを充足済みと
する記法は禁止する。REQ-004(c) の validator は hand-rolled（INV-005）であり、
required 側と optional 配列の内側は別ブランチで実装されうるため、共有ルーチン
の仮定は片側漏れを見逃す。各セルは、そのフィールドを名指しした fixture を
持つ AC によってのみ充足される。

Notes:

- 正例（TEST-003/004/005）と負例（TEST-006..012/014/016..024）は
  1 検査 1 fixture で対をなし、validator の各検査項目が空虚に真でないことを
  個別に証明する（house convention: 負例 canary による非空虚性証明）。
  1 つの検査項目に複数 fixture を割り当てる AC（TEST-014 が 7、TEST-017 が
  2、TEST-018 が 3、TEST-019 が 3、TEST-020 が 4、TEST-021 が 7、TEST-022 が
  2、TEST-023 が 8、TEST-024 が 29）では、どれが効いたかを標準エラーの
  違反行で判別可能とする。負例 fixture の総数は 73 件（1 fixture の AC が
  8 件 = AC-006..012 の 7 件 + AC-016、複数 fixture の AC が 65 件 =
  7+2+3+3+4+7+2+8+29。この値は AC 表の宣言から導出したものであり、AC を
  増減したら再計算する）。
- TEST-018 の境界正例（`APIOrder` / `order-taking-2`）は、pattern が
  stuck-shut（正当な名前を誤って拒否する）方向に壊れていないことの証明で
  あり、負例 3 件と対をなす。
- TEST-017(2) の 10MB fixture は mktemp スコープで生成し（リポジトリに
  恒久ファイルを追加しない）、生成コストを抑えるため内容はパディングで
  よい。サイズ閾値そのものを validator に実装するか、単に大きな入力でも
  fail-closed を保つかは design.md の決定事項とする。
- fixture は suite 内で mktemp スコープに生成し、リポジトリに恒久 fixture
  ディレクトリを追加しない（INV-006 の規約踏襲）。fixture の JSON 本体は
  suite 内のヒアストリング定義とし、Phase 3 のレビュアー評価で再利用する
  際は当該 Phase で共有化を判断する。
- TEST-002 の基準 SHA-256 は実装タスクで固定する（tasks.md の Done 条件に
  記録）。

## UI Integration Checklist

N/A — no change: 本 feature はユーザー向けエントリポイント（view /
dialog / menu / context action）を追加しない。成果物はスキーマファイル・
CLI スクリプト・テストのみ。
