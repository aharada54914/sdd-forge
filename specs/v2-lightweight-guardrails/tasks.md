# タスク（SDD Core）: v2-lightweight-guardrails

## T-001 設計・ADR-0051・設定スキーマの整備
Approval: Draft
Status: Implementation Complete
Risk: standard

### Scope
- `docs/adr/0051-lightweight-guardrails-and-sdd-core.md` の作成と `docs/adr/README.md` 索引更新
- `specs/v2-lightweight-guardrails/{requirements,design,tasks}.md` の作成
- `contracts/guardrails.schema.json` と `sdd/guardrails.example.yaml` の作成

### Done When
- ADR-0051 が既存 ADR 番号規則（0050 の次）と矛盾せず、v1.26.0 準拠の 4 環境対応と置換対象 ADR を明記している
- `contracts/guardrails.schema.json` が妥当な JSON Schema として検証できる

### Blockers
- None

---

## T-002 ソフトガード & Spec Drift プロトタイプ実装（Node.js ESM）
Approval: Draft
Status: Implementation Complete
Risk: standard

### Scope
- `plugins/sdd-quality-loop/scripts/v2/guardrails-lib.mjs`
- `plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs`
- `plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs`
- `plugins/sdd-quality-loop/scripts/v2/check-spec-drift.mjs`

### Done When
- AC-001〜AC-010 をすべて満たし、外部 npm 依存ゼロの Node.js ESM で動作する
- `node --test tests/v2-soft-guard.test.mjs tests/v2-spec-drift.test.mjs` が全件 PASS する

### Blockers
- T-001

---

## T-003 Phase 2: SDD Core スキル統合
Approval: Draft
Status: Implementation Complete
Risk: standard

### Scope
- `plugins/sdd-bootstrap/skills/sdd-core-spec/`（新テンプレート 3 種 + スキル）
- `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md`（SDD Core 単一トラック化）
- `plugins/sdd-review-loop/skills/spec-check/SKILL.md`（1 体 1 パス統合レビュー新設）
- `plugins/sdd-quality-loop/skills/sdd-gate/SKILL.md`, `templates/sdd-gate-report.md`, `scripts/v2/run-sdd-gate.mjs`
- `plugins/sdd-ship/skills/ship/SKILL.md`（SDD Core 単一トラック化）
- `plugins/sdd-lite/references/lite-flow-policy.md`（SDD Core 統合案内）

### Done When
- 単一トラック `SDD Core` で仕様作成→1パス統合レビュー→承認＆ベースライン記録→実装→`sdd-gate` が完走できる
- `node --test tests/v2-sdd-core-flow.test.mjs` が全件 PASS する

### Blockers
- T-002

---

## T-004 Phase 3–4: SDD Full 廃止・フック切替・CI ガバナンス刷新（次フェーズ）
Approval: Draft
Status: Planned
Risk: high

### Scope
- 4 言語 `sdd-hook-guard.*` / `guard-invariants.json` / canary handshake / `SDD_SUDO` / 3 連レビューループの廃止
- `.github/workflows/sdd-guardrails.yml`・`CODEOWNERS`・インストーラ・ドキュメントの v2.0.0 刷新

### Done When
- 全 4 ホスト（Claude / Codex / Copilot / Gemini）のフックが `sdd-soft-guard.mjs` へ切り替わり、CI で Spec Drift 検知が稼働する

### Blockers
- T-003

## Spec Amendments
- （初期版のため変更なし）
