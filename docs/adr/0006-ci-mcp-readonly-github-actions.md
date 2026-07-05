# ADR-0006 ci-mcp は GitHub Actions を read-only(GET 専用)で提供し write 機能を持たない

## Status

Proposed(人間承認待ち — セキュリティ境界・資格情報取り扱いに関わる決定)

## Context

Issue #67(承認済み MCP 導入計画 Phase 4)は「GitHub Actions の run 状態・
ジョブログ・artifacts を read-only で取得する MCP ツール群」を要求し、GitHub
MCP の read/write 分離方針(read-only 常時 ON / write 通常 OFF)との整合を求める。
論点は 4 つ:

1. **配置**: repo 内 `mcp/ci-mcp/` 同梱か、独立配布か。
2. **read-only の徹底**: GitHub への write(re-run / cancel / dispatch 等)と
   ローカル FS 書込みをどう構造的に排除するか。artifacts の扱い。
3. **認証**: read-only PAT の受領方法とトークンの非漏えい。
4. **公式 github-mcp-server との関係**: 重複を避け、どこで差別化するか。

GitHub には公式の汎用 `github-mcp-server` が存在し、Actions を含む広域を
write 込みで公開しうる。sdd-forge ワークフローでは read/write 分離を機械的に
保証したい。

## Decision

1. **配置**: repo 内 `mcp/ci-mcp/` に sdd-forge-mcp / local-env-mcp と同型で
   同梱する(installer で選択可・デフォルト同梱)。既存の 3 点(エンベロープ
   契約・esbuild 単一バンドル配布 ADR-0003・4 クライアント冪等登録 ADR-0005)を
   再利用でき、read-only 保証を自リポジトリのテスト/CI で担保できるため。
   **独立配布を却下**: 別リポジトリ化は installer 同梱・dist-parity・
   エンベロープ正準の共有を失い、read/write 分離の機械的保証と保守効率が
   下がる。将来スコープが Actions を大きく越える場合に再検討する。

2. **read-only の徹底**:
   - GitHub API は **GET でのみ**呼び、POST / PATCH / PUT / DELETE を発行しない。
     re-run / cancel / dispatch / delete / approve 等の write ツールを公開しない。
   - ツール入力に write を誘発するフィールド(action / method / body)を定義
     しない。
   - `fetch` の write メソッド・`child_process`(exec/spawn/execFile)・fs 書込み
     API・`eval` の不使用を静的検査(テスト)で強制する。
   - **artifacts はメタデータ列挙を基本**とし、バイナリ内容取得やローカル保存は
     第一版で行わない(ローカル保存は FS 書込みなし方針と衝突)。中身取得の
     要否は Open Question(design.md OQ-002)とし、必要なら別 ADR + contract
     マイナー変更で扱う。

3. **認証**:
   - read-only トークンを **環境変数経由でのみ**受領する(優先順位は design.md
     OQ-004、暫定 `CI_MCP_GITHUB_TOKEN` → `GH_READONLY_TOKEN` → `GITHUB_TOKEN`)。
     GitHub の read-only fine-grained PAT(read/write 分離の read 側)を想定。
   - トークン値・`Authorization` ヘッダ値を応答・stderr ログ・エラーに一切
     出さない(スクラビング)。gh CLI 実行によるトークン取得はしない(exec 回避)。
   - トークン未設定はツール呼び出し時に `auth-missing` エンベロープで返し、
     プロセスを落とさない。
   - 上流(GitHub API)の 401/403/404/429/5xx とネットワーク失敗を、エラー
     エンベロープの正規コード(`auth-missing` / `path-denied` / `rate-limited` /
     `not-found` / `upstream-error`)にマップし、上流レスポンス本文を応答に
     転載しない。

4. **公式 github-mcp-server との関係**: ci-mcp は公式サーバーの置換・重複では
   なく、sdd-forge ワークフロー向けに **(a) エンベロープ正準化**(既存 2 MCP と
   同一の `Result<T>` 契約)、**(b) read-only 保証**(write を型・静的検査で排除)、
   **(c) installer 同梱**(4 クライアント冪等登録)、の 3 点で差別化した狭スコープ
   (Actions read のみ)の情報源とする。公式サーバーの併用を妨げない。

## Consequences

- write 系の要求(re-run 等)が将来必要になっても、本サーバーの拡張ではなく
  read/write 分離方針に沿った別経路(write 通常 OFF の別コンポーネント/設定)で
  設計することになり、本 ADR の supersede が必要になる。
- artifacts の中身取得が必要になった場合、read-only(FS 書込みなし)を保つには
  「応答内にサイズ上限付きで返す」方式を新 ADR で定義する必要がある(OQ-002)。
- 第一版は `api.github.com` にホスト固定するため、GitHub Enterprise Server では
  利用できない。GHES 対応(OQ-003)は base URL の allowlist / 形式検証を伴う
  追加設計を要する(SSRF 面)。
- トークンの権限は利用者が用意する PAT のスコープに依存する。ci-mcp は read
  操作のみ行うため、write 権限付きトークンを渡されても write は発生しないが、
  最小権限(read-only PAT)の利用を README / USERGUIDE で推奨する。
- Codex の TOML マーカー方式、Cursor / VS Code の JSON upsert 方式(ADR-0005)、
  Claude の CLI 方式を ci-mcp でもそのまま再利用でき、登録経路の追加コストは
  名前追加のみに留まる。
