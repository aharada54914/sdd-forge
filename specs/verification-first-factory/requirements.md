# Requirements: Verification-First & Self-Verification Factory (`verification-first-factory`)

- **Feature:** `verification-first-factory`
- **Version:** `v2.1`（両軸構成：Part I 本体品質保証＆テスト安全廃止 / Part II 利用者開発フロー機能）
- **Related ADR:** `docs/adr/0053-verification-first-and-agentic-factory.md`（[ADR-0051](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0051-lightweight-guardrails-and-sdd-core.md) / [ADR-0052](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0052-mcp-architecture-and-v2-consolidation.md) 拡張）
- **Target Baseline:** [aharada54914/sdd-forge](https://github.com/aharada54914/sdd-forge) `v2.1.3`（Node.js >= 20 LTS）

---

## 1. 共通非回帰制約（Non-Regression Constraints: `NFR-*`）

- **NFR-001（ハッシュ局所化）**: [record-spec-baseline.mjs](https://github.com/aharada54914/sdd-forge/blob/main/plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs) の SHA-256 対象は `specs/<feature>/` 配下の保護仕様ファイル（数ファイル・数KB）に限定し、リポジトリ全体ハッシュ・外部署名鍵・`MANIFEST.sha256` を導入しないこと。
- **NFR-002（Layer 1 不変）**: `sdd-soft-guard.mjs`（約200行・ゼロ依存）へ AST 解析や新規ハッシュ処理を追加しないこと。
- **NFR-003（サイドカー非増殖＆MCP 既定 OFF）**: Waiver 独立ファイル・独自ハッシュキャッシュを作らず、`sdd-forge-mcp` は既定 OFF・4ツール・読み取り専用 SSOT を維持すること。
- **NFR-004（検証時間バジェット）**: [docs/verification.md](https://github.com/aharada54914/sdd-forge/blob/main/docs/verification.md) の目標（ローカル検証 2分以内・通常 PR 検証 10分以内）を遵守し、`run-agent-lint.mjs` は変更ファイル100件あたり 3秒以内とすること。
- **NFR-005（決定論性）**: `plugins/sdd-quality-loop/scripts/v2/*.mjs` の合否判定コアに LLM 呼び出しを含めないこと。

---

## 2. Part I（軸A）：`sdd-forge` 本体品質保証＆既存テスト安全廃止要件（`SELF-REQ-*`）

- **SELF-REQ-001（`task-lock.mjs` 排他リース TLA+ モデル＆トレース照合）**: `specs/self-verification/formal/TaskLock.tla`（`.cfg` / `mapping.json`）で同時有効所有者数 `<= 1` およびデッドロック不在を `baseline` / `negative`（`expected_violated_invariant` 照合）で検証し、`task-lock.mjs` 統合テストの NDJSON トレースを Trace Validation で照合する。
- **SELF-REQ-002（`run-sdd-gate.mjs` / `sdd-ship` / `check-spec-drift.mjs` 状態遷移 TLA+ 検証）**: `specs/self-verification/formal/GateLifecycle.tla` で「未承認 `Done` 不可」「`max_auto_fix_rounds` 超過時の `OQ-NNN` 遷移」「`TAMPER_DETECTED` 時の自動修復不可」「`UNDECLARED_DRIFT` 時の `PASS` 不可」を証明し、本体テストトレースと照合する。
- **SELF-REQ-003（本体 Architectural Fitness Functions）**: `tests/verification-catalog.json` に、①`v2-pure-lib.mjs` / `v2-readonly-core.mjs` の `node:fs`・`node:child_process`・`process.env`・書込 API 非依存 AST 検査、②`sdd-soft-guard.mjs` の外部依存ゼロ・300行以内・200ms 以内ガード、③4 CLI マニフェスト・フックパリティおよび Doc-Gardening 検査を組み込む。
- **SELF-REQ-004（本体敵対的セキュリティ回帰＆2層 SAST）**: プロンプトインジェクション模擬 Issue・パストラバーサル・シェルメタ文字・`command` キー注入の拒否フィクスチャを追加し、本体 CI に PR Semgrep/Gitleaks＋夜間 CodeQL＋Slopsquatting 検査を適用する。
- **SELF-REQ-005（Self-Rebuild 互換検証＆Dogfooding 昇格基準）**: 残存 Python / PowerShell / Shell ヘルパーの Node.js ESM 集約時は Differential Testing を必須とし、Part II の新ゲートを利用者既定 `strict` へ昇格するには、本体 CI の Shadow 運用で「誤検知率 < 5% かつ ローカル 2分／PR 10分以内」の実証を必須とする。
- **SELF-REQ-006（既存 250+ テストの安全廃止・統合プロトコル）**: [tests/](https://github.com/aharada54914/sdd-forge/tree/main/tests) の4カテゴリ（①v1 廃止残骸、②ESM 統合後の `.ps1`/`.sh` ペア＆14系統 `parity`、③TLA+ 置換可能な手書き状態遷移・ループ・ロック列挙、④Self-Fitness 集約可能な散在整合スクリプト）を段階的に廃止・統合する。E2E・3-AI 結合・`tests/golden/**` は保持必須とし、廃止時は ①置換先による負例検知パリティ証明（Shadow 並走）、②`verification-catalog-status.mjs` 照合＋承認済み廃止リスト記載、③`verification-timings.json` による時間・ファイル数削減記録の3条件を必須とする。

---

## 3. Part II（軸B）：利用者プロジェクト向け開発フロー要件（`REQ-*`）

- **REQ-001（リスク連動型 Problem Reframing）**: `/sdd-bootstrap:bootstrap` は `standard` / `high`（または `--reframe`）時、`design.md` に「暗黙の前提」「案A：最小変更案」「案B：構造簡素化・抜本解決案」を必須出力する（`low` は既定スキップ）。
- **REQ-002（決定論的 Knowledge メタ分析）**: `sync-knowledge.mjs meta-analyze` は `.learnings/`・`sdd/knowledge/`・`specs/`・`OQ-NNN` 履歴を集計し、`reports/spec-meta-analysis.json` を出力する。
- **REQ-003（決定論的状態機械シグナル抽出＆グラフ検証）**: `discover-state-machines.mjs`（`--scan` / `--validate`）を提供する。
- **REQ-004（チェッカー非依存・多層形式検証ゲート）**: `run-formal-gate.mjs` は `formal_verification.checker.adapter`（`"tlc" | "apalache" | "lean4" | "none"`）を介し、`git diff` 未変更スキップ＋CI `actions/cache`、有界制御（`timeout_sec: 120`, `pr_total_budget_sec: 300`, `on_timeout: "fail"`）、TLA+ `baseline`＋`negative`（`expected_violated_invariant` 照合）、ローカル未導入時終了コード `10`（CI 時 `1`）を実行する。
- **REQ-005（Spec-to-Code Conformance Bridge）**: `high` リスクで形式検証有効時、Trace Validation（NDJSON 照合）または PBT/MBT スイート通過の最低1つを必須とする。
- **REQ-006（CEGIS 反例フィードバック＆Human-on-the-Loop 可視化）**: 反例（`_TTrace_*.tla` / `lean4` ゴール要約）を `reports/verification/<run-id>/` へ保存し、`max_auto_fix_rounds` 超過時は `OQ-NNN` を起票して `render-decision-view.mjs --format html` に描画する。
- **REQ-007（Layer 2/3 専用 AST Agent-Strict Lint）**: `run-agent-lint.mjs` は `diff_only: true` で変更ハンクのみ検査し（Phase 1 公式 AST: JS/TS/MJS＋`ast-grep`）、`max_abstraction_depth`・同一スコープ組み合わせ分岐ブール群・循環依存を検証し、`remediation_hint` を付与する。
- **REQ-008（内蔵・期限付き Waiver ＆ インライン抑止禁止）**: インライン抑止コメント新規追加を禁止し、例外は `sdd/guardrails.yaml` の `agent_lint.waivers`（期限切れ自動 `FAIL`）でのみ許可する。
- **REQ-009（固定アローリスト Security Gate ＆ Slopsquatting 防御）**: `run-security-gate.mjs` は `command` キーをスキーマ禁止し、固定アローリストIDのみ `execFile(..., { shell: false })` で起動。CI・`high_risk_paths` で fail-closed とし、シークレットは全出力でマスクする。
- **REQ-010（Git diff ベース Anti-Tampering）**: Layer 2 の `git diff <base_ref>` 解析で無承認保護パス改変・無承認テスト削除/`skip` 増・抑止コメント追加・`.tla` `== TRUE` 化を検知時、終了コード `4`（`TAMPER_DETECTED`）で即時停止・`OQ-NNN` エスカレーションする（`SELF-REQ-006` の承認済みテスト廃止は除外）。
- **REQ-011（Differential & NFR Rebuild モード）**: `/sdd-ship:ship --mode rebuild` で契約・ゴールデン・`nfr-budget.json` の不変性を `git diff` 検証し、旧実装との Differential Testing および NFR 回帰検証（既定上限 `+10%`）を実行する。
- **REQ-012（Write-Scope・ロック・OTel / MCP v2 統合）**: `check-traceability.mjs` の `git diff` Write-Scope、`task-lock.mjs` 競合時終了コード `3`、`v2-readonly-core.mjs` / `sdd-forge-mcp`（既定 OFF・4ツール維持）オプショナル集約、`factory-metrics.mjs` OTel GenAI メタデータ（本文非収集）、`sdd-doctor.mjs` アダプタ診断を提供する。

---

## 4. 受入基準（`SELF-AC-001`〜`SELF-AC-006` ＋ `AC-001`〜`AC-013`）

| ID | 紐づく要件 | 検証可能な受入基準 |
| :--- | :--- | :--- |
| **SELF-AC-001** | SELF-REQ-001 | `TaskLock.tla` の `baseline` 通過、`negative` 相互排他違反照合、`task-lock.mjs` NDJSON トレース検証が本体 CI で通過すること。 |
| **SELF-AC-002** | SELF-REQ-002 | `GateLifecycle.tla` で未承認 `Done` 不可・無限自動修正不可・`TAMPER_DETECTED` 自動修復不可が証明され、本体テストトレースと整合すること。 |
| **SELF-AC-003** | SELF-REQ-003 | `v2-readonly-core.mjs` への `node:fs` import 負例、`sdd-soft-guard.mjs` 肥大化負例、4 CLI パリティ不整合負例を本体 Fitness Function が `FAIL` 検知すること。 |
| **SELF-AC-004** | SELF-REQ-004 | パストラバーサル・シェルメタ文字・`command` 注入・プロンプトインジェクション模擬 Issue が安全拒否され、本体 CI の Semgrep/Gitleaks/Slopsquatting が通過すること。 |
| **SELF-AC-005** | SELF-REQ-005 | 本体 Shadow 運用で誤検知率 < 5% かつ ローカル 2分以内・PR 10分以内が `tests/verification.py --receipt` で実証されること。 |
| **SELF-AC-006** | SELF-REQ-006 | 既存テスト廃止 PR が ①`verification-catalog-status.mjs` 照合、②置換先の負例検知パリティ証明、③承認済み廃止リスト記載、④`verification-timings.json` 時間・ファイル数削減記録、および E2E・ゴールデン保持を全件満たすこと。 |
| **AC-001** | REQ-001 | `standard`/`high` の `/sdd-bootstrap:bootstrap` で `design.md` に3項目が出力され、`low` では既定スキップされること。 |
| **AC-002** | REQ-002 | `sync-knowledge.mjs meta-analyze` が決定論的集計 JSON を出力し、空リポジトリでも終了コード `0` を返すこと。 |
| **AC-003** | REQ-003 | `discover-state-machines.mjs --scan` が組み合わせ分岐ブール群のみ抽出し、`--validate` が到達不能状態で終了コード `1` を返すこと。 |
| **AC-004** | REQ-004 | [Reservation.tla](https://github.com/aharada54914/sdd-forge/blob/main/tests/fixtures/project-skills/formal-review-reservation/Reservation.tla) に対し `checker.adapter: "tlc"` で `baseline`＋`negative`（`expected_violated_invariant`）が通り、未変更時 `SKIPPED`・タイムアウト `FAIL`・未導入ローカル `10`（CI `1`）・`adapter: "lean4"` スキーマ許容となること。 |
| **AC-005** | REQ-005 | 実装出力の NDJSON トレースが仕様の禁止遷移を含む場合、Trace Validation が `FAIL` を返すこと。 |
| **AC-006** | REQ-006 | `max_auto_fix_rounds` 超過時に `OQ-NNN (Provisional)` が起票され、`render-decision-view.mjs --format html` に反例要約が表示されること。 |
| **AC-007** | REQ-007, REQ-008, NFR-002 | `sdd-soft-guard.mjs` 無変更のまま、`run-agent-lint.mjs` が `diff_only` で新規違反のみ `remediation_hint` 付き `FAIL`、期限内 Waiver 通過・期限切れ `FAIL` となること。 |
| **AC-008** | REQ-009 | 未許可アダプタ／`command` キーで終了コード `2`、シークレット全出力マスク、`high_risk_paths` で `high` 脆弱性およびアダプタ未導入が `FAIL` となること。 |
| **AC-009** | REQ-010, NFR-001 | 無承認の `git diff` 改ざん・テスト削除で終了コード `4` となり、`record-spec-baseline.mjs` のハッシュ対象ファイル数が増えないこと。 |
| **AC-010** | REQ-011 | `--mode rebuild` でゴールデン・`nfr-budget.json` 改変がブロックされ、Differential 差分または p95 +10% 超劣化で `FAIL` となること。 |
| **AC-011** | REQ-012 | `implementer` の保護パス編集を `check-traceability.mjs` がブロックし、`task-lock.mjs` 競合時は終了コード `3` で停止すること。 |
| **AC-012** | REQ-012 | `factory-metrics.mjs` が OTel GenAI メタデータ（本文非収集）を集計し、`sdd-doctor.mjs` が設定済みアダプタを診断出力すること。 |
| **AC-013** | NFR-003, NFR-004 | `v2.1.3` 既存 `guardrails.yaml` のまま `tests/verification.py --profile local-posix`（2分以内）と `mcp/sdd-forge-mcp` の `npm test`（既定 OFF・4ツール維持）が全件通過すること。 |

---

## Spec Amendments
*(承認後の仕様変更・`SELF-REQ-006` テスト廃止リスト追加時は、日付・理由・影響IDをここに追記する)*
