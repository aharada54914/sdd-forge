# Implementation Report: T-008

- Task ID: T-008
- Feature: sdd-forge-mcp
- Risk: low
- Required Workflow: test-after

## Target

`USERGUIDE.md` に `sdd-forge-mcp` の導入（デフォルト / `--skip-mcp` / `--mcp`）、
tool 13 種 + resources 5 種の一覧、対象リポジトリの指定（`--root` /
`SDD_FORGE_ROOT` / cwd）、トラブルシュート（stderr ログの読み方・エラーコード・
rollback 手順）、セキュリティ特性を追記する。あわせて `README.md` に1段落、
`infra-spec.md` Observability 表の Runbook 欄の参照先を確定する
（tasks.md T-008 Goal/Scope/Done When、design.md「Architecture」/
「API / Contract Plan」）。

## Summary

- `USERGUIDE.md` に「sdd-forge-mcp（MCP サーバー）」節を新規追加した（既存の
  移転リダイレクト表の直後）。以下を含む:
  - 概要: read-only・書き込みなし・stdio 起動の1段落
  - 導入手順: `install.sh` / `install.ps1` の既定動作（配置先
    `INSTALL_ROOT/mcp/sdd-forge-mcp/`、Claude 登録コマンド
    `claude mcp add sdd-forge-mcp --scope user -- node <INSTALL_ROOT>/mcp/sdd-forge-mcp/dist/index.js`、
    Codex 向け `~/.codex/config.toml` マーカーブロック追記）と、
    `--skip-mcp` / `--mcp sdd-forge-mcp` の効果を表形式で整理。Node >= 20
    要件（不在・バージョン不足時は警告のみでスキップし plugin 本体の
    インストールは継続する）を明記。
  - 対象リポジトリの指定: `--root` > `SDD_FORGE_ROOT` > cwd の優先順位
    （`src/root.ts` の実装順序と一致）。
  - tools 13 種の一覧表（core 8 + evidence 5）: 各 tool 名と一行の用途を
    `mcp/sdd-forge-mcp/src/server.ts` の `description` から転記・要約。
  - resources 5 種の一覧表: URI と対応する tool を `src/resources.ts` の
    JSDoc コメント（`<-> ` 対応表）から転記。
  - セキュリティ特性の1段落: allowlist（`specs/`、`reports/`、
    `docs/review-tickets/`、`docs/workflow-improvements/`、単一ファイル
    `AGENTS.md`）、denylist（sudo フラグファイル・evidence 署名鍵・`.env`、
    symlink 経由でも拒否）、2 MiB 上限、書き込み API なしを
    `src/path-guard.ts` の実装から転記。
  - トラブルシュート: stderr ログの読み方（stdout は JSON-RPC 専用）、
    `Result<T>` の `error.code` 7種（`cannot-parse` /
    `cannot-determine` / `not-found` / `path-denied` / `not-sdd-root` /
    `too-large` / `invalid-input`）を `src/envelope.ts` の型定義に基づき
    一覧化、rollback 手順（`uninstall.sh --mcp sdd-forge-mcp` による登録
    解除 + 配置除去、または該当コミットの revert、次回 install 時の
    `--skip-mcp`）。
- `README.md` の「Getting Started」節末尾に、MCP サーバー同梱と
  `USERGUIDE.md` の該当アンカーへの参照を1段落追加した。
- `specs/sdd-forge-mcp/infra-spec.md` の Observability 表の Runbook セルを、
  「USERGUIDE.md に追記予定（トラブルシュート節、Phase 2 タスク）」から
  `USERGUIDE.md` の実際のアンカー
  (`../../USERGUIDE.md#sdd-forge-mcpmcp-サーバー`) への相対リンクに更新した
  （該当1セルのみ変更、他の行・列は無変更）。

## Files Changed

- `USERGUIDE.md` — 「sdd-forge-mcp（MCP サーバー）」節を新規追加（概要 /
  導入・除外・選択導入 / 対象リポジトリの指定 / tools 13種 / resources 5種 /
  セキュリティ特性 / トラブルシュート）
- `README.md` — 「Getting Started」節に MCP サーバー同梱と USERGUIDE.md
  参照の1段落を追加
- `specs/sdd-forge-mcp/infra-spec.md` — Observability 表の Runbook セルを
  USERGUIDE.md の実アンカーへの参照に更新（1セルのみ）
- `reports/implementation/sdd-forge-mcp-T-008.md` — 本レポート（新規）

`specs/sdd-forge-mcp/tasks.md` は読み取りのみで変更していない。`plugins/`
配下・`mcp/sdd-forge-mcp/src|tests` 等のコードは一切変更していない。

## Tests Added Or Updated

ドキュメントのみの変更のため、自動テストの追加・更新はなし
（Required Workflow: test-after の対象は下記「Regression Tests Run」の
整合性確認で代替）。

## Regression Tests Run

- `mcp/sdd-forge-mcp/src/server.ts` の 13 tool 登録（`server.registerTool`
  呼び出し）を `grep -n 'registerTool('` で数え、USERGUIDE.md の一覧表の
  行数（core 8 + evidence 5 = 13）と一致することを確認した。
- `mcp/sdd-forge-mcp/src/resources.ts` の `server.registerResource` 呼び出し
  5件と、ファイル冒頭 JSDoc の URI コメント（`sdd://active-specs` /
  `sdd://spec/{feature}` / `sdd://tasks/{feature}` / `sdd://review-tickets` /
  `sdd://quality-reports`）が USERGUIDE.md の resources 一覧表と一致する
  ことを目視確認した。
- `mcp/sdd-forge-mcp/src/envelope.ts` の `ErrorCode` union（7種）が
  USERGUIDE.md のエラーコード表の7行と1対1で一致することを確認した。
- `mcp/sdd-forge-mcp/src/path-guard.ts` の `ALLOWLISTED_DIRECTORIES` /
  `ALLOWLISTED_FILES` / `DENYLISTED_BASENAMES` / `MAX_FILE_SIZE_BYTES` が
  USERGUIDE.md のセキュリティ特性の記述（4ディレクトリ + `AGENTS.md`、
  sudo フラグファイル・`.env`・署名鍵、2 MiB）と一致することを確認した
  （`SDD_SUDO` という文字列はドキュメント内では「sudo フラグファイル」に
  言い換え、Bash コマンドラインには含めていない）。
- `install.sh` の `usage()` ヘルプテキストおよび `register_claude_mcp` /
  `register_codex_mcp` 関数の実装（`claude mcp add "$name" --scope user --
  node "$entry_point"`、Codex マーカー `# >>> sdd-forge-mcp ... >>>` /
  `# <<< sdd-forge-mcp <<<`）と USERGUIDE.md の導入節の記載を突き合わせ、
  コマンド文字列・フラグ名（`--skip-mcp`、`--mcp <comma-separated>`）が
  一致することを確認した。
- `install.sh` の `node_version_ok()` の警告文言（Node 不在 / メジャー
  バージョン不足でそれぞれ「MCP server installation was skipped (plugin
  installation continues)」）と USERGUIDE.md の Node 要件の記載が矛盾
  しないことを確認した。
- `uninstall.sh` の `--mcp` / `--skip-mcp-uninstall` オプションと
  `unregister_claude_mcp` / `unregister_codex_mcp` / `remove_mcp_payload`
  の実装を読み、USERGUIDE.md の rollback 手順の記載と整合することを
  確認した。
- `mcp/sdd-forge-mcp/src/root.ts` の `resolveRoot()` の優先順位実装
  （`readCliRootArg` → `SDD_FORGE_ROOT` → `cwd`）が USERGUIDE.md の
  「対象リポジトリの指定」節の記載と一致することを確認した。
- Markdown のリンクアンカー（GitHub 方式のスラッグ化: 全角括弧・空白の
  扱い）については、`infra-spec.md` からの相対参照
  `../../USERGUIDE.md#sdd-forge-mcpmcp-サーバー` を目視で組み立てたのみで、
  GitHub 上でのレンダリング確認（実際のクリック遷移）は未実施
  （Unresolved Items 参照）。

## Specification Differences

なし。tasks.md T-008 の Goal / Scope / Done When の記載範囲内で完結した。

## Unresolved Items

- Markdown アンカーリンク（`USERGUIDE.md#sdd-forge-mcpmcp-サーバー`、
  `README.md#sdd-forge-mcpmcp-サーバー` 相当の見出しテキストからの
  スラッグ生成）は GitHub のレンダリング上で実際にリンクが機能するかを
  ブラウザで未確認。見出し `## sdd-forge-mcp（MCP サーバー）` から
  GitHub 標準のスラッグ化規則（英数字・ハイフン以外を除去、空白をハイフン
  化、小文字化）に基づき手動で組み立てたアンカーのため、レンダリング環境
  によっては微差が生じる可能性がある。quality gate でのリンク動作確認を
  推奨する。

## Quality Gate Focus

- USERGUIDE.md に転記した tool 名・description の要約が
  `mcp/sdd-forge-mcp/src/server.ts` の実装と食い違っていないか（特に
  `get_next_sdd_command` の feature 省略時の自動選択挙動の説明）。
- infra-spec.md の Runbook セル変更が、指示どおり該当1セルのみで他の
  Observability 表の行・列に影響していないか。
- Markdown アンカーリンクの実際のレンダリング確認（Unresolved Items 参照）。

## Working Notes

- 調査: `USERGUIDE.md` は既存内容が「移転しました」というリダイレクト
  ページ（旧セクション → 新ドキュメントの対応表のみ）だったため、指示
  どおりこのファイルに直接新規節を追記する方針とした（`docs/` 配下の
  別ファイルへの分割は行っていない）。
- 調査: `mcp/sdd-forge-mcp/src/server.ts` の13 tool 登録
  （`server.registerTool(...)` 呼び出し）と `src/resources.ts` の5
  resource 登録（`server.registerResource(...)` 呼び出し）を実ファイルから
  直接読み、tool 名・description・resource URI を創作せず転記した。
- 調査: `mcp/sdd-forge-mcp/src/path-guard.ts` を読み、allowlist が
  `specs`、`reports`、`docs/review-tickets`、`docs/workflow-improvements`
  の4ディレクトリと単一ファイル `AGENTS.md` であること、denylist の
  basename セットが `SDD_SUDO`（実行時に `["SDD","SUDO"].join("_")` で
  組み立てられている）と `.env` の2つであり、evidence 署名鍵
  （`~/.sdd/evidence-key`）は realpath 一致による別ロジックで拒否されて
  いることを確認した。ドキュメント内では指示に従い「sudo フラグ
  ファイル」「evidence 署名鍵」という言い換えを使い、Bash コマンドライン
  に該当の環境変数名文字列を含めていない。
- 調査: `install.sh` の `register_claude_mcp` / `register_codex_mcp` /
  `usage()` を読み、Claude 登録コマンドと Codex マーカーブロックの正確な
  文字列、`--skip-mcp` / `--mcp <comma-separated>`（既定値
  `sdd-forge-mcp`）のヘルプテキストをそのまま転記した。
- 調査: `uninstall.sh` の `--mcp` / `--skip-mcp-uninstall` と
  `unregister_claude_mcp` / `unregister_codex_mcp` / `remove_mcp_payload`
  を読み、rollback 手順の記載が実装と一致するようにした。

## Session Handoff

- **Current status**: T-008 完了。USERGUIDE.md への節追加、README.md への
  1段落追加、infra-spec.md Runbook セルの更新、本実装レポートの作成まで
  完了。`specs/sdd-forge-mcp/tasks.md` / `plugins/` / コード（`src/`
  `tests/` installer 本体）は無変更。git commit は未実施（オーケストレー
  ターに委ねる）。
- **Next action**: quality gate によるレビュー。特に Markdown アンカー
  リンクの実際のレンダリング確認を推奨。
- **Unresolved items**: 上記「Unresolved Items」参照
  （アンカーリンクの実地未確認）。
