# Requirements: local-env-mcp

Spec-Review-Status: Passed

Source Issue: https://github.com/aharada54914/sdd-forge/issues/64

## Overview

承認済み MCP 導入計画(2026-07-04)の Phase 1。ローカル開発環境の read-only
情報(ツールチェーンのバージョン、利用可能 CLI、OS 情報)を提供する MCP サーバー
`local-env-mcp` を repo 内 `mcp/local-env-mcp/` に同梱し、installer を拡張して
Cursor / VS Code(Copilot MCP)への MCP 登録(sdd-forge-mcp と local-env-mcp の
両方)を追加する。**実行機能は提供しない**(承認済み決定): 呼び出し側から
コマンドや引数を受け取って実行するツールは一切持たない。

sdd-forge-mcp(Issue #60、QG 11/11 PASS)で確立した技術基盤 — エラーエンベロープ、
esbuild 単一バンドル配布(ADR-0003)、node:test、read-only 静的検査 — を踏襲する。

## Target Users

- AI コーディングエージェント(Claude Code / Codex / Cursor / VS Code Copilot)。
  環境依存の判断(ツールの有無・バージョン)を推測でなく事実で行うために使う。
- sdd-forge 利用者(人間)。installer 経由で Cursor / VS Code に MCP を登録し、
  IDE のエージェントから sdd-forge-mcp / local-env-mcp を利用する。

## Problems

- エージェントが「node のバージョンは?」「pnpm はあるか?」を確かめるために
  シェル実行(Bash tool)へフォールバックし、許可プロンプトやハルシネーションの
  温床になっている。read-only の構造化された環境情報源がない。
- sdd-forge-mcp は Claude Code / Codex にしか登録されず、Cursor / VS Code
  ユーザーは手動設定が必要。

## Goals

- 環境情報の read-only 提供: OS 情報 / ツールチェーンバージョン / CLI 可用性を
  構造化 JSON(エンベロープ準拠)で返す。
- 実行機能ゼロの安全設計: プローブ対象はコンパイル時固定の allowlist のみ。
  ユーザー入力がコマンド・引数に到達する経路を持たない。
- installer で選択可能(デフォルト同梱)な配布と、Cursor / VS Code への冪等な登録。

## Non-goals

- install 実行機能(コマンド実行系ツール)。承認済み決定により見送り、現状維持。
- 環境の変更(インストール・アップデート・設定書換え)。
- 環境変数値の提供(秘密情報を含みうるため、ツールとして提供しない)。
- リポジトリ内ファイルの読み取り(sdd-forge-mcp の責務。local-env-mcp は
  ファイルシステム読み取りを行わない)。
- VS Code Insiders / Cursor nightly 等の派生チャネル対応。
- knowledge-mcp / ci-mcp(Phase 2 以降の別 issue)。

## User Stories

- エージェントとして、`get_toolchain_versions` で node/git/python 等の正確な
  バージョンを取得し、環境依存の実装判断を事実に基づいて行いたい。
- エージェントとして、`list_available_clis` で CLI の有無を確認し、存在しない
  ツールの呼び出しを試行前に回避したい。
- sdd-forge 利用者として、installer 一発で Cursor と VS Code の両方に
  sdd-forge-mcp / local-env-mcp を登録し、手動 JSON 編集を避けたい。

## Acceptance Criteria

正準の AC 一覧は `acceptance-tests.md` を参照。要旨:

- 3 ツール(`get_os_info` / `get_toolchain_versions` / `list_available_clis`)が
  契約準拠エンベロープで応答する。
- ツール入力スキーマにコマンド・引数・パスを受け取るフィールドが存在しない。
- 応答・ログに環境変数値・ユーザー名・ホスト名・ホームパスが現れない。
- installer(sh/ps1)が local-env-mcp をデフォルト同梱し、Cursor / VS Code へ
  冪等に登録・登録解除できる。

## Requirements

- **REQ-001**: `mcp/local-env-mcp/` に TypeScript + `@modelcontextprotocol/sdk`
  (stdio transport)の read-only MCP サーバーを実装する。サーバーは
  ファイルシステムへの書込み API を使用せず、ツール応答経路では
  ファイルシステム読み取りも行わない(環境情報は `os`/`process` API と
  固定プローブのみから得る)。
- **REQ-002**: ツール 3 種を提供する: `get_os_info`(platform / arch / OS type /
  release / CPU 論理コア数 / 総メモリ / Node ランタイムバージョン)、
  `get_toolchain_versions`(固定 allowlist の CLI バージョン一括取得、
  未インストールは per-entry `available: false`)、`list_available_clis`
  (allowlist 各 CLI の可用性)。
- **REQ-003**: 実行機能非提供の境界: プローブ対象(コマンド名・引数)は
  コンパイル時定数の allowlist(node / npm / pnpm / yarn / bun / deno / git /
  gh / python3 / go / rustc / cargo / java / docker)に限定し、`execFile`
  (shell 不使用)でのみ起動する。ツール入力からコマンド・引数・パスへ到達する
  経路を持たない(入力は allowlist 名の enum フィルタのみ許可)。プローブは
  1 件あたりタイムアウト 2 秒・出力上限 8 KiB・並列上限 4 とし、超過時は
  プロセスを kill して per-entry 失敗として報告する。
- **REQ-004**: 全ツール応答は sdd-forge-mcp と同一構造のエラーエンベロープ
  (`ok`/`data` | `ok`/`error`、error code enum: `cannot-parse` /
  `cannot-determine` / `not-found` / `path-denied` / `not-sdd-root` /
  `too-large` / `invalid-input`)に従い、
  `contracts/local-env-mcp-tools.v1.schema.json` として契約化する。
- **REQ-005**: 秘密情報・準個人情報の非漏えい: ツール応答および stderr ログに
  環境変数の値・ユーザー名・ホスト名・ホームディレクトリパス・PATH 全文を
  含めない。バージョン文字列は先頭行のみ・最大 200 文字に正規化する。
- **REQ-006**: 配布は ADR-0003 に準拠する: esbuild 単一バンドル
  `mcp/local-env-mcp/dist/index.js` をコミットし、CI で dist-parity 検証
  (src から再ビルドしてコミット済み dist と一致)を行う。実行要件は
  Node.js >= 20 のみ。
- **REQ-007**: installer 拡張(install.sh / install.ps1 パリティ):
  `VALID_MCPS` と既定 `MCP_LIST` に `local-env-mcp` を追加(デフォルト同梱)し、
  既存の `--skip-mcp` / `--mcp <list>` 選択、配置(`dist/*` + `package.json`)、
  Claude(`claude mcp add`)/ Codex(config.toml マーカーブロック)登録の
  既存経路で local-env-mcp も扱えるようにする。
- **REQ-008**: Cursor 登録: 選択された各 MCP を `~/.cursor/mcp.json` の
  `mcpServers.<name>` へ冪等に upsert する(既存の他エントリは保持、再実行で
  重複しない)。JSON 操作は Node.js(>= 20 が配置ゲートで保証済み)で行う。
  Cursor 未導入(設定ディレクトリ不在)の場合はスキップし通知する。
- **REQ-009**: VS Code(Copilot MCP)登録: 選択された各 MCP を VS Code
  ユーザープロファイルの `mcp.json`(OS 別パス)の `servers.<name>` へ冪等に
  upsert する。既存の他エントリは保持する。VS Code 未導入の場合はスキップし
  通知する。
- **REQ-010**: uninstall(uninstall.sh / uninstall.ps1): 配置済み MCP の削除に
  加え、Claude / Codex / Cursor / VS Code から installer が管理するエントリ
  のみを登録解除する(他のユーザー定義エントリは無傷)。
- **REQ-011**: ドキュメント: README / USERGUIDE に local-env-mcp の概要・
  ツール一覧・セキュリティ境界(実行機能なし)と、Cursor / VS Code の自動登録・
  手動登録手順を追記する。
- **REQ-012**: テストは node:test を使用し、sdd-forge-mcp と同じ
  `tsconfig.test.json` + `scripts/run-tests.mjs` 方式に従う。installer 変更は
  `tests/install.tests.sh` / `tests/install.tests.ps1` の既存ハーネスに
  ケースを追加する。

## Roles and Permissions

- 役割分離なし(単一ローカルユーザー)。MCP サーバーは呼び出し元 OS ユーザーの
  権限で動作し、認証機構を持たない(OS ユーザー境界に委譲)。

## Main Workflows

1. エージェントが MCP 経由で `get_toolchain_versions` を呼ぶ → サーバーは
   allowlist を execFile でプローブ → per-entry の version / available を
   エンベロープで返す。
2. 利用者が `./install.sh` を実行 → local-env-mcp が配置され、Claude / Codex /
   Cursor / VS Code に登録される(存在するクライアントのみ)。
3. 利用者が `./uninstall.sh` を実行 → 配置物と登録エントリが除去される。

## Edge Cases

- allowlist の CLI が未インストール → per-entry `available: false`(エンベロープ
  は `ok: true`)。全体エラーにしない。
- プローブがハング/大量出力 → 2 秒 / 8 KiB で打ち切り kill、per-entry 失敗。
- `java -version` のように stderr へ出力する CLI → stream を問わず先頭行を採用。
- `list_available_clis` に allowlist 外の名前を指定 → `invalid-input`。
- Cursor / VS Code の設定ファイルが存在しない → ディレクトリごと新規作成はせず
  (クライアント未導入とみなし)スキップ・通知。設定ファイルが壊れた JSON →
  上書きせずエラー通知して該当クライアントの登録のみ中断。
- Node < 20 → 既存の MCP 配置ゲート(MCP_NODE_OK)により配置・登録とも行わない。

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: MCP クライアント ↔ local-env-mcp(stdio) | なし(OS ユーザー境界に委譲) | internal(バージョン文字列・OS 情報) | なし |
| B2: local-env-mcp ↔ OS プロセス起動(固定プローブ) | allowlist 固定・shell 不使用 | internal(プローブ出力は untrusted data として扱う) | なし |
| B3: installer ↔ IDE 設定ファイル(mcp.json 等) | ユーザー権限での冪等 upsert | internal(設定パスのみ) | なし |

詳細は `security-spec.md` を参照。

## Assumptions

- Cursor のグローバル MCP 設定は `~/.cursor/mcp.json` の `mcpServers` キー、
  VS Code(Copilot MCP)はユーザープロファイル `mcp.json` の `servers` キー
  である(実装タスク開始時に公式ドキュメントで最新仕様を確認する。OQ-001)。
- 実行環境は macOS / Linux / Windows(installer は既存の sh / ps1 二系統)。
- 「実行機能は持たない」(Issue #64)は「呼び出し側にコマンド実行能力を提供
  しない」ことを指し、コンパイル時固定 allowlist の内部バージョンプローブは
  スコープ内(ツールチェーンバージョン提供に必須)と解釈する。この解釈と
  安全制約は ADR-0004 として記録し、人間の承認対象とする。

## Open Questions

### OQ-001: Cursor / VS Code の MCP 設定ファイルの正確なパスとスキーマ

Cursor `~/.cursor/mcp.json`(`mcpServers`)/ VS Code ユーザープロファイル
`mcp.json`(`servers`、OS 別パス)という想定を、実装タスク着手時に各公式
ドキュメントで確認し、差異があれば design.md と installer 実装に反映する。

Owner: 実装タスク担当(Cursor / VS Code 登録タスク)
Blocks Implementation: no(該当タスクの冒頭で解消)
Resolution Path: 公式ドキュメント確認 → design.md の「API / Contract Plan」を更新

## Risks

- プローブ allowlist 設計の欠陥(入力からコマンドへの経路混入)は任意コマンド
  実行に直結する。→ Risk: high。入力スキーマの静的検査とネガティブテストで防ぐ。
- IDE 設定ファイル(mcp.json)の破壊はユーザーの他 MCP 設定を失わせる。→
  冪等 upsert・他エントリ保持のテストを必須とする。
- PATH 上の偽装バイナリ(プローブ先の乗っ取り)はクライアント環境由来の脅威で、
  local-env-mcp は出力を untrusted data として扱い実行・評価しない(STRIDE 参照)。
