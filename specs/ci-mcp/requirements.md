# Requirements: ci-mcp

Spec-Review-Status: Passed

Source Issue: https://github.com/aharada54914/sdd-forge/issues/67

## Overview

承認済み MCP 導入計画の Phase 4。GitHub Actions の workflow run 状態・ジョブログ・
artifacts を **read-only** で取得する MCP サーバー `ci-mcp` を repo 内
`mcp/ci-mcp/` に同梱する(sdd-forge-mcp / local-env-mcp と同型、installer で
選択可・デフォルト同梱)。GitHub の read/write 分離方針(read-only 常時 ON /
write 通常 OFF)と整合させ、re-run / cancel / dispatch 等の write 操作を行う
ツールは一切持たない。依存: Phase 1(#64 local-env-mcp、完了済み)の後。

sdd-forge-mcp(Issue #60)/ local-env-mcp(Issue #64)で確立した技術基盤 —
エラーエンベロープ、esbuild 単一バンドル配布(ADR-0003)、node:test、read-only
静的検査、installer 同梱・冪等登録 — を踏襲する。

公式 `github-mcp-server`(GitHub 提供の汎用 MCP)は Actions を含む広範な
GitHub 機能を write 込みで公開しうる。ci-mcp はその重複ではなく、sdd-forge
ワークフロー向けに **(a) エンベロープ正準化**(sdd-forge-mcp / local-env-mcp と
同一の `Result<T>` 契約)、**(b) read-only 保証**(write ツールを型・静的検査
レベルで排除)、**(c) installer 同梱**(Claude / Codex / Cursor / VS Code への
冪等登録)、を提供する位置付けである。この関係は design.md「Technical Summary」
で明確化する。

## Target Users

- AI コーディングエージェント(Claude Code / Codex / Cursor / VS Code Copilot)。
  CI の失敗原因を推測でなく事実(run 状態・失敗ジョブのログ・artifacts の
  メタデータ)で診断するために使う。
- sdd-forge 利用者(人間)。installer 経由で各クライアントに ci-mcp を登録し、
  IDE のエージェントから CI 状態を参照する。

## Problems

- エージェントが CI の失敗を調べるために `gh` CLI をシェル実行(Bash tool)へ
  フォールバックし、許可プロンプト・トークン露出・ハルシネーションの温床に
  なっている。read-only で構造化された CI 情報源がない。
- 公式 github-mcp-server は汎用で write 操作を含みうるため、read/write 分離
  方針(write 通常 OFF)を機械的に保証しづらい。sdd-forge ワークフロー用に
  read-only を型レベルで保証したエンベロープ正準の情報源が欲しい。

## Goals

- CI 情報の read-only 提供: workflow run 一覧・単一 run の詳細・run 内ジョブ
  一覧・ジョブログ・run の artifacts メタデータを構造化 JSON(エンベロープ
  準拠)で返す。
- write 操作ゼロの安全設計: GitHub への write(re-run / cancel / dispatch /
  delete 等)を行うツールを一切持たず、GitHub API は read 系エンドポイント
  のみを呼ぶ。ローカル FS への書き込みも原則行わない。
- トークンの非漏えい: read-only PAT を環境変数経由でのみ受け取り、値を
  ログ・エラー・応答に一切出さない(スクラビング)。gh CLI 実行による
  トークン取得はしない(exec 回避)。
- 上流(GitHub API)のエラー・rate limit をエラーエンベロープに正規化する。
- installer で選択可能(デフォルト同梱)な配布と、各クライアントへの冪等登録。

## Non-goals

- GitHub への write 操作(re-run / cancel / dispatch / delete / approve /
  comment 等)。read/write 分離方針により提供しない。
- artifact のバイナリ内容をローカルにダウンロード保存する機能(第一案では
  メタデータ列挙のみ。要否は OQ-002 として記録)。
- Actions 以外の GitHub 機能(issues / PR / releases / packages 等)。公式
  github-mcp-server または sdd-forge-mcp の責務であり、ci-mcp は Actions に限定。
- GitHub Enterprise Server(自己ホスト)の独自 API バージョン差異への対応
  (OQ-003 として base URL の設定可否のみ記録)。
- gh CLI 実行によるトークン取得・API 呼び出し(exec 回避、Non-goal)。
- knowledge-mcp / repo-mirror(別 Phase の別 issue)。

## User Stories

- エージェントとして、`list_workflow_runs` で対象リポジトリの直近の run と
  その `conclusion`(success / failure 等)を取得し、CI が緑かどうかを事実で
  判断したい。
- エージェントとして、失敗した run について `list_run_jobs` で失敗ジョブを
  特定し、`get_job_log` でそのログ末尾を取得して、失敗原因を推測でなく
  ログに基づいて診断したい。
- エージェントとして、`list_run_artifacts` で run が生成した artifacts の
  名前・サイズ・有効期限を確認し、証跡バンドルの有無を判断したい。
- sdd-forge 利用者として、installer 一発で各クライアントに ci-mcp を登録し、
  read-only PAT を環境変数で渡すだけで CI 参照を有効化したい。

## Acceptance Criteria

正準の AC 一覧は `acceptance-tests.md` を参照。要旨:

- 5 ツール(`list_workflow_runs` / `get_workflow_run` / `list_run_jobs` /
  `get_job_log` / `list_run_artifacts`)が契約準拠エンベロープで応答する。
- write を行う GitHub API 呼び出し(POST / PATCH / PUT / DELETE)が src に
  存在せず、ツール入力に write を誘発するフィールドが存在しない(静的検査)。
- 応答・ログ・エラーにトークン値・`Authorization` ヘッダ値が現れない
  (canary スクラビング検査)。
- GitHub API の 401/403/404/429 とネットワーク失敗がエラーエンベロープの
  正規コードにマップされる。
- ジョブログはサイズ上限で truncate され、`truncated` フラグが応答に付く。
- installer(sh/ps1)が ci-mcp をデフォルト同梱し、各クライアントへ冪等に
  登録・登録解除できる。

## Requirements

- **REQ-001**: `mcp/ci-mcp/` に TypeScript + `@modelcontextprotocol/sdk`
  (stdio transport)の read-only MCP サーバーを実装する。サーバーは GitHub
  Actions の REST API を read(GET)専用で呼び、ファイルシステムへの書込み API
  を使用せず、ツール応答経路ではファイルシステム読み取りも行わない(唯一の
  外部入力はツール引数と、環境変数経由の read-only トークンおよび対象リポジトリ
  指定)。
- **REQ-002**: ツール 5 種を提供する:
  - `list_workflow_runs`(対象 run の一覧: id / name / status / conclusion /
    branch / event / created/updated 時刻 / run number / html_url。任意の
    絞り込み: branch / status / event / 件数上限)
  - `get_workflow_run`(単一 run の詳細: 上記メタデータ + workflow 名 + 実行
    時間 + commit SHA)
  - `list_run_jobs`(run 内ジョブ一覧: job id / name / status / conclusion /
    開始/終了時刻 / 失敗ステップ番号)
  - `get_job_log`(単一ジョブのプレーンテキストログ。サイズ上限で truncate、
    `truncated` フラグと返却バイト数を付す)
  - `list_run_artifacts`(run の artifacts メタデータ: id / name / サイズ /
    expired フラグ / 有効期限。**内容(バイナリ)は返さない**、第一案)
- **REQ-003**: write 非提供の境界: ci-mcp は GitHub API を GET でのみ呼び、
  POST / PATCH / PUT / DELETE を発行しない。re-run / cancel / dispatch /
  delete / approve / rerun-failed 等の write ツールを一切公開しない。HTTP
  メソッドが GET 固定であること、および `fetch` 呼び出しに write メソッドが
  現れないことを静的検査(テスト)で強制する。ツール入力に write を誘発する
  フィールド(action / method / body 等)を定義しない。
- **REQ-004**: 全ツール応答は sdd-forge-mcp / local-env-mcp と同一構造の
  エラーエンベロープ(`ok`/`data` | `ok`/`error`)に従い、
  `contracts/ci-mcp-tools.v1.schema.json` として契約化する。error code enum は
  既存 7 種(`cannot-parse` / `cannot-determine` / `not-found` / `path-denied` /
  `not-sdd-root` / `too-large` / `invalid-input`)を契約互換のため保持しつつ、
  ci-mcp 固有の上流連携コードとして `upstream-error` / `rate-limited` /
  `auth-missing` の 3 種を追加する(design.md「API / Contract Plan」で定義)。
- **REQ-005**: 認証は read-only トークンを環境変数経由でのみ受け取る。トークン
  変数名の優先順位(design.md で提案、OQ-004 で確定)に従い解決し、未設定時は
  `auth-missing` エラーエンベロープを返す(プロセスは異常終了しない)。トークン
  値・`Authorization` ヘッダ値を応答・stderr ログ・エラー `message`/`details` に
  一切含めない(スクラビング)。gh CLI 実行によるトークン取得は行わない。
- **REQ-006**: 上流エラー・rate limit の正規化(決定的写像): GitHub API の
  401 → 常に `auth-missing`(トークン未設定・無効・失効を区別せず、
  `details.status: 401` を付す。`upstream-error` へは写像しない)。403 →
  レスポンスに rate limit 指標(`x-ratelimit-remaining: 0` ヘッダまたは
  `retry-after` ヘッダ)が存在する場合に限り `rate-limited`、指標がない 403 は
  `upstream-error`(`details.status: 403`。`path-denied` はローカル入力ガード
  専用に予約し、上流 403 には使用しない)。404 → `not-found`、429 →
  `rate-limited`、5xx / ネットワーク失敗 → `upstream-error` にマップする。
  `rate-limited` 応答には(トークンを含まない)リセット時刻等の非機微メタデータ
  を `details` に載せてよい。上流のレスポンス本文をそのまま応答に転載しない。
- **REQ-007**: 対象リポジトリの指定: owner / repo の解決方法(明示引数 vs
  環境変数 vs git remote 由来)を design.md で提案し、OQ-001 で確定する。
  ci-mcp 自身は git 操作(remote 参照)を exec で行わない。解決不能時は
  `invalid-input` を返す。
- **REQ-008**: ジョブログのサイズ制御: `get_job_log` は取得ログを上限
  256 KiB(local-env-mcp の 8 KiB プローブ上限 / 2 MiB クラスの流儀に準拠した
  ログ向け具体値。design.md で根拠提示)で truncate し、末尾優先で保持する
  (失敗診断は末尾が有用なため)。上限超過時は `truncated: true` と
  `returnedBytes` を応答に含め、エンベロープは `ok: true` を保つ。
- **REQ-009**: 配布は ADR-0003 に準拠する: esbuild 単一バンドル
  `mcp/ci-mcp/dist/index.js` をコミットし、CI で dist-parity 検証(src から
  再ビルドしてコミット済み dist と一致)を行う。実行要件は Node.js >= 20 のみ。
- **REQ-010**: installer 拡張(install.sh / install.ps1 パリティ):
  `VALID_MCPS` と既定 `MCP_LIST` に `ci-mcp` を追加(デフォルト同梱)し、
  既存の `--skip-mcp` / `--mcp <list>` 選択、配置(`dist/*` + `package.json`)、
  Claude(`claude mcp add`)/ Codex(config.toml マーカーブロック)/ Cursor
  (`~/.cursor/mcp.json` upsert)/ VS Code(ユーザープロファイル `mcp.json`
  upsert)登録の既存経路で ci-mcp も扱えるようにする。トークン環境変数は
  installer が値を保存せず、登録メッセージで必要な変数名を利用者に案内する。
- **REQ-011**: uninstall(uninstall.sh / uninstall.ps1): 配置済み ci-mcp の
  削除に加え、Claude / Codex / Cursor / VS Code から installer が管理する
  ci-mcp エントリのみを登録解除する(他のユーザー定義エントリは無傷)。
- **REQ-012**: ドキュメント: README / USERGUIDE に ci-mcp の概要・ツール一覧・
  セキュリティ境界(write 機能なし・トークン取り扱い)・read-only PAT の
  必要な環境変数と設定手順・各クライアントの自動/手動登録手順を追記する。
- **REQ-013**: テストは node:test を使用し、sdd-forge-mcp / local-env-mcp と
  同じ `tsconfig.test.json` + `scripts/run-tests.mjs` 方式に従う。GitHub API は
  ローカルのフェイク HTTP サーバー(またはインジェクトした fetch)でスタブし、
  実ネットワークに接続しない。installer 変更は `tests/install.tests.sh` /
  `tests/install.tests.ps1` の既存ハーネスにケースを追加する。

## Roles and Permissions

- 役割分離なし(単一ローカルユーザー)。MCP サーバーは呼び出し元 OS ユーザーの
  権限で動作し、GitHub API へは環境変数で与えられた read-only トークンの権限で
  アクセスする。ci-mcp 自身は認証機構を持たず、OS ユーザー境界とトークンの
  スコープに委譲する。

## Main Workflows

1. エージェントが `list_workflow_runs` を呼ぶ → サーバーは対象 owner/repo を
   解決 → GitHub Actions REST API を GET → run 一覧をエンベロープで返す。
2. 失敗 run について `list_run_jobs` → 失敗ジョブ id を取得 → `get_job_log` で
   ログ末尾(<= 256 KiB、truncated フラグ)を取得 → 原因診断。
3. `list_run_artifacts` で artifacts メタデータ(名前・サイズ・期限)を取得。
4. 利用者が `./install.sh` を実行 → ci-mcp が配置され、Claude / Codex / Cursor
   / VS Code に登録される。read-only PAT の環境変数名が案内される。
5. 利用者が `./uninstall.sh` を実行 → 配置物と ci-mcp 登録エントリが除去される。

## Edge Cases

- トークン環境変数が未設定 → `auth-missing`(プロセスは落とさない)。
- owner/repo が解決できない → `invalid-input`。
- 存在しない run id / job id → GitHub 404 を `not-found` にマップ。
- rate limit 到達(429 または 403 + rate-limit ヘッダ) → `rate-limited`、
  `details` に(非機微の)リセット時刻。
- ジョブログが上限超過 → 末尾優先で 256 KiB に truncate、`truncated: true`。
- artifact が expired → メタデータで `expired: true`(エラーにしない)。
- GitHub API 5xx / ネットワーク断 → `upstream-error`。上流本文は転載しない。
- 空の結果(run 0 件) → `ok: true` で空配列。

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: MCP クライアント ↔ ci-mcp(stdio) | なし(OS ユーザー境界に委譲) | internal(CI メタデータ・ログ) | なし |
| B2: ci-mcp ↔ GitHub Actions REST API(HTTPS, GET 専用) | 環境変数の read-only PAT(値は非漏えい) | internal(run/job/artifact メタデータ、ジョブログ)。上流出力は untrusted data として扱う | GitHub API 利用規約・rate limit |
| B3: installer ↔ IDE 設定ファイル(mcp.json 等) | ユーザー権限での冪等 upsert | internal(設定パス・env 変数名のみ、トークン値は保存しない) | なし |

詳細は `security-spec.md` を参照。

## Assumptions

- 対象は GitHub.com(github.com REST API v3, `api.github.com`)を第一とし、
  GitHub Enterprise Server の base URL 設定可否は OQ-003 に記録する。
- read-only の fine-grained PAT(`github-readonly` 系、Actions: read /
  Contents: read 相当)が利用者側で用意され、環境変数で与えられる(GitHub
  read/write 分離方針の read 側と整合)。
- 実行環境は macOS / Linux / Windows(installer は既存の sh / ps1 二系統)。
- 「read-only」は「GitHub への write を一切行わない + ローカル FS 書込みを
  行わない」ことを指し、この境界と write API 不使用の静的検査を ADR-0006 として
  記録し、人間の承認対象とする。

## Open Questions

### OQ-001: 対象リポジトリ(owner/repo)の指定方法

明示引数(ツール入力の `owner` / `repo`)/ 環境変数(例: `CI_MCP_REPO`)/
git remote 由来のいずれを正準とするか。ci-mcp は exec を避けるため git remote の
直接参照は行わない前提。design.md で「明示引数を必須、環境変数をデフォルトに
できる」案を提示するが、正準の優先順位は製品判断として要確定。

Owner: 実装タスク担当(ツール入力設計タスク) / 承認は人間
Blocks Implementation: partial(ツール入力スキーマ確定に必要。design で暫定案、
実装着手前に確定)
Resolution Path: 製品判断 → design.md「API / Contract Plan」を更新 → 契約反映

### OQ-002: artifact のダウンロード保存の要否

第一案は artifacts の**メタデータ列挙のみ**(内容は返さない)。証跡バンドルの
中身取得(サイズ上限付きで応答内に返す or ローカル保存)が必要かは製品判断。
ローカル保存は read-only(FS 書込みなし)方針と衝突するため、必要なら別 ADR。

Owner: 製品判断(人間)
Blocks Implementation: no(第一案=メタデータのみで REQ-002 は充足。拡張は
後続の contract マイナー変更で対応可)
Resolution Path: 利用実態の確認 → 必要なら新 REQ + 新 ADR + contract v1.1

### OQ-003: GitHub Enterprise Server の base URL 設定可否

`api.github.com` 固定か、環境変数で base URL を差し替え可能にするか。第一案は
github.com 固定(Non-goal)。GHES 対応が要件なら base URL 環境変数を追加する。

Owner: 製品判断(人間)
Blocks Implementation: no(github.com 固定で MVP 成立)
Resolution Path: 需要確認 → 必要なら `CI_MCP_API_BASE_URL` を design に追加

### OQ-004: read-only トークンの環境変数名と優先順位

`GITHUB_TOKEN` を既定にするか、専用変数(例: `CI_MCP_GITHUB_TOKEN` /
`GH_READONLY_TOKEN`)を優先するか。`GITHUB_TOKEN` は他ツールと衝突・意図しない
高権限トークン混入のリスクがあるため、design.md では「専用変数を最優先、
`GITHUB_TOKEN` をフォールバック」案を提示するが、正準の変数名は要確定。

Owner: 製品判断(人間) / GitHub PAT インベントリ方針と整合
Blocks Implementation: partial(認証実装タスクの冒頭で確定)
Resolution Path: 製品判断 → design.md「API / Contract Plan」と security-spec.md を更新

## Risks

- write ツールの誤公開・write API 混入は read/write 分離方針の破綻に直結する。
  → Risk: high。GET 固定と write メソッド不使用の静的検査 + ネガティブテストで防ぐ。
- トークンの応答/ログ漏えいは資格情報流出に直結する。→ Risk: high。canary
  スクラビング検査を必須とする。
- 上流(GitHub API)仕様変更・rate limit 挙動の差異。→ 正規化レイヤーで吸収、
  フェイク HTTP でのエラーパステストを必須とする。
- ジョブログの巨大出力によるメモリ枯渇。→ ストリーミング + 256 KiB 上限
  (末尾優先)で緩和。
