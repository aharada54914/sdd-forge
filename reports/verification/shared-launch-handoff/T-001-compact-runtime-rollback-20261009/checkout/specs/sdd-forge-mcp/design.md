# Design: sdd-forge-mcp

Impl-Review-Status: Passed
Feature Type: api-only (read-only MCP server; no frontend/UI)

## Technical Summary

sdd-forge リポジトリ初の Node/TypeScript コンポーネントとして、SDD 状態を
構造化して返す read-only MCP サーバーを `mcp/sdd-forge-mcp/` に追加する。
`@modelcontextprotocol/sdk` の stdio transport で 13 tools + 5 resources を
公開する。tasks.md 状態機械の判定は `check-task-state.sh` とのシェル等価を
ゴールデンテストで担保し、判定不能時は `cannot-parse` を返して推測しない。
配布はバンドル済み `dist/index.js` のコミットで行い、利用側は Node >= 20 のみを
要求する。installer はデフォルトで配置と Claude Code / Codex への登録を行う。

## Architecture

```text
mcp/sdd-forge-mcp/
├── package.json            # private, type: module, engines.node >= 20
├── tsconfig.json
├── src/
│   ├── index.ts            # entrypoint: root解決 → server起動 (stdio)
│   ├── server.ts           # McpServer 構築、tools/resources 登録
│   ├── root.ts             # ルート解決 (--root > SDD_FORGE_ROOT > cwd)、起動時固定
│   ├── path-guard.ts       # allowlist/denylist、realpath 検証、traversal 拒否
│   ├── envelope.ts         # ok/error レスポンスエンベロープ、エラーコード
│   ├── parsers/
│   │   ├── tasks.ts        # check-task-state.sh 等価パーサー（状態機械判定）
│   │   ├── agents-md.ts    # Active Spec Directories / Required Workflow 抽出
│   │   ├── review-ticket.ts# RT-*.yml (js-yaml)
│   │   ├── quality-report.ts # reports/quality-gate/*.md の VERDICT/counts 抽出
│   │   ├── evidence.ts     # *.evidence.json / *.contract.json
│   │   └── traceability.ts # traceability.md の表抽出
│   ├── tools/
│   │   ├── core.ts         # 8 core tools
│   │   └── evidence.ts     # 5 evidence tools
│   ├── resources.ts        # 5 resources (sdd:// URI)
│   └── next-command.ts     # 状態→次コマンド決定論マッピング
├── dist/
│   └── index.js            # esbuild バンドル成果物（コミット対象）
└── tests/                  # node:test ベース（golden/ parser/ path-security/ ...）
```

- すべての読み取りは `path-guard.ts` を必ず経由する（単一チョークポイント）。
- パーサーは「解釈できたもの」と「解釈できなかったもの」を厳密に区別し、
  後者は `cannot-parse`（詳細付き）として伝播する。フォールバック値を返さない。

## Components

| Component | Responsibility | Technology | New/Existing |
|---|---|---|---|
| server / index | MCP プロトコル処理、tool/resource 登録、起動 | @modelcontextprotocol/sdk (stdio) | New |
| root | プロジェクトルートの起動時解決・固定 | Node path/fs (realpath) | New |
| path-guard | allowlist/denylist・traversal 拒否（fail-closed） | Node path/fs | New |
| parsers | tasks.md 状態機械 / AGENTS.md / RT yml / QG report / evidence / traceability | TypeScript + js-yaml | New |
| tools/core | 8 core tools | TypeScript | New |
| tools/evidence | 5 evidence tools | TypeScript | New |
| resources | 5 resources | TypeScript | New |
| next-command | 状態→次 SDD コマンドの決定論マッピング | TypeScript | New |
| installer 拡張 | mcp 配置 + Claude/Codex 登録 + `--skip-mcp`/`--mcp` | bash 3.2 互換 / PowerShell | Existing (拡張) |
| CI 拡張 | Node テストジョブ + dist 一致検証 | GitHub Actions | Existing (拡張) |

## Layer Specifications

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | N/A — no change: GUI/画面を持たない。MCP クライアントが消費する構造化応答のみ（応答契約は API / Contract Plan が正） | [UX specification](ux-spec.md#scope-and-user-journeys) | ai-implementer | N/A recorded |
| Frontend | N/A — no change: フロントエンド UI なし。ランタイム要件（Node >= 20）のみ記録 | [Frontend specification](frontend-spec.md#technology-stack) | ai-implementer | N/A recorded |
| Infrastructure | ローカル stdio プロセス。installer 配置 + CLI 登録、CI 3 OS マトリクス + dist 一致検証 | [Infrastructure specification](infra-spec.md#deployment-topology) | ai-implementer | Drafted |
| Security | B1 (client→server) / B2 (server→fs) の 2 境界。allowlist/denylist・traversal 拒否・read-only 保証 | [Security specification](security-spec.md#trust-boundaries) | ai-implementer | Drafted |

## Cross-Layer Dependencies

| From | To | Contract / Decision | REQ | AC | Verification |
|---|---|---|---|---|---|
| requirements.md | security-spec.md | allowlist 4 dirs + AGENTS.md、denylist（SDD_SUDO/署名鍵/.env）、fail-closed | REQ-006 | AC-003, AC-004 | TEST-003, TEST-004 |
| requirements.md | infra-spec.md | dist バンドルコミット + Node >= 20 + CI dist 一致検証 | REQ-008, REQ-010 | AC-006, AC-010 | TEST-006, TEST-010 |
| security-spec.md | infra-spec.md | installer は read-only 登録のみ生成（write 系設定を作らない） | REQ-009 | AC-007 | TEST-007 |
| design.md | contracts/sdd-forge-mcp-tools.v1.schema.json | tool 応答エンベロープと各 tool の data 形状 | REQ-002, REQ-003 | AC-013, AC-014 | TEST-013, TEST-014 |

## ADR Change Log

| ADR | Decision | Status | Layer Impact | Supersedes | Date |
|---|---|---|---|---|---|
| ADR-0002 | read-only sdd-forge-mcp を repo 内 mcp/ に置き Evidence 機能を統合する | Accepted | Security, Infra | none | 2026-07-04 |
| ADR-0003 | バンドル済み dist/ をコミットして配布し、installer が MCP 登録まで行う | Accepted | Infra | none | 2026-07-04 |

## Data Plan

Data Entities（すべて既存ファイルの読み取りのみ。新規データストアなし）:

| Entity | Source | Parser |
|---|---|---|
| Active specs | `AGENTS.md` ## Active Spec Directories | agents-md.ts |
| Task state | `specs/<feature>/tasks.md` | tasks.ts（シェル等価） |
| Review tickets | `docs/review-tickets/RT-*.yml` | review-ticket.ts |
| Quality gate reports | `reports/quality-gate/*.md` | quality-report.ts |
| Implementation reports | `reports/implementation/*.md` | quality-report.ts（存在確認中心） |
| Evidence bundles | `specs/<feature>/verification/T-*.evidence.json` | evidence.ts |
| Verification contracts | `specs/<feature>/verification/T-*.contract.json` | evidence.ts |
| Traceability | `specs/<feature>/traceability.md` | traceability.ts |

Existing Data Affected: なし（読み取りのみ）。

Migration Strategy: 不要（新規コンポーネント、既存データ形式の変更なし）。

ファイルサイズ上限: 1 ファイル 2 MiB。超過は `too-large` エラー（quality gate
レポート等の肥大化検知を兼ねる）。

## API / Contract Plan

すべての tool 応答は共通エンベロープに従う（正:
`contracts/sdd-forge-mcp-tools.v1.schema.json`）:

```jsonc
// 成功
{ "ok": true, "data": { /* tool 固有 */ } }
// 失敗（推測禁止の明示）
{ "ok": false, "error": {
    "code": "cannot-parse" | "cannot-determine" | "not-found" | "path-denied"
          | "not-sdd-root" | "too-large" | "invalid-input",
    "message": "人間可読の説明",
    "details": { /* 該当ファイル・行・ルール等 */ } } }
```

主要 tool の data 形状（代表）:

- `get_task_state(feature)` →
  `{ feature, tasksFile, verdict: "pass"|"fail", taskCount,
     tasks: [{ id, approval, approvalAnnotation?, status, risk?,
               requiredWorkflow?, secondApproval?, blockersNonEmpty }],
     failures: [{ taskId?, rule, message }] }`
  — `verdict`/`failures` は `check-task-state.sh` の exit code / 失敗メッセージと
  1:1 対応（AC-001）。
- `list_active_specs()` →
  `{ specs: [{ feature, path, hasApprovedPlannedOrInProgress }] }`
- `get_next_sdd_command(feature?)` →
  `{ phase, nextCommand, rationale }` または `cannot-determine`。
- `evidence_find_missing(feature, taskId)` →
  `{ required: [...], present: [...], missing: [...] }`（Done 遷移要件基準）。

Resources は同 data を `application/json` で返す読み取りビュー
（`sdd://active-specs`、`sdd://spec/{feature}`、`sdd://tasks/{feature}`、
`sdd://review-tickets`、`sdd://quality-reports`）。

契約バージョニング: `v1`。破壊的変更時は `v2` スキーマを追加し ADR を起こす。

## Test Strategy

- **Required Workflow: tdd**（Risk: high）。Red→Green evidence を記録する。
- **ゴールデンテスト（TEST-001）**: 既存 6 spec の tasks.md に対する
  `check-task-state.sh` の exit code + 失敗メッセージと `get_task_state` の
  verdict + failures を突合。POSIX CI ではシェルを実際に実行して比較、
  Windows では記録済みフィクスチャと比較。
- **ユニット**: パーサー（正常系・cannot-parse 系）、path-guard
  （traversal / symlink / denylist）、next-command（フェーズ網羅 fixture）。
- **統合**: MCP クライアント（SDK の InMemory/stdio テストハーネス）経由の
  tools/resources 呼び出し、installer テスト（既存 *.tests.sh / *.tests.ps1
  パターンに追加）。
- **read-only 検証（TEST-011）**: 本体 src/ に fs 書込み API が現れないことの
  静的検査（grep ベース + eslint ルール）と、テスト実行前後のリポジトリ
  スナップショット比較。
- テストランナーは `node:test`（追加依存なし）。型検査は `tsc --noEmit`。

## Security Boundaries

| Trust Boundary | Auth/Authz Mechanism | Data Classification | OWASP Concerns |
|---|---|---|---|
| B1: MCP クライアント → サーバー（stdio） | 同一ユーザーのローカルプロセス。tool 入力は JSON Schema 検証 | internal | Injection（引数経由のパス注入） |
| B2: サーバー → ファイルシステム | path-guard: realpath 化 → allowlist 前方一致 + denylist 拒否、fail-closed | internal / restricted（denylist） | Broken Access Control, Path Traversal |

Detailed controls: [Security specification](security-spec.md#trust-boundaries).

## Deployment / CI Plan

- ビルド: `esbuild src/index.ts --bundle --platform=node --format=esm
  --outfile=dist/index.js`（`npm run build`）。dist/ はコミット対象。
- CI（.github/workflows/test.yml に追加）:
  1. `mcp-tests` ジョブ（3 OS マトリクス）: `npm ci` → `tsc --noEmit` →
     `node --test`。
  2. `dist-parity` ステップ: 再ビルドして `git diff --exit-code dist/`。
  3. 既存 installer テストに MCP 配置/登録ケースを追加。
- installer: `install.sh` / `install.ps1` に `--skip-mcp` / `--mcp <list>` を
  追加。配置は `INSTALL_ROOT/mcp/sdd-forge-mcp/`（dist + package.json のみ）。
  登録は Claude Code: `claude mcp add`（user scope, read-only 1 プロファイル）、
  Codex: config.toml への mcp_servers エントリ追記（実装時に CLI の有無を確認、
  OQ-001）。uninstall は登録解除 → 配置除去の順で best-effort。
- Node >= 20 が無い場合: installer は警告を出して MCP 部分をスキップ
  （プラグイン導入は継続）。

Detailed topology and operations:
[Infrastructure specification](infra-spec.md#deployment-topology).

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| 完全 read-only（REQ-001） | fs 書込み API 不使用 + 静的検証 + スナップショット比較（TEST-011） |
| シェル等価（REQ-005） | 等価パーサー + ゴールデンテスト常設 + cannot-parse フォールバック禁止 |
| allowlist/denylist（REQ-006） | 単一チョークポイント path-guard、realpath 検証、fail-closed |
| 起動時ルート固定（REQ-007） | root.ts が起動時に一度だけ解決・freeze、tool 入力に root パラメータなし |
| dist 配布（REQ-008） | esbuild 単一バンドル + CI dist-parity 検証 |
| bash 3.2 互換（REQ-009） | installer 変更は既存パターン（連想配列不使用）に従う |
| 3 OS CI（REQ-010） | 既存マトリクスに Node ジョブ追加、Windows はフィクスチャ比較 |
| ファイルサイズ上限 2 MiB（REQ-005 / REQ-006, requirements.md Edge Cases + AC-017） | 各読み取りで path-guard がサイズを検査し、2 MiB（Data Plan と同値）超過は `too-large` 構造化エラーを返す。過大入力による資源枯渇（DoS）緩和を兼ね、security-spec.md STRIDE の DoS 行と対応する |

## Assumptions

- `check-task-state.sh` は POSIX CI 上で実行可能（現行 CI と同条件）。
- `claude mcp add` CLI が利用可能（installer が Claude CLI を既に要求している）。
- js-yaml と @modelcontextprotocol/sdk はバンドル可能なライセンス（MIT 系）で
  あり、SBOM は package-lock.json で管理する。

## Open Questions

### OQ-001: Codex への MCP 登録手段

Codex CLI に MCP 登録コマンドが存在するか、`~/.codex/config.toml` への直接
追記が必要かを実装時に確認する。追記方式の場合、既存エントリ保全
（冪等追記・マーカーコメント）を installer に実装する。

Owner: ai-implementer
Blocks Implementation: no（installer タスク内で解決）
Resolution Path: codex CLI `--help` / 公式ドキュメント確認 → 実装レポートに記録

## Risks

- パーサーとシェルの等価性ドリフト（high）→ ゴールデンテスト CI 常設。
  `check-task-state.sh` 側の変更で golden が壊れた場合、MCP 側の追随が必須で
  あることを CONTRIBUTING 系ドキュメントに明記。
- installer の bash 3.2 互換リグレッション → 既存 install.tests.sh に
  ケース追加、macOS CI（bash 3.2 相当）で検証。
- dist コミットのレビュー困難性 → dist-parity CI で改ざん・ビルド漏れを検出。
  dist の手編集は PR レビューで拒否するルールを AGENTS.md Rules に追記。
