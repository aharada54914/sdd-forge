# ADR-0053: Verification-First Guardrails, Self-Verification & Test Consolidation, and Agentic Factory Evolution

- **Status:** Proposed
- **Date:** 2026-11-25
- **Supersedes / Extends:** Extends [ADR-0051 (Lightweight Guardrails & SDD Core)](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0051-lightweight-guardrails-and-sdd-core.md) and [ADR-0052 (MCP Architecture & v2 Consolidation)](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0052-mcp-architecture-and-v2-consolidation.md) without breaking changes
- **Target Version:** `v2.2.0`+（基準: `v2.1.3`）

---

## 1. Context

`sdd-forge v2.x`（[ADR-0051](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0051-lightweight-guardrails-and-sdd-core.md) / [ADR-0052](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0052-mcp-architecture-and-v2-consolidation.md)）では、v1 系の 4言語 7,247行フック、224ファイルハードロック（`guard-invariants.json`）、`MANIFEST.sha256`、外部署名鍵（`~/.sdd/sudo-key`, `~/.sdd/evidence-key`）、および承認サイドカーを一掃し、**「Local Soft, Boundary Firm」**・**Node.js >= 20 LTS 単一ランタイム**・**4ツール読み取り専用 MCP（既定 OFF）**・**ローカル検証2分／PR検証10分目標**（[docs/verification.md](https://github.com/aharada54914/sdd-forge/blob/main/docs/verification.md)）の軽量基盤を確立した。

一方、2025〜2026年の AI エージェント駆動開発（[Tobi Lütke 対談](https://www.youtube.com/watch?v=w0oOxs0WKNk)、[OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)、[Martin Fowler: Harness Engineering](https://martinfowler.com/articles/harness-engineering.html)、[Anthropic: Harness Design (Mar 2026)](https://www.anthropic.com/research/harness-design-long-running-apps)）と、`sdd-forge` 自身の [tests/](https://github.com/aharada54914/sdd-forge/tree/main/tests)（直下250+ファイル）の実態を踏まえると、**2つの軸（内向き＝本体品質保証とテスト刷新、外向き＝利用者開発フロー機能）**の同時進化が必要である。

1. **軸A（Self-Verification & Test Consolidation — 本体品質保証＆テスト引き算）**:
   - `sdd-forge` 自身のコア状態機械（`task-lock.mjs`、`run-sdd-gate.mjs` / `sdd-ship`、`check-spec-drift.mjs`）に TLA+ 形式検証＋実装 [Trace Validation](https://sefm-conference.github.io/2024/acceptedpapers/) を適用し、さらに `v2-readonly-core.mjs` 純粋性や 4 CLI パリティを AST Fitness Functions で機械強制する。
   - 同時に、`tests/` に蓄積した **v1 廃止機能の残骸（`resolve-project-context-*` 24本等）・`.ps1`/`.sh` 多言語ペア＆14系統の `parity` テスト・手書き状態遷移列挙テスト・散在整合スクリプト**を、同等以上の欠陥検知パリティを証明した上で安全に廃止・統合する。
2. **軸B（User-Facing SDD Workflow — 利用者向けプラグイン機能）**:
   - 軸A（`sdd-forge` 本体 CI）で「誤検知 < 5%・ローカル 2分／PR 10分以内」を実証（Dogfooding-First）した仕組みを、利用者プロジェクト向けの Reframing、チェッカー非依存の形式検証ゲート（TLA+ 標準・Lean 4 拡張対応）、AST 厳格 Lint、固定アローリスト Security Gate、Differential Rebuild、および F-8 OTel / MCP v2 観測性として提供する。

---

## 2. Non-Regression Constraints（`ADR-0051` / `ADR-0052` 軽量原則の絶対遵守）

1. **ハッシュ局所化**: [record-spec-baseline.mjs](https://github.com/aharada54914/sdd-forge/blob/main/plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs) の SHA-256 対象は `specs/<feature>/` の数ファイル（数KB・$O(N)$）に厳密限定し、リポジトリ全体ハッシュ・外部署名鍵・`MANIFEST.sha256` は一切導入しない。
2. **Layer 1（`sdd-soft-guard.mjs`）不変**: 約200行・ゼロ依存・3責務を維持し、AST 解析や新規ハッシュ処理は Layer 1 に入れず Layer 2/3 に配置する。
3. **Git diff ＋ `CODEOWNERS` による境界保護**: 改ざん検知・ロール Write-Scope 強制はファイルハッシュではなく `git diff --name-only <base_ref>`（Layer 2）および `CODEOWNERS` / Branch Protection（Layer 3）でゼロオーバーヘッドに担保する。
4. **サイドカー非増殖＆MCP 既定 OFF 維持**: Waiver は `sdd/guardrails.yaml` 内に内蔵し、形式検証キャッシュは `git diff`＋CI 標準 `actions/cache` に委ねる。`sdd-forge-mcp` は [ADR-0052](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0052-mcp-architecture-and-v2-consolidation.md) 通り「既定 OFF・4ツール・読み取り専用 SSOT」を維持する。

---

## 3. Decision

### 3.1 Computational 層と Inferential 層の厳格分離
- **Computational 層（`plugins/sdd-quality-loop/scripts/v2/*.mjs`）**: 既存13本＋新規4本（`discover-state-machines.mjs`, `run-formal-gate.mjs`, `run-agent-lint.mjs`, `run-security-gate.mjs`）はすべて Node.js >= 20 LTS の決定論的 ESM とし、合否判定コアに LLM 呼び出しを含めない。
- **Inferential 層（プラグイン／エージェント）**: Problem Reframing、`state-machine.md` / `.tla` / `.lean` / PBT の起案、CEGIS 反例修復、メタ分析の定性要約を担う。

### 3.2 Part I（軸A）：`sdd-forge` 本体品質保証＆既存テスト安全廃止（Dogfooding-First）
1. **本体コアの TLA+ 形式検証＋Trace Validation**: `specs/self-verification/formal/TaskLock.tla`（リース排他ロック）および `GateLifecycle.tla`（承認・自動修正・`OQ-NNN`・`TAMPER_DETECTED` 遷移）を整備し、本体 CI で常時検証する。
2. **本体 Self-Fitness Functions**: `v2-pure-lib.mjs` / `v2-readonly-core.mjs` の `node:fs`・`process.env`・書込 API 非依存（AST 検査）、`sdd-soft-guard.mjs` の軽量性維持（300行・200ms 以内）、4 CLI マニフェストパリティおよび Doc-Gardening を機械強制する。
3. **本体敵対的セキュリティ回帰＆Self-Rebuild**: プロンプトインジェクション模擬 Issue・パストラバーサル・`command` 注入の拒否テスト、PR Semgrep/Gitleaks＋夜間 CodeQL＋Slopsquatting 検査、および残存 Python/PowerShell/Shell ヘルパーの ESM 統合時の Differential Testing を導入する。
4. **既存 250+ テストの安全廃止・統合プロトコル（Zero-Regression Test Retirement）**:
   - **廃止・統合対象4カテゴリ**: ①v1 廃止残骸（`resolve-project-context-*` 24本、`human-copy-*`、`rollback-1.5.0` 等）、②ESM 統合後の `.ps1`/`.sh` ペア＆14系統の `parity` テスト、③TLA+＋Trace Validation へ置換可能な手書き状態遷移・ループ・ロック列挙テスト（`workflow-state*`, `loop-*` 等）、④Self-Fitness Functions へ集約可能な散在整合スクリプト（`doc-diagrams.*`, `check-placeholders*` 等）。
   - **保持必須（廃止禁止）**: `v2-real-flows-e2e.test.mjs`, `v2-sdd-core-flow.test.mjs`, `v2-hooks-and-ci.test.mjs`, `v2-mcp-server.test.mjs`, `tests/gemini-environment-loops.tests.py`, `tests/golden/**`。
   - **安全廃止3条件**: ①置換先による負例検知パリティ証明（Shadow 並走）、②`verification-catalog-status.mjs` 照合＋承認済み廃止リスト明記（無断テスト削除の `TAMPER_DETECTED` と分離）、③`verification-timings.json` による時間・ファイル数削減記録。

### 3.3 Part II（軸B）：利用者プロジェクト向け開発フロー拡張
1. **リスク連動 Reframing ＆ Knowledge メタ分析**: `standard`/`high`（または `--reframe`）で `design.md` に前提・最小案・抜本案を比較出力（`low` はスキップ、[Martin Fowler: Understanding SDD](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)）。`sync-knowledge.mjs meta-analyze` で決定論的集計 JSON を出力。
2. **チェッカー非依存の多層形式検証ゲート**: `formal_verification.checker.adapter` を `"tlc" | "apalache" | "lean4" | "none"` に抽象化（Phase 2 で TLA+ 標準実装、Phase 3+ で `lean4` オプトイン）。`baseline`＋`negative`（`expected_violated_invariant` 照合）＋Trace Validation / PBT 接続（[Anthropic: PBT](https://www.anthropic.com/research/property-based-testing)）を検証。ローカル未導入時は終了コード `10`（CI 時 `1`）。
3. **Layer 2/3 専用 AST Agent-Strict Lint ＆ 内蔵 Waiver**: `diff_only: true`、組み合わせ分岐ブール群限定、循環依存・レイヤー境界、Remediation Injection、`sdd/guardrails.yaml` 内蔵の期限付き Waiver（インライン抑止コメント禁止）。
4. **固定アローリスト Security Gate・Git diff Anti-Tampering・Differential Rebuild**: `command` キー禁止・`execFile(shell: false)`、Slopsquatting 防御（[CSA Research (Apr 2026)](https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419-csa/)）、シークレットマスキング、`git diff` Anti-Tampering（終了コード `4`）、および `/sdd-ship:ship --mode rebuild`（Differential + NFR 回帰）。
5. **F-8 Write-Scope ＆ OTel / MCP v2 統合**: `check-traceability.mjs` の `git diff` Write-Scope、`task-lock.mjs` 競合時終了コード `3`、`factory-metrics.mjs` の [OpenTelemetry GenAI](https://opentelemetry.io/blog/2026/genai-observability/) メタデータ（本文非収集）、`sdd-forge-mcp`（既定 OFF・4ツール維持）のオプショナル集約。

### 3.4 Fail-Fast 7ステージ順序と共通終了コード規約
- **実行順**: `1: Spec Drift & Anti-Tampering` → `2: Traceability & Role Write-Scope` → `3: Agent-Strict Lint` → `4: Fast Verification` → `5: Builtin Secret & Slopsquatting` → `6: Formal Gate ∥ External SAST（並列）` → `7: Acceptance / PBT / Differential & NFR`。
- **終了コード**: `0` (`PASS`/`WARN`), `1` (`FAIL`), `2` (`TOOL_ERROR`), `3` (`LOCK_CONFLICT`), `4` (`TAMPER_DETECTED`), `10` (`DEFERRED_TO_CI` — CI 境界では `1` へ昇格)。

---

## 4. Consequences, Rollout & Rollback

- **Positive**: `sdd-forge` 本体の排他・ゲート品質を TLA+ と Fitness Function で機械保証しつつ、肥大化した 250+ テストを安全に削減して CI 負荷（特に PowerShell 系）を圧縮できる。さらに本体で実証済みの仕組みだけを利用者へ提供するため誤検知リスクを最小化できる。
- **Rollout**: Phase 1（v1 残骸廃止・Self-Fitness・Agent Lint Shadow）→ Phase 2（本体 TLA+・手書き状態遷移テスト圧縮・利用者 Formal/Security Gate）→ Phase 3（Self-Rebuild・`.ps1`/`.sh` ペア廃止・`--mode rebuild`・`lean4` オプトイン）。
- **Rollback**: 各セクションの `enabled: false` 単一フラグで既存設定や仕様を破壊せず即座に `v2.1.3` 相当へ復帰可能。

---

## 5. References
- [ADR-0051](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0051-lightweight-guardrails-and-sdd-core.md) / [ADR-0052](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0052-mcp-architecture-and-v2-consolidation.md) / [docs/verification.md](https://github.com/aharada54914/sdd-forge/blob/main/docs/verification.md) / [docs/non-interactive-factory.md](https://github.com/aharada54914/sdd-forge/blob/main/docs/non-interactive-factory.md) / [tests/](https://github.com/aharada54914/sdd-forge/tree/main/tests) / [Reservation.tla](https://github.com/aharada54914/sdd-forge/blob/main/tests/fixtures/project-skills/formal-review-reservation/Reservation.tla)
- [Tobi Lütke 対談 (YouTube)](https://www.youtube.com/watch?v=w0oOxs0WKNk) / [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/) / [Martin Fowler: Harness Engineering](https://martinfowler.com/articles/harness-engineering.html) / [Understanding SDD](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) / [Anthropic: Harness Design (Mar 2026)](https://www.anthropic.com/research/harness-design-long-running-apps) / [PBT](https://www.anthropic.com/research/property-based-testing) / [Apalache Docs](https://apalache-mc.org/docs/apalache/running.html) / [SEFM 2024](https://sefm-conference.github.io/2024/acceptedpapers/) / [OpenTelemetry GenAI](https://opentelemetry.io/blog/2026/genai-observability/) / [CSA Slopsquatting](https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419-csa/)
