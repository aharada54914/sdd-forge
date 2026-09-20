# Investigation: sdd-domain-concept-contract (issue #290 Phase 0 — domain-contract/v2 と Concept 一級要素化の契約基盤)

Source: issue #290 (epic tracking), reports/notes/concept-design-layer-plan-adversarial-review.md §3 Phase 0.
Investigated: 2026-08-16, branch claude/adversarial-review-plan-dhzsr1 (main = d9d254f).
Method: read-only survey with file:line evidence (adversarial-review session の照合結果を再利用).

## Findings

- INV-001: `contracts/domain-contract.v1.schema.json:7-8` は root に
  `additionalProperties: false` を宣言し、`:47-49` (boundedContext),
  `:68-70` (term), `:89-91` (aggregate) の各 definition も同様。v1 スキーマ
  ファイルへの in-place の加算拡張は既存 validator を壊すため不可能であり、
  v2 は別ファイルとして追加するしかない。
- INV-002: v1 の term 定義 (`contracts/domain-contract.v1.schema.json:68-88`)
  は canonical / ja / definition / forbidden_synonyms のみで、term が
  どの概念の名前なのかを表現するフィールドが存在しない（Term ≠ Concept
  の分離が構造上不可能）。
- INV-003: v1 の aggregate は context 配下にネストされ (`:62-65`)、単一
  コンテキスト所属が構造で強制されている。concept の所属表現の先例となる
  が、concept は `distinguished_from` でコンテキスト横断参照を持つため、
  ネストではなくトップレベル配列 + 所属フィールドが必要（design.md DD-1）。
- INV-004: v1 契約の consumer は次の 4 系統。いずれも Phase 0 では無変更:
  - `plugins/sdd-domain/skills/domain-sync/SKILL.md:60-71` — v1 スキーマ
    に対する検証と injection
  - `plugins/sdd-domain/agents/domain-reviewer-a.md:74-80` — relation
    pattern enum の参照
  - `plugins/sdd-domain/skills/domain-interviewer/SKILL.md:3` — 各 stage
    後の contract 再生成
  - `plugins/sdd-quality-loop/scripts/check-domain-conformance.sh:37` —
    contract 読取（grep-only の決定論チェック）
- INV-005: 既存の契約テスト `tests/sdd-domain/contract-schema.Tests.ps1:4-11`
  は「汎用 JSON Schema エンジンや外部依存を導入せず、hand-rolled の構造
  assertion で検証する」方式を明記（`tests/design-system-contract.tests.ps1`
  と同型、PS5.1-safe / Test-Json 不使用）。v2 の検証もこの house pattern に
  従う。
- INV-006: `tests/sdd-domain/` は 11 の Pester スイートのみで fixtures
  ディレクトリを持たない。fixture は suite 内のインライン定義
  （ConvertTo-Json/ConvertFrom-Json ラウンドトリップ、`Get-PropSafe`
  アクセサ `contract-schema.Tests.ps1:33-40`）または mktemp スコープで
  生成される。
- INV-007: `tests/sdd-domain/*.Tests.ps1` は `tests/run-all.ps1` /
  `tests/run-all.sh` / `.github/workflows/test.yml` のいずれからも参照され
  ていない（grep で不在確認、2026-08-16）。実行は Pester 直接実行および
  `specs/sdd-domain/verification/` の記録による。Phase 0 の新スイートも
  同じ規約に従い、CI 登録の変更はスコープ外（OQ-002）。
- INV-008: hook-guard の保護対象（`plugins/sdd-quality-loop/scripts/
  generated/guard_invariants.py` の保護パス一覧）に `contracts/
  domain-contract.*` および `plugins/sdd-domain/` 配下は含まれない
  （contracts 配下の保護は capability-registry 系のみ）。Phase 0 の全
  成果物は agent 編集可能で、human-copy フロー（ADR 0011）は不要。
- INV-009: sdd-forge 自身に `domain/` ディレクトリは存在せず（ルート
  直下確認）、owner 決定（2026-08-16、issue #290）により v1 契約
  インスタンスは外部にも存在しないものとして扱う。v1 → v2 の
  アーティファクト移行設計はスコープ外。
- INV-010: 本セッションの hook-activation handshake は
  `CAPABILITY_RUNTIME_UNAVAILABLE`（reason: WRITE_EXECUTED — canary 書込が
  実行された）。`sdd/project-context.yaml` は物理不在のため track 解決は
  C1 `COMPATIBILITY_FALLBACK`（full profile）。逸脱は owner の明示指示に
  基づき記録の上続行（requirements.md Assumptions 参照）。
- INV-011: `plugins/sdd-domain/scripts/` には `domain-review-precheck.{sh,ps1}`
  のみが存在する。契約の決定論 validator スクリプトは存在せず、Phase 1
  の決定論ゲート（concept-test 記録の存在検査）は Phase 0 で新設する
  validator を前提にできる。
- INV-012: 記事レビュー C-2 の裁定（概念分離には不変条件の明示が随伴する）
  および plan レビュー P-7（同名別概念のコンテキスト横断表現）は fixture
  要件として反映する必要がある — 受注 Order / 出荷側概念の同名ケースを
  正例、同一コンテキスト内の概念名重複を負例とする。

## Open Questions

- OQ-001: v1 スキーマファイル (`contracts/domain-contract.v1.schema.json`)
  の最終処遇（削除 or 恒久共存）。提案: 最後の consumer が v2 へ切り替わる
  Phase（3 想定）で削除を判断。Phase 0 では共存・無変更。Status: Open
  （owner 判断、Phase 3 で解決）。
- OQ-002: 新テストスイートの CI/run-all 登録。提案: 既存 11 スイートと
  同じく未登録のまま（規約踏襲、INV-007）。登録方針の変更は別 WFI で
  全 11+1 スイート一括で扱う。Status: Open（提案どおりなら追加作業なし）。
- OQ-003: concept の `essence` フィールドを required にするか。提案:
  required（原案 §4 テンプレートに含まれ、1 行の記述コストで概念の
  本質を強制言語化できる）。Status: Open（spec-review で確定）。
- OQ-004: validator が v1 契約も検証すべきか。提案: v2 専用とし、
  `schema` 値が `domain-contract/v2` 以外なら明示エラー（v1 の検証は
  既存の LLM 手続き + contract-schema.Tests.ps1 のまま）。Status: Open
  （提案どおりなら REQ-004 の記載で確定）。
