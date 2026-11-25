# Design: Verification-First & Self-Verification Factory (`verification-first-factory`)

- **Feature:** `verification-first-factory`
- **Version:** `v2.1`（両軸構成：Self-Verification & テスト刷新 × 利用者開発フロー）
- **Related ADR:** `docs/adr/0053-verification-first-and-agentic-factory.md`
- **Target Runtime:** Node.js >= 20 LTS（`plugins/sdd-quality-loop/scripts/v2/*.mjs` 単一実装）

---

## 1. Problem Reframing（暗黙の前提とアプローチ比較 — `REQ-001` 準拠）

### 暗黙の前提（Assumptions）
1. 「新検証機能（TLA+・Lint・Security）は利用者プロジェクト向けの足し算であり、`sdd-forge` 本体の既存 250+ テストはそのまま積み増し続けるしかない」という先入観。
2. 「改ざん防止にはローカルの編集フック（Layer 1）や全ファイルハッシュが必要」という v1 時代の先入観（[ADR-0051](https://github.com/aharada54914/sdd-forge/blob/main/docs/adr/0051-lightweight-guardrails-and-sdd-core.md) が否定済み）。

### アプローチ比較
| 観点 | 案A：最小変更案（Incremental） | 案B：両輪 Dogfooding ＋ テスト引き算案（Ambitious / **採用案**） |
| :--- | :--- | :--- |
| **概要** | 利用者向けプラグイン機能だけを追加し、本体テスト 250+ 本には手を付けない。 | **Self-First（軸Aで本体に先行適用・実証）→ Productize（軸Bへ展開）**の順序を採用。本体コア（`task-lock.mjs`, `run-sdd-gate.mjs`）を TLA+ 化し、Self-Fitness Function と ESM 集約で**既存 250+ テストの4カテゴリを安全廃止・統合**する。境界保護は `git diff`＋`CODEOWNERS` に統一。 |
| **メリット** | 既存テストの棚卸しコストが不要。 | `sdd-forge` 本体品質の機械保証・CI 高速化（PowerShell 負荷圧縮）・`ADR-0051` 軽量性維持・将来の `lean4` 拡張をすべて同時達成できる。 |
| **トレードオフ** | 本体テストの肥大化・多言語重複が放置され、未実証の厳格ルールを利用者へ押し付けるリスクが高い。 | 既存テストの安全廃止プロトコル（Shadow 負例パリティ証明＋`verification-catalog-status.mjs` 照合）の運用が必要だが、回帰リスクをゼロに抑えられる。 |

---

## 2. コンポーネント設計（軸A 本体資産 ＋ 軸B 共通エンジン）

| 軸 | パス | 種別 | 責務（決定論 / 非決定論） |
| :---: | :--- | :---: | :--- |
| 軸A | `specs/self-verification/formal/{TaskLock,GateLifecycle}.{tla,cfg}` & `mapping.json` | **新規** | `task-lock.mjs`・`run-sdd-gate.mjs` / `sdd-ship` / `check-spec-drift.mjs` の本体公式 TLA+ モデル＆トレース対応表 |
| 軸A | `tests/self-fitness.test.mjs` | **新規** | `v2-readonly-core.mjs` 純粋性 AST 検査、`sdd-soft-guard.mjs` 300行/200ms ガード、4 CLI パリティ、Doc-Gardening |
| 軸A | `tests/self-security-adversarial.test.mjs` | **新規** | プロンプトインジェクション模擬 Issue・パストラバーサル・`command` 注入の敵対的回帰スイート |
| 共通 | `plugins/sdd-quality-loop/scripts/v2/guardrails-lib.mjs` | 変更 | 新規オプショナルセクション補完・固定アローリスト検証（`command` 拒否）・`lean4` スキーマ許容 |
| 共通 | `plugins/sdd-quality-loop/scripts/v2/check-spec-drift.mjs` | 変更 | 既存 `specs/<feature>/` ハッシュ比較を維持＋`git diff` Anti-Tampering（終了コード `4`、承認済みテスト廃止は除外） |
| 共通 | `plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs` | 変更 | `git diff --name-only` ベースのロール別 Write-Scope 検証追加 |
| 共通 | `plugins/sdd-quality-loop/scripts/v2/discover-state-machines.mjs` | **新規** | `--scan`（AST 組み合わせブール・enum 抽出 JSON）／`--validate`（`state-machine.md` グラフ検証） |
| 共通 | `plugins/sdd-quality-loop/scripts/v2/run-formal-gate.mjs` | **新規** | 共通アダプタ契約（`tlc` / `apalache` / `lean4`）、`git diff` 未変更スキップ、有界制御、`expected_violated_invariant` 照合、Trace Validation |
| 共通 | `plugins/sdd-quality-loop/scripts/v2/run-agent-lint.mjs` | **新規** | Layer 2/3 専用 AST 検査（`diff_only`、`max_abstraction_depth`、相関ブール、循環依存）、`guardrails.yaml` 内蔵 Waiver、`remediation_hint` |
| 共通 | `plugins/sdd-quality-loop/scripts/v2/run-security-gate.mjs` | **新規** | 固定アローリストID起動（`execFile(shell: false)`）、`builtin-secret-pattern`、`builtin-slopsquatting`、マスク出力、fail-closed |
| 共通 | `plugins/sdd-quality-loop/scripts/v2/{run-sdd-gate,sync-knowledge,render-decision-view,v2-readonly-core,factory-metrics,sdd-doctor}.mjs` | 変更 | Fail-Fast 7ステージ、`meta-analyze`、反例 HTML 表示、OTel GenAI メタデータ（本文非収集）、アダプタ診断 |
| 共通 | `mcp/sdd-forge-mcp/src/{envelope.ts,status-view.ts}` & `plugins/{sdd-bootstrap,sdd-ship}/**` | 変更 | MCP 4ツール・既定 OFF 維持のオプショナル拡張、Reframing、`--mode rebuild`（Differential + NFR） |

> **不変ファイル（変更禁止）**: `sdd-soft-guard.mjs`（Layer 1 約200行）および `record-spec-baseline.mjs` のハッシュ対象スコープ（`specs/<feature>/` のみ）は拡張しない。

---

## 3. チェッカー非依存 形式検証アダプタ契約（TLA+ 標準・Lean 4 拡張対応）

```ts
interface FormalCheckerAdapter {
  readonly id: "tlc" | "apalache" | "lean4";
  detectTool(env: NodeJS.ProcessEnv): Promise<{ available: boolean; version?: string; binPath?: string }>;
  checkSpec(input: {
    specEntry: string;
    configFile?: string;
    timeoutSec: number;
    options: Record<string, unknown>;
  }): Promise<{
    status: "PASS" | "FAIL" | "TIMEOUT" | "TOOL_ERROR";
    violatedInvariant?: string;
    traceFile?: string;
    summary: string;
  }>;
  validateTrace?(input: {
    mappingFile: string;
    traceGlob: string;
  }): Promise<{ status: "PASS" | "FAIL"; mismatchedStep?: number; reason?: string }>;
}
```

---

## 4. 既存 250+ テストの安全廃止・統合フロー（`SELF-REQ-006`）

1. **棚卸し（Phase 1）**: ローカルで `node tests/verification-catalog-status.mjs` を実行し、`unwired`（CI 未接続）および v1 廃止対象（`resolve-project-context-*` 24本、`human-copy-*`、`rollback-1.5.0` 等）を確定して承認済み廃止リストへ登録。
2. **置換パリティ証明（Phase 1〜3）**:
   - 散在整合スクリプト（`doc-diagrams.*`, `check-placeholders*` 等）→ `tests/self-fitness.test.mjs` で負例検知を確認後に廃止。
   - 手書き状態遷移・ループ・ロック列挙テスト（`workflow-state*`, `loop-*` 等）→ `TaskLock.tla` / `GateLifecycle.tla`＋Trace Validation で負例検知を確認後に圧縮・廃止。
   - `.ps1`/`.sh` ペア＆14系統 `parity` テスト → 残存ヘルパーの Node.js ESM 集約（Differential Testing 通過）後に単一 `v2-*.test.mjs` へ統合・廃止。
3. **保持境界**: `v2-real-flows-e2e.test.mjs`, `v2-sdd-core-flow.test.mjs`, `v2-hooks-and-ci.test.mjs`, `v2-mcp-server.test.mjs`, `tests/gemini-environment-loops.tests.py`, `tests/golden/**` は恒久保持。
4. **計測とロールバック**: `tests/verification-timings.json` で時間短縮を記録。新ゲートは各セクション `enabled: false` の単一フラグで即座に `v2.1.3` 相当へ切り戻し可能。
