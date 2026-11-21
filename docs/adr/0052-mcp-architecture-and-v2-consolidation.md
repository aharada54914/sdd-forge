# ADR-0052: MCP 3 サーバー構成の再評価と v2 最適 MCP アーキテクチャ

- **Status**: Accepted & Implemented (**v2.1.0** MCP Consolidation & Antigravity CLI Support)
- **Date**: 2026-11-22
- **Related**: [ADR-0051](0051-lightweight-guardrails-and-sdd-core.md), Issue #798, [docs/architecture/mcp-v2-spec.md](../architecture/mcp-v2-spec.md), [contracts/sdd-mcp.v2.schema.json](../../contracts/sdd-mcp.v2.schema.json)

## Context（実機検証から得られた事実）

SDD Forge v2.0.0 のローカル実機検証（Claude Code v2.1.330 / Codex CLI v0.171.0 / Gemini CLI v0.70.0 / Node v24.13.0）において、現行の 3 つの既定 MCP サーバー（`sdd-forge-mcp` / `local-env-mcp` / `ci-mcp`）を実測した結果、以下の構造的問題が判明した。

### 1. 実利用ゼロとコンテキスト税（Token Tax）

| サーバー | ツール数 | Schema サイズ | 推定コンテキスト消費 / ターン | アクティブ v2 スキルからの参照数 | 実機検証時の動作 |
|---|---:|---:|---:|---:|---|
| `sdd-forge-mcp` | 15 (16*) | 7,367 B | ~1,841 tokens | 2 箇所（いずれも任意参考） | v2 完了タスクを v1 `evidence.json` 不在で `verdict: fail` 誤判定（#798 で暫定修正） |
| `local-env-mcp` | 3 | 1,379 B | ~345 tokens | **0** | 起動するが `uname` / `node -v` / `which` で即代替可能 |
| `ci-mcp` | 5 | 4,470 B | ~1,118 tokens | **0** | 既定で `auth-missing` 失敗（ローカルには認証済み `gh` CLI が存在） |
| **合計** | **23** | **13,216 B** | **~3,304 tokens + 常駐 Node 3 本** | **実質 0** | Codex `exec` では `readOnlyHint` 欠落等により全ツール呼び出し拒否 |

*\*Codex 側ではリソース補助含め 16 ツール相当として露出。*

### 2. 「プラグインが稼働しているローカル環境を MCP 化すること」はそもそも適当か？

**結論: ローカル CLI プラグイン環境（Claude Code / Codex CLI / Copilot CLI / Gemini CLI）における常駐 MCP 3 サーバー既定導入は不適当（アンチパターン）である。**

1. **責務の重複（シェル・ファイル権限を既に持つホスト）**:
   ローカル CLI エージェントはすでにネイティブの `Read` / `Glob` / `Grep` / `Bash` / `gh` と、ゼロ依存の v2 正準スクリプト群（`plugins/sdd-quality-loop/scripts/v2/*.mjs`）を直接実行できる。同じローカル環境情報を MCP 経由で取り直す必然性がない。
2. **Single Source of Truth（SSOT）崩壊によるドリフト**:
   v2.0.0 で `scripts/v2/*.mjs` へ仕様刷新した一方、`mcp/sdd-forge-mcp`（TypeScript + esbuild バンドル）は v1 の `evidence.json` / `contract.json` / 7 層仕様パーサのまま取り残され、正規の v2 完了リポジトリに対して「不合格（`verdict: fail`）」という誤情報をエージェントへ返した。別実装の常駐ラッパーを持つこと自体が継続的なドリフト源となる。
3. **ADR-0051（軽量ガードレール）との矛盾**:
   v2.0.0 は過剰なオーバーヘッドを削減する刷新であるにもかかわらず、毎セッション 3 本の Node.js サーバーを起動し ~3,300 tokens の使われないツール定義を常時コンテキストへ注入している。
4. **承認 UX の劣化**:
   `codex exec` のような非対話・自動化環境では MCP ツール呼び出し自体が別系統の承認ゲートに引っかかりやすく、ローカルの `node scripts/v2/*.mjs` 実行より不安定である。

### 3. では、MCP が「本当に適当・最適」なユースケースは何か？

MCP は **「クライアントがローカルシェルやリポジトリ直接実行権限を持たない（または持たせたくない）境界」** にこそ最大の価値がある。

- **適するケース**:
  1. **非シェル環境 / 読み取り専用ホスト**: Claude Desktop、ChatGPT App、Web ベースのエージェント、外部ダッシュボードビューア、読み取り専用のクロスリポ監査セッション。
  2. **サンドボックス隔離された外部 API ゲートウェイ**: `gh` CLI やトークンをエージェントのシェル環境へ渡せない環境での CI 観測（この限定用途でのみ `ci-mcp` に存在意義がある）。
- **不適当なケース**:
  1. ローカル CLI プラグイン実行中に `local-env-mcp` で OS や CLI バージョンを問い合わせること（`sdd-doctor.mjs` や `node -v` で完結）。
  2. ローカル CLI プラグイン実行中に 15 個の細分化ツールで `specs/` を断片的に読むこと（`scripts/v2/*.mjs` 直接呼び出しの方が SSOT かつ高速・0 トークン税）。

---

## Decision（最適 MCP アーキテクチャ決定）

1. **ローカル CLI プラグインの既定導入では MCP クライアント登録をオプトイン化（既定 OFF）する**
   - ローカル CLI ワークフロー（`/sdd-bootstrap:bootstrap`, `/sdd-ship:ship`, `sdd-gate`）は、ゼロ依存 Node ESM の `plugins/sdd-quality-loop/scripts/v2/*.mjs` を **唯一の正準インターフェース（SSOT）** とする。
   - `/sdd-ship:status` のローカル HTML/ダッシュボード CLI 実行および既存 v2.0.0 からのアップグレード互換性を保つため、`INSTALL_ROOT/mcp/sdd-forge-mcp/dist/index.js` 自体は配置しつつ、各ホスト設定（Claude / Codex / Cursor / VS Code / Antigravity `agy` / Gemini）への MCP サーバー登録は `./install.sh --with-mcp` 明示指定時のみ行う（既定導入時は 0 トークン税・常駐プロセス 0 本。未選択の `local-env-mcp`/`ci-mcp` 旧登録はアップグレード時に自動整理）。

2. **3 サーバー構成を「単一サーバー（`sdd-forge-mcp` v2）＋ 2 サーバー整理」へ集約する（v2.1.0 で適用）**
   - **`local-env-mcp` → 非推奨（Deprecated in v2.1.0 → Remove in v2.2.0）**:
     ツール 3 種（`get_os_info` / `get_toolchain_versions` / `list_available_clis`）はローカル環境では完全冗長。必要な環境診断は `sdd-doctor.mjs` に統合する。
   - **`ci-mcp` → ローカル既定導入から除外（External/Sandboxed Opt-in のみ）**:
     ローカル開発環境では認証済み `gh` CLI を直接使う方が設定不要で信頼性が高い。シェルや `gh` を持たない隔離エージェント向けにのみ `--mcp ci-mcp` オプトインとして残置（または別リポジトリへ切り出し）。
   - **`sdd-forge-mcp` → v2 単一高凝集サーバー（4 ツール + 2 Resources）へ刷新**:
     詳細は [docs/architecture/mcp-v2-spec.md](../architecture/mcp-v2-spec.md) および [contracts/sdd-mcp.v2.schema.json](../../contracts/sdd-mcp.v2.schema.json) に規定する。
     - **4 ツール**:
       1. `sdd_project_overview` — 全 Active Features の進捗・リスク・次アクション・`sdd-doctor` 健全性を 1 往復で返す。
       2. `sdd_feature_state` — 指定 feature の REQ↔AC↔Task トレーサビリティ、Spec Drift (`CLEAN`/`AMENDED`/`UNDECLARED_DRIFT`/`UNBASELINED`/`BASELINE_ERROR`)、Decision View（`OQ-NNN` / Alternatives Rejected / 観点採否表）、最新ゲート状態を一括返却。
       3. `sdd_gate_audit` — 指定 feature / task の決定論証跡（`.execution.json`）と独立レビュー（`.md`）、Spec Drift、および `Risk: high` 未確定 `OQ-NNN` の fail-closed 整合性検証（v2 準拠）。
       4. `sdd_dashboard_snapshot` — 既存ダッシュボードビューア向け読み取り専用スナップショット（統一 `Result<T>` エンベロープ返却）。
     - **Single Source of Truth & Pure Read-Only 原則**: `sdd-forge-mcp` v2 はパーサを再実装せず、書込 API・`process.env`・`node:fs` を一切持たない純粋コア `plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs` に `path-guard.ts` 経由の `createGuardedIo(root)` を注入する（`dist/index.js` に書込 API を含めないことを静的テスト＋CI で強制）。
     - **全ツールに MCP Tool Annotations と厳格スキーマを必須化**: `annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true }` および `additionalProperties: false` を全ツールへ適用。
     - **コンテキスト消費目標**: 23 ツール (~3,304 tokens) → **4 ツール (~600 tokens, -82%)**、ローカル CLI 既定オプトイン時は **0 tokens**。

3. **v2.0.x での即時是正（#798 適用済み）**
   - 現行 `sdd-forge-mcp` の v2 リポジトリ誤判定バグ（`.spec-baseline.json` 存在時の v1 `evidence.json`/`contract.json` 強制要求、`VERDICT: PASS` 太字 Markdown と `.execution.json` の判定漏れ）を修正。
   - 現行 3 サーバーの全 23 ツールに `readOnlyHint: true` アノテーションを即時付与。
   - `USERGUIDE.md` の `Node >= 26.13.0` 旧記述を `Node >= 20 LTS` へ修正。

## Consequences

- **Positive**:
  - ローカル CLI 開発のトークン消費・起動レイテンシ・常駐プロセス数を大幅削減。
  - `scripts/v2/*.mjs` を SSOT 化することで、v1/v2 間の判定矛盾（偽 FAIL）が構造的に再発しない。
  - 非シェルクライアント（Desktop / Web / ダッシュボード）向けには、1 往復で意思決定に必要な全体像を返す高品質な 4 ツール MCP が提供される。
- **Trade-offs**:
  - v1 互換の `evidence_*` 6 ツールは v2.1 で廃止されるため、旧 v1 リポジトリの監査には v2.0.x タグを使用する。
