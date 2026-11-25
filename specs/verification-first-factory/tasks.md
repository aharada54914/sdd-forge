# Tasks: Verification-First & Self-Verification Factory (`verification-first-factory`)

- **Feature:** `verification-first-factory`
- **Version:** `v2.1`（Dogfooding-First：軸A 本体品質保証＆テスト安全廃止 → 軸B 利用者向け展開）
- **Risk:** `high`
- **Approval:** `Draft`
- **FormalVerification:** `Required`
- **Related Spec:** `specs/verification-first-factory/requirements.md`, `specs/verification-first-factory/design.md`

---

## Wave 1: 基盤・本体 Self-Fitness・v1 死蔵テスト廃止（Phase 1）

### T1: ADR-0053 起票・`guardrails-lib.mjs` 拡張・`git diff` Anti-Tampering・`sdd-doctor.mjs` 診断
- **Status:** `Todo`
- **Approval:** `Draft`
- **Covers:** `REQ-009`（アローリスト検証）, `REQ-010`, `REQ-012`（`sdd-doctor.mjs`）, `NFR-001`, `NFR-003`
- **Scope:** `docs/adr/0053-verification-first-and-agentic-factory.md`, `sdd/guardrails.example.yaml`, `plugins/sdd-quality-loop/scripts/v2/{guardrails-lib,check-spec-drift,sdd-doctor}.mjs`
- **Verification (`AC-008`, `AC-009`, `AC-012`, `AC-013`):** `python3 tests/verification.py --profile local-posix`

### T2（軸A先行）: 本体 Self-Fitness Functions 導入 ＆ カタログ実測に基づくゴースト56件・CI外196件の仕分け・カテゴリ1/4の安全廃止
- **Status:** `Todo`
- **Approval:** `Draft`
- **Covers:** `SELF-REQ-003`, `SELF-REQ-006`（カテゴリ1・4）, `NFR-002`
- **Scope:** `tests/self-fitness.test.mjs`（新規）, `tests/verification-catalog.json`, `tests/verification-timings.json`, `docs/operations/verification-catalog-status.md`, 承認済み廃止対象テスト（`resolve-project-context-*`, `human-copy-*`, `rollback-1.5.0`, `doc-diagrams.*` 等）
- **Measured Baseline (`node tests/verification-catalog-status.mjs`, 2026-11-25):**
  - 登録 262 スイートの内訳：現行 CI 稼働 **10 件**（6ジョブ：`v2-guardrails`, `sdd-forge-mcp-v2`, `mcp-tests`, `cloud-and-ddd`, `installers`, `required-checks`）／ **CI 外（ファイル残存・未実行）196 件**（`posix-regression` 57, `test` 42, `version-gates` 39, `loops-routing` 23, `test-windows-heavy` 17 他）／ **廃止済みゴースト登録 56 件**（`version-gates` 39, `test` 7, `posix-regression` 4, `test-windows-heavy` 3, `cli-hook-enforcement` 2, `windows-powershell` 1）。
- **Implementation Notes:**
  - まずゴースト登録 56 件を `tests/verification-catalog.json` から掃除し、CI 外 196 件を「①即廃止（v1残骸）」「②Self-Fitness / TLA+ 置換対象」「③CI 復帰対象（例：`tests/project-skill-formal.tests.py` → T4 へ引き継ぎ）」の3区分に確定して `## Spec Amendments` へ明記する。
  - `v2-readonly-core.mjs` 純粋性、`sdd-soft-guard.mjs` 300行/200ms ガード、4 CLI パリティ、Doc-Gardening を `tests/self-fitness.test.mjs` に実装し、負例検知パリティ確認後にカテゴリ1・4を廃止する。
- **Verification (`SELF-AC-003`, `SELF-AC-006`):** `node --test tests/self-fitness.test.mjs`, `node tests/verification-catalog-status.mjs --write`（ゴースト 0 件確認）および `verification-timings.json` 削減確認

---

## Wave 2: 決定論的ゲート群 ＆ 本体 TLA+ / 敵対的セキュリティ実装（Phase 2・並列実行可）

### T3: Layer 2/3 専用 AST Agent-Strict Lint ＆ 内蔵 Waiver（Shadow 運用開始）
- **Status:** `Todo`
- **Approval:** `Draft`
- **Covers:** `REQ-007`, `REQ-008`, `NFR-002`, `NFR-004`
- **Scope:** `plugins/sdd-quality-loop/scripts/v2/run-agent-lint.mjs`（新規）, `plugins/sdd-quality-loop/rules/**`, `tests/fixtures/agent-lint/**`
- **Verification (`AC-007`, `SELF-AC-005`):** `node plugins/sdd-quality-loop/scripts/v2/run-agent-lint.mjs --format json`（100件 3秒以内・本体誤検知 < 5% 確認）

### T4: チェッカー非依存 形式検証ゲート ＆ 本体 `TaskLock.tla` / `GateLifecycle.tla` ＋ カテゴリ3テスト圧縮
- **Status:** `Todo`
- **Approval:** `Draft`
- **Covers:** `SELF-REQ-001`, `SELF-REQ-002`, `SELF-REQ-006`（カテゴリ3）, `REQ-003`, `REQ-004`, `REQ-005`, `REQ-006`
- **Scope:** `plugins/sdd-quality-loop/scripts/v2/{discover-state-machines,run-formal-gate,render-decision-view}.mjs`, `specs/self-verification/formal/**`（新規）, `tests/fixtures/project-skills/formal-review-reservation/mapping.json`, 承認済み圧縮対象（`workflow-state*`, `loop-*` 等）
- **Implementation Notes:**
  - `formal_verification.checker.adapter`（`tlc` / `apalache` 実装、`lean4` 予約）、`git diff` 未変更スキップ、有界制御、`expected_violated_invariant` 照合、NDJSON Trace Validation を実装。
  - `TaskLock.tla` / `GateLifecycle.tla` の本体 CI 通過と負例パリティ確認後、重複する手書き状態遷移列挙テストを安全圧縮・廃止。
- **Verification (`SELF-AC-001`, `SELF-AC-002`, `AC-003`〜`AC-006`):** `Reservation.tla` / `TaskLock.tla` / `GateLifecycle.tla` 回帰通過

### T5: 固定アローリスト Security Gate・本体敵対的テスト・Reframing / Meta-Analyze
- **Status:** `Todo`
- **Approval:** `Draft`
- **Covers:** `SELF-REQ-004`, `REQ-001`, `REQ-002`, `REQ-009`
- **Scope:** `plugins/sdd-quality-loop/scripts/v2/{run-security-gate,sync-knowledge}.mjs`, `plugins/sdd-bootstrap/**`, `tests/self-security-adversarial.test.mjs`（新規）
- **Verification (`SELF-AC-004`, `AC-001`, `AC-002`, `AC-008`):** 敵対的フィクスチャ・ダミーシークレット・Slopsquatting 全件通過

---

## Wave 3: 統合ゲート・Differential Rebuild・多言語ペアテスト廃止・MCP v2 / CI 完了（Phase 3）

### T6: Fail-Fast 統合・`--mode rebuild`・Self-Rebuild（カテゴリ2テスト廃止）・OTel / MCP v2・CI 完結
- **Status:** `Todo`
- **Approval:** `Draft`
- **Covers:** `SELF-REQ-005`, `SELF-REQ-006`（カテゴリ2）, `REQ-011`, `REQ-012`, `NFR-003`, `NFR-004`, `NFR-005`
- **Scope:** `plugins/sdd-quality-loop/scripts/v2/{run-sdd-gate,check-traceability,v2-readonly-core,factory-metrics}.mjs`, `plugins/sdd-ship/**`, `mcp/sdd-forge-mcp/src/**`, `tests/verification-catalog.json`, `.github/workflows/sdd-guardrails.yml`, 承認済み廃止対象（`.ps1`/`.sh` 重複ペア・14系統 `parity` テスト）
- **Implementation Notes:**
  - Fail-Fast 7ステージ統合、`--mode rebuild`（Differential + NFR）、`git diff` Write-Scope、OTel GenAI メタデータ、`sdd-forge-mcp`（既定 OFF・4ツール維持）拡張を実装。
  - 残存ヘルパーの Node.js ESM 集約（Differential Testing 通過）に伴い、カテゴリ2の多言語重複テストを単一 `v2-*.test.mjs` へ統合・廃止（E2E・3-AI・`tests/golden/**` は保持）。
  - CI へ `actions/cache`（`hashFiles('specs/**/formal/**')`）を追加し、Shadow→Strict 昇格および単一フラグ・ロールバックを検証。
- **Verification (`SELF-AC-005`, `SELF-AC-006`, `AC-010`〜`AC-013`):** `python3 tests/verification.py --profile local-posix --receipt /tmp/receipt.json` および `npm test`（`mcp/sdd-forge-mcp`）

---

## Spec Amendments
*(承認後のタスク変更および `SELF-REQ-006` により確定した廃止対象テスト一覧をここに追記する)*
