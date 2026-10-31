# Requirements: sdd-forge-mcp

Spec-Review-Status: Passed

Source Issue: https://github.com/aharada54914/sdd-forge/issues/60

## Overview

sdd-forge の状態（active specs、tasks.md の状態機械、review tickets、quality gate
結果、evidence bundle）を構造化して返す**完全 read-only** の MCP サーバー
`sdd-forge-mcp` を `mcp/sdd-forge-mcp/`（TypeScript + @modelcontextprotocol/sdk,
stdio transport）として追加する。Evidence 確認機能は独立サーバーにせず本サーバー
へ統合する（Issue #60 決定済み事項 1）。

## Target Users

- AI クライアント（Claude Code / Codex / Cursor / VS Code）が MCP 経由で SDD 状態を
  構造化取得する。
- 人間の開発者（sdd-forge 運用者）が installer 経由で導入・削除する。

## Problems

- AI クライアントが SDD 状態を読む手段がなく、毎回ファイルを個別に読ませる必要がある。
- 状態確認・品質判断の前処理が手動で、tasks.md 状態機械の誤読リスクがある。
- evidence bundle / quality gate 結果の突合が非構造化で、判断の入力源として不安定。

## Goals

- **REQ-001**: `mcp/sdd-forge-mcp/` に TypeScript + `@modelcontextprotocol/sdk`
  （stdio transport）の read-only MCP サーバーを実装する。サーバーはいかなる
  ファイル書き込み・状態変更も行わない（fs の書込み系 API を使用しない）。
- **REQ-002**: Core tools 8 種を提供する: `list_active_specs` /
  `get_spec_status` / `get_task_state` / `list_approved_tasks` /
  `list_blocked_tasks` / `list_review_tickets` / `get_quality_gate_summary` /
  `get_next_sdd_command`。
- **REQ-003**: Evidence tools 5 種を提供する: `evidence_get_bundle` /
  `evidence_validate_paths` / `evidence_find_missing` /
  `evidence_summarize_contract_checks` / `evidence_compare_to_traceability`。
- **REQ-004**: Resources 5 種を提供する: `sdd://active-specs`、
  `sdd://spec/{feature}`、`sdd://tasks/{feature}`、`sdd://review-tickets`、
  `sdd://quality-reports`。
- **REQ-005**: tasks.md のパースは
  `plugins/sdd-quality-loop/scripts/check-task-state.sh` の判定と**シェル等価**
  であること。既存 6 spec（specs/ 配下全ディレクトリ）に対する
  `get_task_state` の結果がシェル判定と完全一致するゴールデンテストを備える。
  パース不能・判定不一致の入力には `cannot-parse` を返し、内容を推測しない。
- **REQ-006**: パスセキュリティ: 読み取りはプロジェクトルート配下の allowlist
  （`specs/`、`reports/`、`docs/review-tickets/`、`docs/workflow-improvements/`、
  および単一ファイル `AGENTS.md`）に限定する。path traversal（`..`、絶対パス、
  allowlist 外へ解決される symlink）を拒否する。denylist として `SDD_SUDO`
  フラグファイル、evidence 署名鍵（環境変数 `SDD_EVIDENCE_KEY` /
  `SDD_EVIDENCE_KEY_FILE`、`~/.sdd/evidence-key`）、`.env` を読まない・値を
  応答に含めない。
- **REQ-007**: 対象プロジェクトルートは起動時に固定する。優先順位:
  CLI 引数 `--root <path>` > 環境変数 `SDD_FORGE_ROOT` > プロセス cwd。
  起動後（tool 呼び出し中）のルート変更手段を提供しない。
- **REQ-008**: 配布はバンドル済み成果物方式とする。依存を単一 JS
  （`dist/index.js`）にバンドルしてリポジトリにコミットし、実行は
  Node.js >= 20 のみを要求する（利用時の `npm install` 不要）。CI で
  `src/` から再ビルドした結果と コミット済み `dist/` の一致を検証する。
- **REQ-009**: installer 統合: `install.sh` / `install.ps1` はデフォルトで
  MCP サーバーを配置し、Claude Code / Codex への MCP 登録（read-only
  プロファイル）まで自動で行う。`--skip-mcp` で配置・登録を除外、
  `--mcp <list>` で対象 MCP を選択導入できる。`uninstall.sh` / `uninstall.ps1`
  は配置ファイル除去と登録解除を行う。シェルスクリプトは bash 3.2 互換を保つ。
- **REQ-010**: CI: 既存 3 OS マトリクス（windows-latest / macos-latest /
  ubuntu-latest）に Node ベースのテストジョブを追加し、windows-latest で
  パーサー・パス処理テストが通過する。REQ-008 の dist 一致検証も CI で行う。
- **REQ-011**: `get_next_sdd_command` は AGENTS.md の Required Workflow
  フェーズ定義と sdd-ship の自動選択規則（Active Spec Directories +
  Approval/Status 条件）に整合する決定論マッピングで次コマンドを返す。
  判定不能な状態では `cannot-determine` と理由を返し、推測しない。

## Non-goals

- knowledge-mcp / local-env-mcp（別 feature）。
- 書込み系 tool 一切（Approval 変更 / SDD_SUDO / tasks.md 遷移は対象外）。
- Cursor / VS Code への接続作業（別タスク）。
- CI artifacts 取得（gh 連携は後続）。
- npm レジストリへの publish（リポジトリ内配布のみ）。
- evidence 署名の検証実行（署名鍵は読まない。署名検証は
  `check-evidence-bundle.sh` の責務のまま）。

## User Stories

- AI クライアントとして、`list_active_specs` で承認済み・進行中のタスクを持つ
  feature を一覧し、次に実装すべき対象を即座に特定したい。
- AI クライアントとして、`get_task_state` で tasks.md の状態機械判定を
  構造化 JSON で受け取り、シェルスクリプトの出力パースを不要にしたい。
- AI クライアントとして、`evidence_find_missing` で Done 遷移に不足している
  evidence 成果物を列挙し、quality-gate 前の準備を自動化したい。
- 運用者として、`install.sh` 一発で MCP が配置・登録され、`--skip-mcp` で
  除外できるようにしたい。

## Acceptance Criteria

`acceptance-tests.md` の AC-NNN を参照。

- AC-001: 既存 6 spec に対し `get_task_state` が `check-task-state.sh` の判定と
  完全一致する（ゴールデンテスト）
- AC-002: パース不能な tasks.md に対し `cannot-parse` を返し、推測値を返さない
- AC-003: path traversal（`..` / 絶対パス / allowlist 外へ解決される symlink）が
  拒否される
- AC-004: allowlist 外（`plugins/`、`.git/` 等）が読めず、denylist
  （SDD_SUDO・署名鍵・.env）は応答に一切含まれない
- AC-005: MCP Inspector での smoke が macOS で通過する
- AC-006: GitHub Actions windows-latest でパーサー・パス処理テストが通過する
- AC-007: デフォルト install で MCP が配置・登録され、`--skip-mcp` で配置も
  登録もされない
- AC-008: `--mcp <list>` で指定 MCP のみ導入される
- AC-009: uninstall で配置ファイルが除去され登録が解除される
- AC-010: CI で `dist/` と `src/` の一致（再ビルド同一性）が検証される
- AC-011: サーバーに書込みコードパスが存在しない（静的検証）かつ実行中に
  リポジトリのファイルが変更されない
- AC-012: `get_next_sdd_command` が AGENTS.md フェーズ定義・sdd-ship 選択規則と
  整合した結果を返す
- AC-013: Resources 5 種が対応ファイル群の内容を正しく返す
- AC-014: evidence tools が evidence bundle / contract の実ファイル構造
  （`T-NNN.evidence.json` / `T-NNN.contract.json`）を正しく解釈し、
  traceability.md との突合結果を返す
- AC-015: 8 core tools すべてが fixture リポジトリに対し契約スキーマ準拠の
  応答を返し、tool ごとの主要フィールドが期待値と一致する
- AC-016: root 不変性 — tool 入力スキーマに root 相当の引数が存在せず、
  起動後の SDD_FORGE_ROOT / cwd 変更が応答の対象 root に影響しない
- AC-017: 名前付きエラーパス（tasks.md 欠落→`not-found`、SDD 構造なし root→
  `not-sdd-root`、サイズ上限超過→`too-large`）が構造化エラーで返る

## Roles and Permissions

| Role | できること | できないこと |
|---|---|---|
| MCP クライアント（AI エージェント） | allowlist 内の SDD 状態の構造化読み取り | 一切の書込み・denylist 読取・ルート変更 |
| 運用者（人間） | install/uninstall、`--root`/`SDD_FORGE_ROOT` 指定 | —（フル権限はサーバー外の責務） |

## Main Workflows

1. **状態確認**: クライアント → `list_active_specs` → `get_spec_status` →
   `get_task_state` → 状態機械判定を取得。
2. **次コマンド決定**: クライアント → `get_next_sdd_command` →
   フェーズ・タスク状態に基づく次の SDD コマンド文字列を取得。
3. **evidence 突合**: クライアント → `evidence_get_bundle` →
   `evidence_find_missing` / `evidence_compare_to_traceability` → 不足一覧取得。
4. **導入**: 運用者 → `install.sh`（デフォルト）→ 配置 + Claude/Codex 登録 →
   MCP Inspector / クライアントから接続確認。

## Edge Cases

- tasks.md が存在しない feature → 構造化エラー（`not-found`）を返す。
- tasks.md に重複タスク ID / 不正な Status 値 → `cannot-parse` +
  該当行情報を返す（シェル判定の FAIL と整合）。
- AGENTS.md に Active Spec Directories セクションがない → `cannot-determine`。
- 巨大ファイル / バイナリ混入 → サイズ上限（2 MiB、design.md Data Plan と同値）
  超過を `too-large` 構造化エラーで返す。
- ルートが SDD 構造を持たない（specs/ 不在）→ 起動は成功し、tool 呼び出しで
  `not-sdd-root` エラーを返す。
- Windows パス（バックスラッシュ・ドライブレター）での allowlist 判定が
  POSIX と同じ結果になる。

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: MCP クライアント → サーバー（stdio） | ローカル同一ユーザーのプロセス間。認証なし（stdio 前提）。tool 入力はスキーマ検証 | リポジトリ内容（internal） | なし |
| B2: サーバー → ファイルシステム | allowlist + denylist + path traversal 拒否（fail-closed） | SDD_SUDO・署名鍵は restricted（読取禁止） | なし |

詳細は security-spec.md を参照。

## Assumptions

- 利用環境に Node.js >= 20 が存在する（installer は存在チェックのみ行い、
  インストールはしない）。
- 対象リポジトリは sdd-forge の SDD 構造（AGENTS.md、specs/ 等）を持つ。
- stdio transport のみ（HTTP/SSE は提供しない）。ネットワーク送信は行わない。
- `check-task-state.sh` の判定仕様が等価性の正であり、本サーバーは仕様の
  写しであって置き換えではない。

## Open Questions

- OQ-R1（owner: human, non-blocking）: 将来 `--mcp <list>` の対象が増えた場合の
  リスト名規約（`sdd-forge-mcp` を正式名とする前提でよいか）。
  → tasks.md 承認時に確認。

## Risks

- **high**: 本サーバーの出力は quality gate 判断の入力源になるため、
  パーサーの誤判定は品質ゲートの誤通過につながる。→ Required Workflow: tdd、
  シェル等価ゴールデンテスト必須（REQ-005 / AC-001）。
- パーサーとシェルスクリプトの二重管理によるドリフト。→ ゴールデンテストを
  CI 常設し、`check-task-state.sh` 変更時に検出する。
- リポジトリ初の Node/TypeScript 基盤導入による CI 複雑化。→ dist バンドル
  コミット方式で利用側の依存を Node ランタイムのみに限定（REQ-008）。
