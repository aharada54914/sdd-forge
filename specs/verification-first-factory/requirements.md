# Requirements: Verification-First & Self-Verification Factory (`verification-first-factory`)

- **Feature:** `verification-first-factory`
- **Version:** `v2.2`（両軸構成：Part I 本体品質保証＆テスト安全廃止 / Part II 利用者開発フロー機能）
- **Related ADR:** `docs/adr/0054-verification-first-and-agentic-factory.md`（**WFI-013 再確認指示**: PR #974 が `0053` を予約しているため `0054` を仮採番。マージ／起票直前に `ls docs/adr/` とオープン PR で空き番号を再確認すること）
- **Target Baseline:** [aharada54914/sdd-forge](https://github.com/aharada54914/sdd-forge) `v2.1.3`（Node.js >= 20 LTS）

---

## 1. 共通非回帰制約（Non-Regression Constraints: `NFR-*`）

- **NFR-001（ハッシュ局所化）**: [record-spec-baseline.mjs](https://github.com/aharada54914/sdd-forge/blob/main/plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs) の SHA-256 対象は `specs/<feature>/` 配下の保護仕様ファイル（数ファイル・数KB）に限定し、リポジトリ全体ハッシュ・外部署名鍵・`MANIFEST.sha256` を導入しないこと。
- **NFR-002（Layer 1 不変＆非肥大化）**: `plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs`（実測 **663 行**: `wc -l`）へ AST 解析や新規ハッシュ処理を追加しないこと（Fitness Function による非肥大化上限は現行 663 行基準で `<= 700` 行とする）。
- **NFR-003（サイドカー非増殖＆MCP 既定 OFF）**: Lint Waiver 用の独立ファイル・独自ハッシュキャッシュを作らず、`sdd-forge-mcp` は [ADR-0052](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0052-mcp-architecture-and-v2-consolidation.md) 準拠の「既定 OFF・4ツール・読み取り専用 SSOT」を維持すること。
- **NFR-004（新規ゲート純増オーバーヘッド＆CIコスト予算）**: `docs/verification.md:164-166` の「ローカル 2分・PR 10分」は targets（現行保証ではなく、既存 CI ジョブ上限は `docs/verification.md:46-53` の通り 30〜90 分）であるため、合否基準は新規追加による純増オーバーヘッド（ローカル `<= +15s`、`run-agent-lint.mjs` 100件 `<= 3s`、PR CI `<= +120s`；Gitleaks 5〜15s・Semgrep diff-only 20〜60s、CodeQL は夜間のみ 5〜15分）で判定すること。
- **NFR-005（決定論性＆既存終了コード非破壊）**: `plugins/sdd-quality-loop/scripts/v2/*.mjs` の合否判定コアに LLM 呼び出しを含めないこと。また既存スクリプト（`task-lock.mjs:345` `exit 1`、`sdd-soft-guard.mjs` `exit 2`、`validate-concept-test.py` `2`/`3`、`finalize-domain-review.*` `exit 3`）の終了コードは一切変更しないこと。

---

## 2. Part I（軸A）：`sdd-forge` 本体品質保証＆既存テスト安全廃止要件（`SELF-REQ-*`）

- **SELF-REQ-001（`task-lock.mjs` 排他リース TLA+ モデル＆トレース照合）**: `specs/self-verification/formal/TaskLock.tla`（`.cfg` / `mapping.json`）で同時有効所有者数 `<= 1` およびデッドロック不在を `baseline` / `negative`（`expected_violated_invariant` 照合）で検証し、`task-lock.mjs` 統合テストの NDJSON トレースを Trace Validation で照合する。
- **SELF-REQ-002（`run-sdd-gate.mjs` / `sdd-ship` / `check-spec-drift.mjs` 状態遷移 TLA+ 検証）**: `specs/self-verification/formal/GateLifecycle.tla` で「未承認 `Done` 不可」「`max_auto_fix_rounds` 超過時の `OQ-NNN` 遷移」「`TAMPER_DETECTED` 時の自動修復不可」「`UNDECLARED_DRIFT` 時の `PASS` 不可」を証明し、本体テストトレースと照合する。
- **SELF-REQ-003（本体 Architectural Fitness Functions）**: `tests/self-fitness.test.mjs` を新設し、①`v2-pure-lib.mjs` / `v2-readonly-core.mjs` の `node:fs`・`node:child_process`・`process.env`・書込 API 非依存 AST 検査、②`sdd-soft-guard.mjs` の非肥大化ラチェット（実測 663 行基準で `<= 700` 行・外部依存ゼロ・`< 200ms`）、③4 CLI マニフェスト・フックパリティおよび Doc-Gardening 検査を実装する。
- **SELF-REQ-004（本体敵対的セキュリティ回帰＆2層 SAST）**: プロンプトインジェクション模擬 Issue・パストラバーサル・シェルメタ文字・`command` キー注入の拒否フィクスチャを追加し、本体 CI に PR Gitleaks＋Semgrep diff-only、夜間 CodeQL＋Slopsquatting 検査を適用する。
- **SELF-REQ-005（Self-Rebuild 互換検証＆Dogfooding 昇格基準）**: 残存 Python / PowerShell / Shell ヘルパーの Node.js ESM 集約時は Differential Testing を必須とし、Part II の新ゲートを利用者既定 `strict` へ昇格するには、本体 CI の Shadow 運用で「誤検知率 < 5% かつ `NFR-004` の純増オーバーヘッド上限内（ローカル `<= +15s` / PR CI `<= +120s`）」の実証を必須とする。
- **SELF-REQ-006（既存テストの安全廃止・統合プロトコル）**: 実測 `tests/` 直下 **386 ファイル**（`find tests -maxdepth 1 -type f | wc -l`）および `node tests/verification-catalog-status.mjs`（登録 262 件：稼働 10 / CI 外 196 / ゴースト 56、`resolve-project-context*` 24 ファイル）の整理を以下の厳格条件で実施する：
  1. **人間承認マニフェスト分離**: 廃止対象リストは実装エージェントが編集できない **`CODEOWNERS` 保護ファイル `sdd/approved-test-retirements.json`**（`{ path, git_blob_sha, reason, approved_by }`）でのみ管理する（`tasks.md` への自己追記による Anti-Tampering 迂回を禁止）。
  2. **負例ミュータント・パリティ証明**: 廃止対象スイートの各失敗モードにつき最低1件の明示的ミュータント（負例）を定義し、置換先が 100% 検知することを Shadow 並走で証明する（v1 機能自体が廃止済みのカテゴリ1を除く）。
  3. **カテゴリ別安全境界**: カテゴリ2（`.ps1`/`.sh` パリティテスト）は**対応する本番 `.ps1`/`.sh` の ESM 集約＋Windows ネイティブ CI 検証完了まで廃止禁止**。カテゴリ3（TLA+ 圧縮）は重複する状態組合せ列挙テストのみ対象とし、実装境界テストは保持する。E2E・3-AI・`tests/golden/**` は恒久保持。

---

## 3. Part II（軸B）：利用者プロジェクト向け開発フロー要件（`REQ-*`）

- **REQ-001（リスク連動型 Problem Reframing）**: `/sdd-bootstrap:bootstrap` は `standard` / `high`（または `--reframe`）時、`design.md` に「暗黙の前提」「案A：最小変更案」「案B：構造簡素化・抜本解決案」を必須出力する（`low` は既定スキップ、[Martin Fowler: Understanding SDD](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)）。
- **REQ-002（決定論的 Knowledge メタ分析）**: `sync-knowledge.mjs meta-analyze` は `.learnings/`・`sdd/knowledge/`・`specs/`・`OQ-NNN` 履歴を集計し、`reports/spec-meta-analysis.json` を出力する。
- **REQ-003（決定論的状態機械シグナル抽出＆グラフ検証）**: `discover-state-machines.mjs`（`--scan` / `--validate`）を提供する。
- **REQ-004（チェッカー非依存・Windows 互換の多層形式検証ゲート）**: `run-formal-gate.mjs` は `formal_verification.checker.adapter`（`"tlc" | "apalache" | "lean4" | "none"`）を介し、`git diff` 未変更スキップ＋CI `actions/cache`、有界制御（`timeout_sec: 120`, `pr_total_budget_sec: 300`, `on_timeout: "fail"`）、TLA+ `baseline`＋`negative`（`expected_violated_invariant` 照合）、ローカル未導入時終了コード `10`（CI 時 `1`）を実行する。Windows（Node 20.12+ / CVE-2024-27980）対応として、JVM ツールは `java` バイナリを直接 `execFile('java', [...], { shell: false })` で起動し、`.cmd`/`.bat` ラッパーへ依存しないこと。
- **REQ-005（Spec-to-Code Conformance Bridge）**: `high` リスクで形式検証有効時、Trace Validation（NDJSON 照合、[SEFM 2024](https://sefm-conference.github.io/2024/acceptedpapers/)）または PBT/MBT スイート通過（[Anthropic: PBT](https://www.anthropic.com/research/property-based-testing)）の最低1つを必須とする。
- **REQ-006（CEGIS 反例フィードバック＆Human-on-the-Loop 可視化）**: 反例（`_TTrace_*.tla` / `lean4` ゴール要約）を `reports/verification/<run-id>/` へ保存し、`max_auto_fix_rounds` 超過時は `OQ-NNN` を起票して `render-decision-view.mjs --format html` に描画する。
- **REQ-007（Layer 2/3 専用 AST Agent-Strict Lint）**: `run-agent-lint.mjs` は `diff_only: true` で変更ハンクのみ検査し（Phase 1 公式 AST: JS/TS/MJS＋`ast-grep`）、`max_abstraction_depth`・同一スコープ組み合わせ分岐ブール群・循環依存を検証し、`remediation_hint` を付与する（[OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)）。
- **REQ-008（内蔵・期限付き Waiver ＆ インライン抑止禁止）**: インライン抑止コメント新規追加を禁止し、例外は `sdd/guardrails.yaml` の `agent_lint.waivers`（期限切れ自動 `FAIL`）でのみ許可する。
- **REQ-009（固定アローリスト Security Gate・Windows バイナリ解決・Slopsquatting 防御）**: `run-security-gate.mjs` は `command` キーをスキーマ禁止し、固定アローリストIDのみを実バイナリ（`.exe` / ELF / Mach-O または `node`＋JS エントリポイント）解決のうえ `execFile(..., { shell: false })` で起動する（`.cmd`/`.bat` 直起動禁止）。CI・`high_risk_paths` で fail-closed とし、Slopsquatting 検査（[CSA Research (Apr 2026)](https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419-csa/)）およびシークレット全出力マスクを行う。
- **REQ-010（Git diff ベース Anti-Tampering）**: Layer 2 の `git diff <base_ref>` 解析で無承認保護パス改変・無承認テスト削除/`skip` 増・抑止コメント追加・`.tla` `== TRUE` 化を検知時、終了コード `4`（`TAMPER_DETECTED`）で即時停止・`OQ-NNN` エスカレーションする。例外除外は `CODEOWNERS` 保護ファイル `sdd/approved-test-retirements.json` の `path`＋`git_blob_sha` 一致のみ許可する。
- **REQ-011（Differential & NFR Rebuild モード）**: `/sdd-ship:ship --mode rebuild` で契約・ゴールデン・`nfr-budget.json` の不変性を `git diff` 検証し、旧実装との Differential Testing および NFR 回帰検証（既定上限 `+10%`）を実行する。
- **REQ-012（Write-Scope・ロック連携・OTel / MCP v2 統合）**: `check-traceability.mjs` の `git diff` Write-Scope、既存 `task-lock.mjs:345`（`exit 1` 不変）の JSON `acquired: false` 読み取り連携、`v2-readonly-core.mjs` / `sdd-forge-mcp`（既定 OFF・4ツール維持）オプショナル集約、`factory-metrics.mjs` [OpenTelemetry GenAI](https://opentelemetry.io/blog/2026/genai-observability/) メタデータ（本文非収集）、`sdd-doctor.mjs` アダプタ診断を提供する。

---

## 4. 受入基準（`SELF-AC-001`〜`SELF-AC-006` ＋ `AC-001`〜`AC-013`）

| ID | 紐づく要件 | 検証可能な受入基準 |
| :--- | :--- | :--- |
| **SELF-AC-001** | SELF-REQ-001 | `TaskLock.tla` の `baseline` 通過、`negative` 相互排他違反照合、`task-lock.mjs` NDJSON トレース検証が本体 CI で通過すること。 |
| **SELF-AC-002** | SELF-REQ-002 | `GateLifecycle.tla` で未承認 `Done` 不可・無限自動修正不可・`TAMPER_DETECTED` 自動修復不可が証明され、本体テストトレースと整合すること。 |
| **SELF-AC-003** | SELF-REQ-003, NFR-002 | `v2-readonly-core.mjs` への `node:fs` import 負例、`sdd-soft-guard.mjs` の 700 行超過／外部依存追加負例（現行 663 行は PASS）、4 CLI パリティ不整合負例を `tests/self-fitness.test.mjs` が `FAIL` 検知すること。 |
| **SELF-AC-004** | SELF-REQ-004 | パストラバーサル・シェルメタ文字・`command` 注入・プロンプトインジェクション模擬 Issue が安全拒否され、本体 CI の Gitleaks / Semgrep diff-only / Slopsquatting が通過すること。 |
| **SELF-AC-005** | SELF-REQ-005, NFR-004 | 本体 Shadow 運用で誤検知率 < 5% かつ 新規ゲート純増オーバーヘッドがローカル `<= +15s`・PR CI `<= +120s` 以内であることが `tests/verification.py --receipt` で実証されること。 |
| **SELF-AC-006** | SELF-REQ-006 | 既存テスト廃止 PR が ①`CODEOWNERS` 保護 `sdd/approved-test-retirements.json`（パス＋blob SHA）記載、②廃止対象スイートの各失敗モードに対する負例ミュータント 100% 検知パリティ証明、③カテゴリ2の ESM 完了前廃止禁止遵守、④E2E・3-AI・`tests/golden/**` 保持、⑤`verification-timings.json` 削減記録を全件満たすこと。 |
| **AC-001** | REQ-001 | `standard`/`high` の `/sdd-bootstrap:bootstrap` で `design.md` に3項目が出力され、`low` では既定スキップされること。 |
| **AC-002** | REQ-002 | `sync-knowledge.mjs meta-analyze` が決定論的集計 JSON を出力し、空リポジトリでも終了コード `0` を返すこと。 |
| **AC-003** | REQ-003 | `discover-state-machines.mjs --scan` が組み合わせ分岐ブール群のみ抽出し、`--validate` が到達不能状態で終了コード `1` を返すこと。 |
| **AC-004** | REQ-004 | 正規フィクスチャ [tests/fixtures/project-skills/formal-review-reservation/Reservation.tla](https://github.com/aharada54914/sdd-forge/blob/main/tests/fixtures/project-skills/formal-review-reservation/Reservation.tla) に対し `checker.adapter: "tlc"`（`java` 直接起動）で `baseline`＋`negative`（`expected_violated_invariant: OneAccepted`）が通り、未変更時 `SKIPPED`・タイムアウト `FAIL`・未導入ローカル `10`（CI `1`）・`adapter: "lean4"` スキーマ許容となること。 |
| **AC-005** | REQ-005 | 実装出力の NDJSON トレースが仕様の禁止遷移を含む場合、Trace Validation が `FAIL` を返すこと。 |
| **AC-006** | REQ-006 | `max_auto_fix_rounds` 超過時に `OQ-NNN (Provisional)` が起票され、`render-decision-view.mjs --format html` に反例要約が表示されること。 |
| **AC-007** | REQ-007, REQ-008, NFR-002 | `sdd-soft-guard.mjs` 無変更（663行維持）のまま、`run-agent-lint.mjs` が `diff_only` で新規違反のみ `remediation_hint` 付き `FAIL`、期限内 Waiver 通過・期限切れ `FAIL` となること。 |
| **AC-008** | REQ-009 | 未許可アダプタ／`command` キーで終了コード `2`、`.cmd`/`.bat` 直起動拒否、シークレット全出力マスク、`high_risk_paths` で `high` 脆弱性およびアダプタ未導入が `FAIL` となること。 |
| **AC-009** | REQ-010, NFR-001 | `sdd/approved-test-retirements.json` 未記載のテスト削除・`git diff` 改ざんで終了コード `4` となり、`record-spec-baseline.mjs` のハッシュ対象ファイル数が増えないこと。 |
| **AC-010** | REQ-011 | `--mode rebuild` でゴールデン・`nfr-budget.json` 改変がブロックされ、Differential 差分または p95 +10% 超劣化で `FAIL` となること。 |
| **AC-011** | REQ-012, NFR-005 | `implementer` の保護パス編集を `check-traceability.mjs` がブロックし、`task-lock.mjs:345`（`exit 1` 不変）のロック競合 JSON を `run-sdd-gate.mjs` が fail-closed 検知すること。 |
| **AC-012** | REQ-012 | `factory-metrics.mjs` が OTel GenAI メタデータ（本文非収集）を集計し、`sdd-doctor.mjs` が設定済みアダプタを診断出力すること。 |
| **AC-013** | NFR-003, NFR-004, NFR-005 | `v2.1.3` 既存 `guardrails.yaml` のまま既存スクリプト終了コード不変・新規オーバーヘッド `<= +15s`（ローカル）・`mcp/sdd-forge-mcp` の `npm test`（既定 OFF・4ツール維持）が全件通過すること。 |

---

## Spec Amendments
*(承認後の仕様変更時は、日付・理由・影響IDをここに追記する。テスト廃止の例外承認はここではなく `CODEOWNERS` 保護の `sdd/approved-test-retirements.json` で管理する)*
