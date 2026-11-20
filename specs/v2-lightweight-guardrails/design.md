# 設計（SDD Core）: v2-lightweight-guardrails

## 設計方針

「Local Soft, Boundary Firm」原則に基づき、ゼロ外部依存の **Node.js ESM（Node >= 20 LTS）** で Phase 1 プロトタイプ群を構築する。既存 `v1.26.0` の稼働パスを壊さないよう、Phase 1 では `plugins/sdd-quality-loop/scripts/v2/` 配下へ加算実装し、`node --test` で仕様契約を完全に証明する。

## モジュール構成

| パス | 責務 |
|---|---|
| `contracts/guardrails.schema.json` | `sdd-guardrails/v1` 設定ファイルの JSON Schema 定義 |
| `sdd/guardrails.example.yaml` | 導入リポジトリ向けの標準設定テンプレート |
| `plugins/sdd-quality-loop/scripts/v2/guardrails-lib.mjs` | ルート探索、設定ロード（JSON/簡易 YAML）、承認判定、改行正規化 SHA-256、安全差分判定（`Status:` / `Spec Amendments`）、REQ/AC 抽出、イベントログ追記 |
| `plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs` | 4 環境対応（Claude / Codex / Copilot / Gemini）の軽量 PreToolUse ソフトガード |
| `plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs` | 承認時点の仕様スナップショット（`.spec-baseline.json`）生成 CLI |
| `plugins/sdd-quality-loop/scripts/v2/check-spec-drift.mjs` | ベースライン対比の仕様ドリフト・ゴールポスト移動検知 CLI（JSON / Markdown 出力） |
| `tests/v2-soft-guard.test.mjs` | `sdd-soft-guard.mjs` のユニット & CLI 結合テスト |
| `tests/v2-spec-drift.test.mjs` | `record-spec-baseline.mjs` + `check-spec-drift.mjs` の結合テスト |

## インターフェース・データ契約

### 1. 設定ファイル（`sdd/guardrails.yaml` / `sdd/guardrails.json`）

- 優先順位: `sdd/guardrails.json` → `sdd/guardrails.yaml` → 組み込み既定値（`mode: "confirm"`, `allow_amendment_section: true`）。
- 外部 YAML ライブラリに依存しないよう、サポートする YAML は標準設定の 2 階層マップ＋配列＋スカラー（コメント可）に限定し、明確にパースする。

### 2. `sdd-soft-guard.mjs` 出力契約（4 環境互換）

| `--emit` モード | 対象ホスト | `allow` 出力 | `deny` 出力 |
|---|---|---|---|
| `exit`（既定） | Claude Code / Codex CLI | exit `0`（`warn` 時のみ stderr へ警告出力） | reason を stderr 出力、exit `2` |
| `copilot` | GitHub Copilot CLI | stdout `{"permissionDecision":"allow"}`、exit `0` | stdout `{"permissionDecision":"deny","permissionDecisionReason":"..."}`、exit `0` |
| `gemini` | Gemini CLI (`BeforeTool`) | stdout `{"decision":"allow"}`、exit `0` | stdout `{"decision":"deny","reason":"..."}`、exit `0` |

### 3. 安全編集の判定規則

- **承認判定**: `specs/<feature>/.spec-baseline.json` が存在するか、または `specs/<feature>/tasks.md` に `Approval: Approved` 行が 1 つ以上存在する場合に「承認済み」とみなす。
- **`Status:` 遷移のみの許可（`tasks.md`）**: 変更前後の内容を比較する際、`Status:` 行および `### Spec Amendments` / `## Spec Amendments` セクションを除いた本文が一致すれば安全な編集とみなす（ただし `Approval: Approved` の純増チェックはこれより先に独立して必ず実行する）。
- **Amendment 追記のみの許可（他仕様ファイル）**: `allow_amendment_section: true` のとき、`## Spec Amendments` または `### Spec Amendments` 見出しより前の本文が完全に一致していれば、Amendment 追記のみと判定して許可する。

### 4. Spec Drift 判定アルゴリズム（`check-spec-drift.mjs`）

1. `specs/<feature>/.spec-baseline.json` を読み込む。
2. 対象仕様ファイルごとに現在のハッシュを計算（`tasks.md` は `Status:` 行と `Spec Amendments` セクションを除いた契約ハッシュで比較。他ファイルは `Spec Amendments` セクションを除いた本文ハッシュで比較）。
3. 本文に変更があるファイル（および削除されたファイル）を `changedFiles` として抽出。
4. ベースラインの `REQ-*` / `AC-*` マップと現在ファイルの `REQ-*` / `AC-*` マップを比較し、`removedIdentifiers`・`modifiedIdentifiers`・`addedIdentifiers` を算出。
5. 変更されたファイル自身、または同フィーチャーの `tasks.md` / `requirements.md` の `Spec Amendments` セクションから非空・非プレースホルダーの変更理由行を収集。
6. 判定:
   - `changedFiles.length === 0` かつ `removedIdentifiers.length === 0` かつ `modifiedIdentifiers.length === 0` → **`CLEAN`**
   - 変更があり、かつ有効な Amendment 理由が 1 件以上記載されている → **`AMENDED`**
   - 変更があるが有効な Amendment 理由が記載されていない → **`UNDECLARED_DRIFT`**

## テスト方針

- `node --test tests/v2-soft-guard.test.mjs tests/v2-spec-drift.test.mjs` で AC-001〜AC-010 を全件自動検証する。
- 一時ディレクトリ（`os.tmpdir()`）内に擬似リポジトリを構築してテストを隔離し、ワークツリーを汚さない。
