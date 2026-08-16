# Acceptance Tests: sdd-domain-concept-contract

TEST IDs (TEST-001..TEST-015) are namespaced to this feature
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
| AC-014 | REQ-002 | TEST-014 | negative fixture (required 欠落) | 同 suite: `essence` 欠落・`evidence` 空配列・`responsibilities` 空配列の各 fixture をそれぞれ拒否（1 fixture 1 欠落で、どの required 検査が効いたか判別可能にする） | Planned |
| AC-015 | REQ-007 | TEST-015 | non-regression (既存スイート) | 既存 `tests/sdd-domain/contract-schema.Tests.ps1`（v1）を無変更のまま実行して green。加えて review 時チェックとして、本 feature の diff が INV-004 の consumer 4 系統・既存 11 スイートに触れていないことを確認 | Planned |

Notes:

- 正例（TEST-003/004/005）と負例（TEST-006..012/014）は 1 検査 1 fixture
  で対をなし、validator の各検査項目が空虚に真でないことを個別に証明する
  （house convention: 負例 canary による非空虚性証明）。
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
