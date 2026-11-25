# Tasks: Verification-First & Self-Verification Factory (`verification-first-factory`)

- **Feature:** `verification-first-factory`
- **Version:** `v2.2`（正規ステータス `Planned`・タスク別 `Risk` / `### Blockers`・単一責務 10 タスク分割版）
- **Approval:** `Approved`
- **Related Spec:** `specs/verification-first-factory/requirements.md`, `specs/verification-first-factory/design.md`
- **Related ADR:** `docs/adr/0054-verification-first-and-agentic-factory.md`（WFI-013: 起票・マージ前空き番号再確認必須）

---

## Wave 1: 基盤・スキーマ・Anti-Tampering・本体 Fitness ＆ カタログ棚卸し

### T-001: ADR-0054 正式化・`guardrails-lib.mjs` スキーマ拡張・`sdd-doctor.mjs` 診断・`AGENTS.md` 登録
- **Status:** `Implementation Complete`
- **Approval:** `Approved`
- **Risk:** `medium`
- **Covers:** `REQ-009`（アローリスト検証）, `REQ-012`（`sdd-doctor.mjs`）, `NFR-001`, `NFR-003`, `NFR-005`
- **Scope:** `docs/adr/0054-verification-first-and-agentic-factory.md`, `AGENTS.md`（`Active Spec Directories` 追加）, `sdd/guardrails.example.yaml`, `plugins/sdd-quality-loop/scripts/v2/{guardrails-lib,sdd-doctor}.mjs`
- **Implementation Notes:**
  - `guardrails-lib.mjs` に新規オプショナルセクション（`formal_verification.checker.{adapter, adapter_options.{tlc,apalache,lean4}}`, `agent_lint.waivers`, `security_audit.enabled_adapters`, `anti_tampering`）を追加し、`command` キーおよび未許可アダプタを終了コード `2` で拒否。既存スクリプト終了コードは変更しない。
- **Verification (`AC-008`, `AC-012`, `AC-013`):** `node --test tests/v2-sdd-doctor.test.mjs`
### Blockers
None

### T-002: `git diff` ベース Anti-Tampering ＆ `CODEOWNERS` 保護 `sdd/approved-test-retirements.json`
- **Status:** `Implementation Complete`
- **Approval:** `Approved`
- **Risk:** `high`
- **Covers:** `REQ-010`, `SELF-REQ-006`（承認マニフェスト分離）, `NFR-001`
- **Scope:** `plugins/sdd-quality-loop/scripts/v2/check-spec-drift.mjs`, `sdd/approved-test-retirements.json`（新規）, `CODEOWNERS`
- **Implementation Notes:**
  - `git diff <base_ref>` 解析で無承認保護パス改変・テスト削除/`skip` 増・抑止コメント・`.tla` `== TRUE` 化を検知し終了コード `4` を返す。テスト削除例外は `CODEOWNERS` 保護の `sdd/approved-test-retirements.json`（`path`＋`git_blob_sha` 一致）のみ許可。`record-spec-baseline.mjs` のハッシュ対象ファイル数は増やさない。
- **Verification (`AC-009`):** `node --test tests/v2-spec-drift.test.mjs`
### Blockers
T-001

### T-003: 本体 Self-Fitness Functions（`tests/self-fitness.test.mjs`）＆ ゴースト 56 件掃除・カテゴリ1/4 安全廃止
- **Status:** `Implementation Complete`
- **Approval:** `Approved`
- **Risk:** `medium`
- **Covers:** `SELF-REQ-003`, `SELF-REQ-006`（カテゴリ1・4）, `NFR-002`
- **Scope:** `tests/self-fitness.test.mjs`（新規）, `tests/verification-catalog.json`, `tests/verification-timings.json`, `docs/operations/verification-catalog-status.md`, `sdd/approved-test-retirements.json`
- **Measured Baseline (`2026-11-25`):** `tests/` 直下 386 ファイル、カタログ 262 件（稼働 10 / CI 外 196 / ゴースト 56、`resolve-project-context*` 24 本）、`sdd-soft-guard.mjs` 663 行。
- **Implementation Notes:**
  - `v2-readonly-core.mjs` 純粋性 AST 検査、`sdd-soft-guard.mjs` 非肥大化ラチェット（`<= 700` 行・外部依存ゼロ・`< 200ms`）、4 CLI パリティ、Doc-Gardening を実装。
  - ゴースト 56 件を掃除し、カテゴリ1（v1 廃止残骸）・カテゴリ4（散在整合スクリプト）について負例ミュータント 100% 検知パリティ確認後に `sdd/approved-test-retirements.json` 経由で廃止。
- **Verification (`SELF-AC-003`, `SELF-AC-006`):** `node --test tests/self-fitness.test.mjs` および `node tests/verification-catalog-status.mjs`（ゴースト 0 件）
### Blockers
T-002

---

## Wave 2: 新規決定論的ゲート群の並列実装（T-004 / T-005 / T-006 / T-007）

### T-004: Layer 2/3 専用 AST Agent-Strict Lint ＆ 内蔵 Waiver（Shadow 運用開始）
- **Status:** `Implementation Complete`
- **Approval:** `Approved`
- **Risk:** `medium`
- **Covers:** `REQ-007`, `REQ-008`, `NFR-002`, `NFR-004`
- **Scope:** `plugins/sdd-quality-loop/scripts/v2/run-agent-lint.mjs`（新規）, `plugins/sdd-quality-loop/rules/**`, `tests/fixtures/agent-lint/**`
- **Implementation Notes:**
  - `sdd-soft-guard.mjs`（Layer 1）は無変更。`diff_only: true` で JS/TS/MJS AST 解析（100件 `<= 3s`）と `guardrails.yaml` 内蔵 Waiver 期限検証、`remediation_hint` 出力を実装。
- **Verification (`AC-007`, `SELF-AC-005`):** `node plugins/sdd-quality-loop/scripts/v2/run-agent-lint.mjs --format json`
### Blockers
T-001

### T-005: 状態機械抽出＆チェッカー非依存・Windows 互換の多層形式検証ゲート（TLA+ 標準・Lean 4 予約）
- **Status:** `Implementation Complete`
- **Approval:** `Approved`
- **Risk:** `high`
- **Covers:** `REQ-003`, `REQ-004`, `REQ-005`, `REQ-006`
- **Scope:** `plugins/sdd-quality-loop/scripts/v2/{discover-state-machines,run-formal-gate,render-decision-view}.mjs`, `tests/fixtures/project-skills/formal-review-reservation/mapping.json`
- **Implementation Notes:**
  - `formal_verification.checker.adapter`（`tlc` / `apalache` 実装、`lean4` 予約）を実装。Windows では `java` バイナリを直接 `execFile('java', [...], { shell: false })` 起動（`.cmd`/`.bat` 禁止）。
  - `tasks.md` の任意トリガおよび `guardrails.yaml` の `trigger_tiers` を読み込み、正規フィクスチャ `tests/fixtures/project-skills/formal-review-reservation/Reservation.tla` で `baseline`＋`negative`（`expected_violated_invariant: OneAccepted`）＋NDJSON Trace Validation を検証。
- **Verification (`AC-003`, `AC-004`, `AC-005`, `AC-006`):** `Reservation.tla` 回帰＆Trace Validation テスト通過
### Blockers
T-001

### T-006: 本体公式 TLA+ モデル（`TaskLock.tla` / `GateLifecycle.tla`）＆ カテゴリ3重複列挙テスト圧縮
- **Status:** `Done`
- **Approval:** `Approved`
- **Risk:** `high`
- **Covers:** `SELF-REQ-001`, `SELF-REQ-002`, `SELF-REQ-006`（カテゴリ3）
- **Scope:** `specs/self-verification/formal/{TaskLock,GateLifecycle}.{tla,cfg}`, `specs/self-verification/formal/mapping.json`, `tests/project-skill-formal.tests.py`（CI 復帰）, `sdd/approved-test-retirements.json`
- **Implementation Notes:**
  - `task-lock.mjs` と `run-sdd-gate.mjs` / `sdd-ship` の TLA+ モデル＋NDJSON Trace Validation を実装。負例ミュータント 100% 検知を確認した重複状態列挙テストのみ圧縮し、実装境界テストは保持する。
- **Verification (`SELF-AC-001`, `SELF-AC-002`, `SELF-AC-006`):** `TaskLock.tla` / `GateLifecycle.tla` 回帰通過
### Blockers
T-002, T-005

### T-007: 固定アローリスト Security Gate・本体敵対的テスト・Reframing / Meta-Analyze
- **Status:** `Implementation Complete`
- **Approval:** `Approved`
- **Risk:** `high`
- **Covers:** `SELF-REQ-004`, `REQ-001`, `REQ-002`, `REQ-009`
- **Scope:** `plugins/sdd-quality-loop/scripts/v2/{run-security-gate,sync-knowledge}.mjs`, `plugins/sdd-bootstrap/**`, `tests/self-security-adversarial.test.mjs`（新規）
- **Implementation Notes:**
  - `run-security-gate.mjs` は実バイナリ（`.exe` / `node`＋JS）解決＋`execFile(..., { shell: false })` で `.cmd`/`.bat` 直起動を禁止。Slopsquatting・シークレットマスク・CI fail-closed を実装。
- **Verification (`SELF-AC-004`, `AC-001`, `AC-002`, `AC-008`):** `node --test tests/self-security-adversarial.test.mjs`
### Blockers
T-001

---

## Wave 3: 統合ゲート・Rebuild・OTel / MCP v2（T-008 / T-009）

### T-008: Fail-Fast 7ステージ統合・`--mode rebuild`（Differential + NFR）・Write-Scope 連携
- **Status:** `Done`
- **Approval:** `Approved`
- **Risk:** `high`
- **Covers:** `REQ-011`, `REQ-012`（Write-Scope・ロック連携）, `NFR-005`
- **Scope:** `plugins/sdd-quality-loop/scripts/v2/{run-sdd-gate,check-traceability}.mjs`, `plugins/sdd-ship/**`
- **Implementation Notes:**
  - `task-lock.mjs:345`（`exit 1` 不変）の JSON `acquired: false` を `run-sdd-gate.mjs` で fail-closed 検知。`--mode rebuild` の Differential Testing・`nfr-budget.json` 回帰検証を実装。
- **Verification (`AC-010`, `AC-011`):** `node --test tests/v2-sdd-core-flow.test.mjs`
### Blockers
T-002, T-004, T-005, T-007

### T-009: `v2-readonly-core.mjs`・`factory-metrics.mjs`（OTel GenAI）・`sdd-forge-mcp` オプショナル拡張
- **Status:** `Done`
- **Approval:** `Approved`
- **Risk:** `medium`
- **Covers:** `REQ-012`（OTel / MCP v2）, `NFR-003`
- **Scope:** `plugins/sdd-quality-loop/scripts/v2/{v2-readonly-core,factory-metrics}.mjs`, `mcp/sdd-forge-mcp/src/**`
- **Implementation Notes:**
  - `sdd-forge-mcp` は既定 OFF・4ツール維持のままオプショナルフィールドを追加。OTel GenAI メタデータはプロンプト本文非収集を既定とする。
- **Verification (`AC-012`, `AC-013`):** `npm test`（`mcp/sdd-forge-mcp`）
### Blockers
T-008

---

## Wave 4: CI 統合・Shadow→Strict 昇格検証・Self-Rebuild（カテゴリ2テスト廃止）

### T-010: CI 2層 SAST / `actions/cache` 統合・純増オーバーヘッド計測・Self-Rebuild 完了後のカテゴリ2廃止
- **Status:** `Implementation Complete`
- **Approval:** `Approved`
- **Risk:** `high`
- **Covers:** `SELF-REQ-005`, `SELF-REQ-006`（カテゴリ2）, `NFR-004`, `AC-013`
- **Scope:** `.github/workflows/sdd-guardrails.yml`, `.github/workflows/test.yml`, `tests/verification-catalog.json`, `sdd/approved-test-retirements.json`, `.gitignore`
- **Implementation Notes:**
  - PR へ Gitleaks（5〜15s）・Semgrep diff-only（20〜60s）・`actions/cache`（`hashFiles('specs/**/formal/**')`）を、夜間へ CodeQL（5〜15m）を配線。
  - Shadow 運用で誤検知 < 5% かつ 純増オーバーヘッド（ローカル `<= +15s` / PR CI `<= +120s`）を実証後に `strict` へ昇格。
  - **カテゴリ2（`.ps1`/`.sh` パリティテスト）は、対応本番スクリプトの Node.js ESM 集約と Windows ネイティブ CI 通過を確認した項目のみ** `sdd/approved-test-retirements.json` 経由で廃止する（E2E・3-AI・`tests/golden/**` は保持）。
- **Verification (`SELF-AC-005`, `SELF-AC-006`, `AC-013`):** `python3 tests/verification.py --profile local-posix --receipt /tmp/receipt.json`
### Blockers
T-003, T-006, T-009

---

## Spec Amendments
*(承認後の仕様・タスク変更時は、日付・理由・影響タスクをここに追記する。テスト廃止の例外承認は `CODEOWNERS` 保護の `sdd/approved-test-retirements.json` で管理する)*
