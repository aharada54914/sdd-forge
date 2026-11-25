# ADR-0054: Verification-First Guardrails, Self-Verification & Test Consolidation, and Agentic Factory Evolution

- **Status:** Proposed
- **Date:** 2026-11-25
- **Supersedes / Extends:** Extends [ADR-0051 (Lightweight Guardrails & SDD Core)](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0051-lightweight-guardrails-and-sdd-core.md) and [ADR-0052 (MCP Architecture & v2 Consolidation)](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0052-mcp-architecture-and-v2-consolidation.md) without breaking changes
- **Target Version:** `v2.2.0`+（基準: `v2.1.3`）
- **Numbering Re-Verification (WFI-013):** PR #974 が `docs/adr/0053-keyless-concept-decisions.md` を予約しているため `0054` を仮採番している。**マージ／正式起票直前に `ls docs/adr/` およびオープン PR の `docs/adr/NNNN-*.md` を再確認し、空き番号であることを確認すること。**

---

## 1. Context

`sdd-forge v2.x`（[ADR-0051](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0051-lightweight-guardrails-and-sdd-core.md) / [ADR-0052](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0052-mcp-architecture-and-v2-consolidation.md)）では、v1 系の 4言語 7,247行フック、224ファイルハードロック（`guard-invariants.json`）、`MANIFEST.sha256`、外部署名鍵（`~/.sdd/sudo-key`, `~/.sdd/evidence-key`）、および承認サイドカーを一掃し、**「Local Soft, Boundary Firm」**・**Node.js >= 20 LTS 単一ランタイム**・**4ツール読み取り専用 MCP（既定 OFF）**の軽量基盤を確立した。

一方、2025〜2026年の AI エージェント駆動開発（[Tobi Lütke 対談](https://www.youtube.com/watch?v=w0oOxs0WKNk)、[OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)、[Martin Fowler: Harness Engineering](https://martinfowler.com/articles/harness-engineering.html)、[Anthropic: Harness Design (Mar 2026)](https://www.anthropic.com/research/harness-design-long-running-apps)）と、`sdd-forge` 本体の実測値（`tests/` 直下 386 ファイル、`node tests/verification-catalog-status.mjs` による登録 262 件中 稼働 10 件・CI 外 196 件・ゴースト 56 件、`plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs` 663 行）を踏まえると、**2つの軸（軸A＝本体品質保証＆テスト刷新、軸B＝利用者開発フロー機能）**の同時進化が必要である。

---

## 2. Non-Regression Constraints（`ADR-0051` / `ADR-0052` 軽量原則の絶対遵守）

1. **ハッシュ局所化**: [record-spec-baseline.mjs](https://github.com/aharada54914/sdd-forge/blob/main/plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs) の SHA-256 対象は `specs/<feature>/` の数ファイル（数KB・$O(N)$）に厳密限定し、リポジトリ全体ハッシュ・外部署名鍵・`MANIFEST.sha256` は一切導入しない。
2. **Layer 1（`sdd-soft-guard.mjs`）不変＆非肥大化**: 現行実測 **663 行**（`wc -l plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs`）を不変ベースラインとし、AST 解析や新規ハッシュ処理は追加しない（Fitness Function は現行 663 行を基準に上限 `<= 700` 行の非肥大化ラチェットとして設定）。
3. **既存スクリプトの終了コード非破壊**: `task-lock.mjs:345`（取得失敗 `exit 1`）、`sdd-soft-guard.mjs`（ホストフック拒否 `exit 2`）、`validate-concept-test.py`（`DEFER=2`, `REJECT=3`）、`finalize-domain-review.*`（実行環境不在 `exit 3`）の終了コードは**一切変更しない**。共通終了コード規約は新規 v2 ゲートスクリプト群（`discover-state-machines.mjs`, `run-formal-gate.mjs`, `run-agent-lint.mjs`, `run-security-gate.mjs`）および `run-sdd-gate.mjs` の集約 JSON 出力のみに適用する。
4. **Git diff ＋ `CODEOWNERS` による境界保護**: 改ざん検知・ロール Write-Scope 強制・承認済みテスト廃止リスト（`sdd/approved-test-retirements.json`）の保護はファイルハッシュではなく `git diff --name-only <base_ref>`（Layer 2）および `CODEOWNERS` / Branch Protection（Layer 3）で担保する。
5. **サイドカー非増殖＆MCP 既定 OFF**: Lint Waiver は `sdd/guardrails.yaml` 内に内蔵し、形式検証キャッシュは `git diff`＋CI 標準 `actions/cache` に委ねる。`sdd-forge-mcp` は [ADR-0052](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0052-mcp-architecture-and-v2-consolidation.md) 通り既定 OFF・4ツール維持。

---

## 3. Decision

### 3.1 Computational 層と Inferential 層の厳格分離
- **Computational 層（`plugins/sdd-quality-loop/scripts/v2/*.mjs`）**: 既存13本＋新規4本はすべて Node.js >= 20 LTS の決定論的 ESM とし、合否判定コアに LLM 呼び出しを含めない。
- **Inferential 層（プラグイン／エージェント）**: Problem Reframing、`state-machine.md` / `.tla` / `.lean` / PBT の起案、CEGIS 反例修復、メタ分析の定性要約を担う。

### 3.2 Part I（軸A）：`sdd-forge` 本体品質保証＆既存テスト安全廃止（Dogfooding-First）
1. **本体コアの TLA+ 形式検証＋Trace Validation**: `specs/self-verification/formal/TaskLock.tla`（リース排他ロック）および `GateLifecycle.tla`（承認・自動修正・`OQ-NNN`・`TAMPER_DETECTED` 遷移）を整備し、本体 CI で常時検証する。
2. **本体 Self-Fitness Functions**: `v2-pure-lib.mjs` / `v2-readonly-core.mjs` の `node:fs`・`process.env`・書込 API 非依存 AST 検査、`sdd-soft-guard.mjs` の非肥大化ラチェット（`<= 700` 行・外部依存ゼロ・`< 200ms`）、4 CLI マニフェストパリティおよび Doc-Gardening を機械強制する。
3. **本体敵対的セキュリティ回帰＆2層 SAST**: プロンプトインジェクション模擬 Issue・パストラバーサル・`command` 注入の拒否テスト、PR Gitleaks（約5〜15秒）＋ Semgrep diff-only（約20〜60秒）、夜間 CodeQL（約5〜15分、公開リポジトリ追加課金なし）＋ Slopsquatting 検査を導入する。
4. **既存テストの安全廃止・統合プロトコル（Zero-Regression Test Retirement）**:
   - 承認済みテスト廃止リストは実装エージェントが編集できない **`CODEOWNERS` 保護ファイル `sdd/approved-test-retirements.json`**（`{ path, git_blob_sha, reason, approved_by }`）にのみ配置し、`tasks.md` からの自己承認による Anti-Tampering 迂回を防ぐ。
   - **負例検知パリティ証明（Mutation / Negative Parity）**: 廃止対象スイートの各失敗モードごとに最低1件の明示的ミュータント（負例）を定義し、置換先が 100% 検知することを Shadow 並走で証明する。
   - **カテゴリ別安全境界**: ①ゴースト 56 件＆v1 廃止残骸は Phase 1 で整理、②`.ps1`/`.sh` パリティテストは**対応する本番スクリプトの ESM 集約＋Windows ネイティブ CI 検証完了まで絶対に廃止しない**、③TLA+ で圧縮するのは重複する状態組合せ列挙テストのみとし実装境界テストは保持、④E2E・3-AI・`tests/golden/**` は恒久保持。

### 3.3 Part II（軸B）：利用者プロジェクト向け開発フロー拡張
1. **リスク連動 Reframing ＆ Knowledge メタ分析**: `standard`/`high`（または `--reframe`）で `design.md` に前提・最小案・抜本案を比較出力（`low` はスキップ、[Martin Fowler: Understanding SDD](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)）。
2. **チェッカー非依存の多層形式検証ゲート**: `formal_verification.checker.adapter` を `"tlc" | "apalache" | "lean4" | "none"` に抽象化（Phase 2 で TLA+ 標準実装、Phase 3+ で `lean4` オプトイン）。正規フィクスチャ [tests/fixtures/project-skills/formal-review-reservation/Reservation.tla](https://github.com/aharada54914/sdd-forge/blob/main/tests/fixtures/project-skills/formal-review-reservation/Reservation.tla) を基準に `baseline`＋`negative`（`expected_violated_invariant` 照合）＋Trace Validation / PBT 接続（[Anthropic: PBT](https://www.anthropic.com/research/property-based-testing)）を検証。
3. **Windows 互換プロセス起動（CVE-2024-27980 対応）**: Node 20.12+ で `execFile(..., { shell: false })` が `.cmd`/`.bat` を起動できない制約に対応し、JVM ツール（`tlc`/`apalache`）は `java` 実行ファイルを直接 `execFile('java', ['-Xmx...', '-cp', jarPath, ...], { shell: false })` で起動、ネイティブツールは実 `.exe` / バイナリ（または `node`＋JS エントリポイント）を解決して起動する。
4. **Layer 2/3 専用 AST Agent-Strict Lint ＆ 内蔵 Waiver**: `diff_only: true`、組み合わせ分岐ブール群限定、Remediation Injection、`sdd/guardrails.yaml` 内蔵の期限付き Waiver。
5. **固定アローリスト Security Gate・Git diff Anti-Tampering・Differential Rebuild・F-8 OTel / MCP v2**: `command` キー禁止、Slopsquatting 防御（[CSA Research (Apr 2026)](https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419-csa/)）、シークレットマスキング、`git diff` Anti-Tampering（新規ゲート終了コード `4`）、`/sdd-ship:ship --mode rebuild`（Differential + NFR）、[OpenTelemetry GenAI](https://opentelemetry.io/blog/2026/genai-observability/) メタデータ（本文非収集）。

### 3.4 新規ゲート共通終了コード規約（既存スクリプト対象外）と昇格時間基準
- **新規 v2 ゲートスクリプトの終了コード**: `0` (`PASS`/`WARN`), `1` (`FAIL`), `2` (`TOOL_ERROR`), `4` (`TAMPER_DETECTED`), `10` (`DEFERRED_TO_CI` — CI 境界では `1` へ昇格)。`task-lock.mjs` 等の既存終了コードは変更せず、`run-sdd-gate.mjs` 内部で JSON ステータスへ正規化する。
- **時間バジェットと昇格基準**: `docs/verification.md:164-166` の「ローカル 2分・PR 10分」は現行保証ではなく目標（targets）であり、既存 CI ジョブ上限は 30〜90 分（`docs/verification.md:46-53`）である。したがって本 ADR の合否・昇格条件には**新規ゲート追加による純増オーバーヘッド上限（ローカル `<= +15s`、`run-agent-lint.mjs` 100件 `<= 3s`、PR CI `<= +120s`）**および誤検知率 `< 5%` を用いる。

---

## 4. Rollout & Rollback（可逆／不可逆の明確な区分）

- **単一フラグで即座に切り戻せる範囲（可逆）**: `sdd/guardrails.yaml` の各新規セクション（`agent_lint`, `formal_verification`, `security_audit`, `anti_tampering`, `factory`）を `enabled: false` に設定すれば、新規ゲートの実行を即座に無効化して `v2.1.3` 相当のゲート挙動へ戻せる（既存スクリプトの終了コードは無変更のため呼び出し側への副作用ゼロ）。
- **フラグでは戻せない範囲（`git revert` 対象）**: `SELF-REQ-006` に基づき削除したレガシーテストファイルおよび `tests/verification-catalog.json` の変更は、機能フラグではなく該当 PR の `git revert` により復元する。

---

## 5. References
- [ADR-0051](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0051-lightweight-guardrails-and-sdd-core.md) / [ADR-0052](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0052-mcp-architecture-and-v2-consolidation.md) / [docs/verification.md](https://github.com/aharada54914/sdd-forge/blob/main/docs/verification.md)（`:46-53`, `:164-166`） / [docs/non-interactive-factory.md](https://github.com/aharada54914/sdd-forge/blob/main/docs/non-interactive-factory.md) / [Reservation.tla](https://github.com/aharada54914/sdd-forge/blob/main/tests/fixtures/project-skills/formal-review-reservation/Reservation.tla)
- [Tobi Lütke 対談 (YouTube)](https://www.youtube.com/watch?v=w0oOxs0WKNk) / [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/) / [Martin Fowler: Harness Engineering](https://martinfowler.com/articles/harness-engineering.html) / [Understanding SDD](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) / [Anthropic: Harness Design (Mar 2026)](https://www.anthropic.com/research/harness-design-long-running-apps) / [PBT](https://www.anthropic.com/research/property-based-testing) / [Apalache Docs](https://apalache-mc.org/docs/apalache/running.html) / [SEFM 2024](https://sefm-conference.github.io/2024/acceptedpapers/) / [OpenTelemetry GenAI](https://opentelemetry.io/blog/2026/genai-observability/) / [CSA Slopsquatting](https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419-csa/)
