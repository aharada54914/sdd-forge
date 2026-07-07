# Tasks: ci-mcp

Task-Review-Status: Passed

Source: specs/ci-mcp/requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed) / Issue #67

Lifecycle: `Draft -> Approved -> In Progress -> Implementation Complete -> Done`

> Risk 注記: 各タスクの `Risk` tier と `Risk Rationale` は起草エージェントの
> **提案**である。承認(Approval)時に human が確定・変更する。提案のみでゲートは
> 緩和されない(risk-classification-policy.md)。`Required Workflow` は
> risk-gate-matrix.md に従い tier から機械的に導出している(low→test-after /
> medium→acceptance-first / high・critical→tdd)。

## T-001 ci-mcp サーバー基盤(scaffold)+ エンベロープ

Approval: Approved
Status: Implementation Complete
Risk: medium
Risk Rationale: TypeScript プロジェクト基盤(package.json / tsconfig / run-tests)と McpServer/stdio 骨組み・エラーエンベロープの新設。観察可能な挙動を持つ通常の内部ツール実装で、既存 2 MCP パターンの踏襲であり、機微面(write/トークン/上流連携)は後続タスクが担う。
Required Workflow: acceptance-first
Requirements: REQ-001, REQ-004, REQ-013
Rollback: 本タスクのコミットを revert(未リリース段階、後続タスクは Blockers で未着手のため影響なし)。infra-spec.md「Deployment / CI Plan」節参照。

### Goal
mcp/ci-mcp/ の TypeScript プロジェクト基盤(package.json / tsconfig.json /
tsconfig.test.json / scripts/run-tests.mjs)を sdd-forge-mcp / local-env-mcp と
同型で作り、Result エラーエンベロープ(既存 2 MCP と同一構造 `ok`/`data` |
`ok`/`error`。既存 7 種 code enum を保持しつつ ci-mcp 固有の `upstream-error` /
`rate-limited` / `auth-missing` を追加、計 10 種)、および McpServer 構築 +
stdio transport 起動の骨組み(index.ts / server.ts、起動時に GitHub API を
呼ばない = 起動 <= 1 s)を実装する。ツール本体・github-client・auth・
repo-resolve は後続タスクで追加する。

### Scope
- mcp/ci-mcp/{package.json,tsconfig.json,tsconfig.test.json}
- mcp/ci-mcp/scripts/run-tests.mjs
- mcp/ci-mcp/src/{envelope.ts,server.ts,index.ts}
- mcp/ci-mcp/tests/envelope/(エンベロープ構造 + 追加 error code enum の単体)

### Done When
- [ ] エンベロープが既存 2 MCP と同一構造で、追加 3 コード(`upstream-error` / `rate-limited` / `auth-missing`)を含む 10 種 enum を持つ(単体テスト)
- [ ] stdio 起動が成功し、起動時に GitHub API 呼び出し・トークン検証を行わない(起動診断成功)
- [ ] acceptance テスト(エンベロープ契約準拠の検証手順)が実装に先行して記述される
- [ ] ci-mcp の typecheck / 全テストが green
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-001.md)
- [ ] quality gate pass

### Blockers
None

## T-002 github-client(GET 専用)+ error-normalizer(REQ-006 決定的写像)

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: github-client は GitHub への唯一の外向き経路であり、HTTP メソッドが GET 固定でないと read/write 分離方針(REQ-003、B2)が破綻する。owner/repo の URL 組み立ては SSRF 面(security-spec.md OWASP:SSRF、ホスト固定 api.github.com)を持ち、上流エラー正規化の誤りは資格情報・内部情報の漏えい/誤マップ(REQ-006、B2 の Information Disclosure)に直結する。
Required Workflow: tdd
Requirements: REQ-001, REQ-003, REQ-006
Rollback: 本タスクのコミットを revert(T-001 基盤は独立して残置可能)。

### Goal
GET 専用 fetch ラッパ `github-client.ts` を実装する: ホスト固定
(`api.github.com`)、owner/repo を path 要素として URL エンコード(ホスト差し替え
不可)、GET 以外の HTTP メソッドを発行しない。上流エラー正規化 `error-normalizer`
を REQ-006 の決定的写像に従って実装する(401 → `auth-missing`(`details.status:
401`)/ 403 + rate limit 指標(`x-ratelimit-remaining: 0` または `retry-after`)
→ `rate-limited` / 指標なし 403 → `upstream-error`(`details.status: 403`)/
404 → `not-found` / 429 → `rate-limited` / 5xx・ネットワーク失敗 →
`upstream-error`)。上流レスポンス本文は応答に転載せず、正規化 code + 非機微
message + 非機微 details のみを返す。fake HTTP サーバー(または注入 fetch)で
実ネットワークに接続しない。

### Scope
- mcp/ci-mcp/src/github-client.ts(GET 固定 fetch・URL 組み立て・トークンヘッダ付与)
- mcp/ci-mcp/src/error-normalizer.ts(上流 status → error code 写像)
- mcp/ci-mcp/tests/error-paths/(AC-010: 401/403(指標あり・なし)/404/429/5xx/
  ネットワーク失敗の全分岐、上流本文非転載。AC-011: `rate-limited` の非機微 details)

### Done When
- [ ] AC-010: 401/403(指標あり=`rate-limited` / 指標なし=`upstream-error`)/404/429/5xx/ネットワーク失敗が正規 code に決定的に写像され、上流レスポンス本文が応答に転載されない
- [ ] AC-011: `rate-limited` の `details` に(トークンを含まない)リセット時刻等の非機微メタデータのみが載る
- [ ] HTTP メソッドが GET 固定で、ホストが `api.github.com` に固定される(単体で検証)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-002.md)
- [ ] quality gate pass

### Blockers
T-001

## T-003 auth.ts(トークン解決)+ トークンスクラビング + no-secrets 検査

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: 認証は環境変数の read-only PAT を扱い、値の応答/stderr/エラー混入は資格情報流出に直結する(REQ-005、security-spec.md B2 の Information Disclosure、canary スクラビング必須)。トークン未設定時の非異常終了(`auth-missing`)の欠陥は DoS(security-spec.md B2)になる。OQ-004(変数名優先順位)を本タスク冒頭で確定する。
Required Workflow: tdd
Requirements: REQ-005
Rollback: 本タスクのコミットを revert(T-002 までの機能は独立して残置可能)。

### Goal
環境変数からの read-only トークン解決 `auth.ts`(優先順位 `CI_MCP_GITHUB_TOKEN`
→ `GH_READONLY_TOKEN` → `GITHUB_TOKEN`、最初の非空値を使用、OQ-004 の暫定案を
実装冒頭で確定)、`Authorization: Bearer <token>` 付与(値は診断ログ・エラーに
出さない)、トークン未解決時の `auth-missing` エンベロープ返却(プロセス継続)を
実装する。stderr 診断 `diagnostics.ts` は固定フィールド allowlist のみ出力し
(local-env-mcp と同型)、トークン値・`Authorization` ヘッダ値をスクラビングする。
canary トークンを用いた no-secrets 検査で応答・stderr・エラーの非漏えいを検証する。

### Scope
- mcp/ci-mcp/src/auth.ts(トークン解決・優先順位・Bearer 付与)
- mcp/ci-mcp/src/diagnostics.ts(スクラビング付き stderr 診断、local-env-mcp と同型)
- mcp/ci-mcp/tests/auth/(AC-008: トークン未設定で全ツールが `auth-missing`・
  プロセス継続)
- mcp/ci-mcp/tests/no-secrets/(AC-009: canary env 設定下で応答・stderr・エラーに
  canary 値 / `Authorization` 値が不在)

### Done When
- [ ] AC-008: トークン環境変数未設定のとき全ツールが `auth-missing` を返し、プロセスは異常終了しない
- [ ] AC-009: canary トークン設定下で全ツールを呼んでも応答・stderr・エラー message/details に canary 値・`Authorization` ヘッダ値が現れない
- [ ] OQ-004 の解消記録(確定した変数名優先順位)が addendum(reports/implementation/ci-mcp/T-003.md)に記載される
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-003.md)
- [ ] quality gate pass

### Blockers
T-002

## T-004 repo-resolve.ts(owner/repo 解決、exec なし)

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: owner/repo の解決は B2 の SSRF 面(URL path 要素、ホスト差し替え不可)と入力ガード(REQ-007、security-spec.md B1/OWASP:Injection・SSRF)に直結する。exec による git remote 参照を誤って導入すると exec 回避方針(Non-goal、`child_process` 禁止の静的検査対象)が破綻する。OQ-001(指定方法の正準優先順位)を本タスク冒頭で確定する。
Required Workflow: tdd
Requirements: REQ-007
Rollback: 本タスクのコミットを revert(他モジュールは独立して残置可能)。

### Goal
owner/repo の解決 `repo-resolve.ts` を実装する(OQ-001 の暫定案: 各ツールが
`owner` / `repo` を任意引数で受け、未指定時は環境変数 `CI_MCP_REPO`
(`owner/repo` 形式)にフォールバック。両方なければ `invalid-input`)。git remote
参照のための exec を行わない。owner/repo は URL path 要素として扱い、ホストを
差し替えられない形で github-client に渡す。OQ-001 の正準優先順位を実装冒頭で確定する。

### Scope
- mcp/ci-mcp/src/repo-resolve.ts(引数優先・`CI_MCP_REPO` フォールバック・exec なし)
- mcp/ci-mcp/tests/repo-resolve/(AC-012: owner/repo 未指定かつ既定なしで
  `invalid-input`、git remote 参照のための exec を行わない静的+単体)

### Done When
- [ ] AC-012: 対象リポジトリが解決できない(owner/repo 未指定かつ既定なし)場合 `invalid-input` を返し、git remote 参照のための exec を行わない
- [ ] OQ-001 の解消記録(確定した owner/repo 解決の正準優先順位)が addendum(reports/implementation/ci-mcp/T-004.md)に記載される
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-004.md)
- [ ] quality gate pass

### Blockers
T-001

## T-005 tools/actions.ts(run 系 2 ツール)

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: `list_workflow_runs` / `get_workflow_run` の request/response 形は外部クライアント(Claude Code / Codex / Cursor / VS Code)が直接消費する公開 API 契約であり、risk-classification-policy.md の sentinel surface(public API contracts)に該当する。フィールド形状・error code enum の無言の欠陥は全クライアントのパース破綻に直結する。write 境界・トークン・SSRF の機微制御は T-002/T-003/T-004/T-006 が担う。
Required Workflow: tdd
Requirements: REQ-002
Rollback: 本タスクのコミットを revert(他モジュールは独立して残置可能)。

### Goal
`list_workflow_runs` / `get_workflow_run` を `tools/actions.ts` に実装し、
server.ts に登録する。入力は zod(owner?/repo? + read 絞り込みのみ、
action/method/body 系フィールドなし)、出力は design.md「API / Contract Plan」
の kind 別ペイロード。fake GitHub API で正常系を検証する。

### Scope
- mcp/ci-mcp/src/tools/actions.ts(list_workflow_runs / get_workflow_run 実装 +
  zod 入力スキーマ)
- mcp/ci-mcp/src/server.ts(2 ツール登録)
- mcp/ci-mcp/tests/tools/(AC-001〜002: 各ツールの正常系 + 存在しない run の
  `not-found`)

### Done When
- [ ] AC-001: `list_workflow_runs` が対象 run の一覧(id / name / status / conclusion / branch / event / created/updated / run number / html_url)を契約準拠エンベロープ(`ok: true`)で返し、branch / status / event / 件数上限の絞り込み入力を受理する
- [ ] AC-002: `get_workflow_run` が単一 run の詳細(メタデータ + workflow 名 + 実行時間 + commit SHA)を契約準拠エンベロープで返す。存在しない run id は `not-found`
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] ci-mcp の typecheck / 全テストが green
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-005.md)
- [ ] quality gate pass

### Blockers
T-002, T-003, T-004

## T-012 tools/actions.ts(jobs / artifacts 系 2 ツール)

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: `list_run_jobs` / `list_run_artifacts` の request/response 形は外部クライアント(Claude Code / Codex / Cursor / VS Code)が直接消費する公開 API 契約であり、risk-classification-policy.md の sentinel surface(public API contracts)に該当する。フィールド形状・error code enum の無言の欠陥は全クライアントのパース破綻に直結する。write 境界・トークン・SSRF の機微制御は T-002/T-003/T-004/T-006 が担う。
Required Workflow: tdd
Requirements: REQ-002
Rollback: 本タスクのコミットを revert(他モジュールは独立して残置可能)。

### Goal
`list_run_jobs` / `list_run_artifacts` を `tools/actions.ts` に実装し、
server.ts に登録する。入力は zod(owner?/repo? + read 絞り込みのみ、
action/method/body 系フィールドなし)、出力は design.md「API / Contract Plan」
の kind 別ペイロード。`list_run_artifacts` はバイナリ内容を返さずメタデータの
みとし(expired は `expired: true` でエラーにしない)。fake GitHub API で
正常系を検証する。

### Scope
- mcp/ci-mcp/src/tools/actions.ts(list_run_jobs / list_run_artifacts 実装 +
  zod 入力スキーマ)
- mcp/ci-mcp/src/server.ts(2 ツール登録)
- mcp/ci-mcp/tests/tools/(AC-003, AC-005: 各ツールの正常系 + expired
  artifact)

### Done When
- [ ] AC-003: `list_run_jobs` が run 内ジョブ一覧(job id / name / status / conclusion / 開始/終了時刻 / 失敗ステップ番号)を契約準拠エンベロープで返す
- [ ] AC-005: `list_run_artifacts` が run の artifacts メタデータ(id / name / サイズ / expired / 有効期限)を返し、バイナリ内容を含まない。expired な artifact は `expired: true` でエラーにしない
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] ci-mcp の typecheck / 全テストが green
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-012.md)
- [ ] quality gate pass

### Blockers
T-002, T-003, T-004, T-005

## T-013 tools/actions.ts(get_job_log + 256 KiB 末尾優先 truncation)

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: `get_job_log` の request/response 形は外部クライアント(Claude Code / Codex / Cursor / VS Code)が直接消費する公開 API 契約であり、risk-classification-policy.md の sentinel surface(public API contracts)に該当する。フィールド形状・error code enum の無言の欠陥は全クライアントのパース破綻に直結する。加えてジョブログの 256 KiB 末尾優先 truncation の欠陥はログ欠損・応答肥大に直結する。write 境界・トークン・SSRF の機微制御は T-002/T-003/T-004/T-006 が担う。
Required Workflow: tdd
Requirements: REQ-002, REQ-008
Rollback: 本タスクのコミットを revert(他モジュールは独立して残置可能)。

### Goal
`get_job_log` を `tools/actions.ts` に実装し、server.ts に登録する。入力は
zod(owner?/repo? + read 絞り込みのみ、action/method/body 系フィールドなし)、
出力は design.md「API / Contract Plan」の kind 別ペイロード。256 KiB
リングバッファで末尾優先に保持し、上限超過時 `truncated: true` +
`returnedBytes` を付す(いずれもエンベロープ `ok: true`)。fake GitHub API と
大容量ログ fixture で検証する。

### Scope
- mcp/ci-mcp/src/tools/actions.ts(get_job_log 実装 + zod 入力スキーマ)
- mcp/ci-mcp/src/server.ts(1 ツール登録)
- mcp/ci-mcp/tests/tools/(AC-004: 大容量ログ fixture での truncation)

### Done When
- [ ] AC-004: `get_job_log` がジョブのプレーンテキストログを返し、上限 256 KiB 以内は `truncated: false`、超過時は末尾優先で truncate し `truncated: true` + `returnedBytes` を付す。いずれもエンベロープは `ok: true`
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] ci-mcp の typecheck / 全テストが green
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-013.md)
- [ ] quality gate pass

### Blockers
T-002, T-003, T-004, T-012

## T-006 read-only 静的検査 + no-write テスト(write 境界)

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: write ツール/write API の誤公開は read/write 分離方針の破綻に直結する(REQ-003、security-spec.md B1/B2 の Tampering/Elevation of Privilege、OWASP:Broken Access Control)。入力スキーマの write 誘発フィールド不在と、src の write メソッド/exec/fs 書込み/eval 不在の静的検査が唯一の機械的チョークポイント。
Required Workflow: tdd
Requirements: REQ-001, REQ-003
Rollback: 本タスクのコミットを revert(検査追加のみ、機能コードは残置可能)。

### Goal
write 境界を強制する検査を実装する: (a) 入力スキーマ検査 — 5 ツールすべての
入力に write を誘発するフィールド(action / method / body / command 系)が
存在せず、owner/repo と read 絞り込みのみを受理し、不正入力は `invalid-input`。
(b) 静的検査(grep) — src に write を行う GitHub API 呼び出し(fetch の POST /
PATCH / PUT / DELETE)・fs 書込み API(writeFile/appendFile/mkdir/rm 等)・
`child_process`(exec/spawn/execFile)・`eval` が 0 件で、HTTP メソッドが GET
固定であること。

### Scope
- mcp/ci-mcp/tests/no-write/(AC-006: write 誘発フィールド不在・不正入力
  `invalid-input`)
- mcp/ci-mcp/tests/readonly/(AC-007: fetch write メソッド・fs 書込み・
  child_process・eval が 0 件、GET 固定の grep 静的検査)

### Done When
- [ ] AC-006: 5 ツール入力スキーマに write 誘発フィールド(action/method/body/command 系)が存在せず owner/repo + read 絞り込みのみを受理、不正入力は `invalid-input`
- [ ] AC-007: 静的検査が src 全体で fetch の POST/PATCH/PUT/DELETE・fs 書込み API・child_process(exec/spawn/execFile)・eval を 0 件と判定(HTTP メソッド GET 固定)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-006.md)
- [ ] quality gate pass

### Blockers
T-005, T-012, T-013

## T-007 契約 schema(ci-mcp-tools.v1)+ ajv 検証

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: `contracts/ci-mcp-tools.v1.schema.json` は全ツール応答の正準 JSON Schema 契約であり、risk-classification-policy.md の sentinel surface(public API contracts)に該当する。契約の欠陥(誤ったフィールド形状・error code enum の齟齬)は外部クライアントのエラー処理を無言で破綻させる。既存 2 MCP の v1 enum の上位互換拡張として扱う。
Required Workflow: tdd
Requirements: REQ-004
Rollback: 本タスクのコミットを revert。

### Goal
全ツール応答の JSON Schema 契約 `contracts/ci-mcp-tools.v1.schema.json`(v1)を
新設し、既存 2 MCP と同一構造(`ok`/`data` | `ok`/`error`)で、既存 7 種 error
code を保持しつつ追加 3 種(`upstream-error` / `rate-limited` / `auth-missing`)を
含む計 10 種 enum を定義する。5 ツール応答(ok / error 両分岐)が ajv で契約に
適合することを検証する。

### Scope
- contracts/ci-mcp-tools.v1.schema.json(新設)
- mcp/ci-mcp/tests/contract/(AC-013: ok / error 両分岐 + 追加 error code enum の
  ajv 適合)

### Done When
- [ ] AC-013: 全ツール応答が `contracts/ci-mcp-tools.v1.schema.json` に ajv で適合する(ok / error 両分岐、追加した error code enum を含む)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] ci-mcp の typecheck / 全テストが green
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-007.md)
- [ ] quality gate pass

### Blockers
T-005, T-012, T-013

## T-008 esbuild dist + dist-parity CI + Inspector スモーク

Approval: Approved
Status: Implementation Complete
Risk: medium
Risk Rationale: 配布物(dist)と CI 検証・スモークの追加。挙動面は既存 ADR-0003 パターンの踏襲で、欠陥は CI で検出可能(改竄検知は dist-parity 自体が担う)。local-env-mcp T-004 と同型。
Required Workflow: acceptance-first
Requirements: REQ-009
Rollback: 本タスクのコミットを revert(dist と CI ジョブが同一コミットで戻る)。

### Goal
esbuild 単一バンドル `mcp/ci-mcp/dist/index.js` を生成・コミットし、
.github/workflows/test.yml に ci-mcp の typecheck / test / dist-parity ジョブ
(既存 2 MCP と同型、fake GitHub API で実ネットワーク不使用)を追加する。MCP
Inspector CLI スモークで stdio 起動と 5 ツール列挙を検証する。実行要件は
Node.js >= 20。

### Scope
- mcp/ci-mcp/package.json(build スクリプト確定)
- mcp/ci-mcp/dist/index.js(コミット)
- mcp/ci-mcp/tests/smoke/(AC-015: Inspector CLI tools/list に 5 ツール)
- .github/workflows/test.yml(ci-mcp ジョブ追加)

### Done When
- [ ] AC-014: dist-parity(src から esbuild 再ビルドしたバンドルとコミット済み `mcp/ci-mcp/dist/index.js` の一致)が CI で PASS
- [ ] AC-015: Inspector スモークで stdio 起動と 5 ツール(`list_workflow_runs` / `get_workflow_run` / `list_run_jobs` / `get_job_log` / `list_run_artifacts`)が列挙される
- [ ] acceptance テスト(AC-014 / AC-015 の検証手順)が実装に先行して記述される
- [ ] ci-mcp の typecheck / 全テストが CI で green
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-008.md)
- [ ] quality gate pass

### Blockers
T-006, T-007

## T-009 installer 拡張(install.sh / install.ps1 パリティ)

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: installer は Cursor(`~/.cursor/mcp.json`)/ VS Code ユーザープロファイル `mcp.json` / Codex config.toml / Claude 設定を書き換えるデータ変異であり、欠陥はユーザーの既存 MCP 設定の破壊に直結する(REQ-010、security-spec.md B3、local-env-mcp ADR-0005 継承)。トークン値を設定ファイルに書き込む欠陥は資格情報流出(B3 の Information Disclosure)になる。sh/ps1 の挙動差異は片系統のみでの設定破壊 silent defect を招く。
Required Workflow: tdd
Requirements: REQ-010
Rollback: 本タスクのコミットを revert(既存 sdd-forge-mcp / local-env-mcp の配置・登録経路は変更前挙動に戻る)。壊れ JSON フェイルセーフにより設定ファイルの非可逆破壊は発生しない設計。

### Goal
install.sh / install.ps1 の `VALID_MCPS` と既定 `MCP_LIST` に `ci-mcp` を追加し
(デフォルト同梱)、既存の `--skip-mcp` / `--mcp <list>` 選択・配置
(`dist/*` + `package.json`)・Claude(`claude mcp add`)/ Codex(config.toml
マーカーブロック)/ Cursor / VS Code(mcp.json 冪等 upsert)登録の既存経路
(local-env-mcp で複数 MCP に汎化済み)で ci-mcp も扱えるようにする。installer は
トークン値を保存せず、登録メッセージで必要な read-only PAT の環境変数名を案内する。

### Scope
- install.sh(VALID_MCPS / MCP_LIST に ci-mcp 追加、既存 place/register 経路の
  複数 MCP 動作 + トークン変数案内)
- install.ps1(同上のパリティ)
- tests/install.tests.sh(AC-016: 既定同梱 / --mcp 選択 / --skip-mcp / 4 クライアント
  登録 / トークン変数案内)
- tests/install.tests.ps1(AC-017: sh と同一挙動)

### Done When
- [ ] AC-016: install.sh でデフォルトで ci-mcp が配置され Claude/Codex/Cursor/VS Code 登録経路に含まれ、`--mcp sdd-forge-mcp` 指定時は ci-mcp 非配置、`--skip-mcp` で配置・登録なし、登録メッセージが必要なトークン環境変数名を案内する
- [ ] AC-017: install.ps1 が install.sh と同一挙動(既定同梱・選択・各クライアント登録・冪等性・トークン変数案内)を持つ
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-009.md)
- [ ] quality gate pass

### Blockers
T-008

## T-010 uninstall(uninstall.sh / uninstall.ps1): ci-mcp 登録解除 + 配置削除

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: uninstall は削除系操作であり、欠陥はユーザー定義の他 MCP エントリの誤削除(非可逆的なユーザーデータ喪失)に直結する(REQ-011、security-spec.md B3 の誤削除)。「installer 管理エントリのみ削除」の境界を破ると他クライアントのユーザー設定を破壊する。
Required Workflow: tdd
Requirements: REQ-011
Rollback: 本タスクのコミットを revert。誤削除防止は「installer 管理名(ci-mcp)のみ削除」の設計とテストで担保。

### Goal
uninstall.sh / uninstall.ps1 を拡張し、配置済み ci-mcp の削除と、Claude / Codex /
Cursor / VS Code からの installer 管理 ci-mcp エントリのみの登録解除を実装する。
ユーザー定義の他エントリ(および他の管理 MCP)は無傷であること。

### Scope
- uninstall.sh / uninstall.ps1(ci-mcp 配置削除 + 4 クライアント登録解除)
- tests/uninstall.tests.sh / tests/install.tests.ps1(AC-018: ci-mcp のみ除去・
  他エントリ無傷、sh/ps1 両方)

### Done When
- [ ] AC-018: 配置済み ci-mcp が削除され、Claude/Codex/Cursor/VS Code から installer 管理の ci-mcp エントリのみ除去、ユーザー定義の他エントリは無傷(sh/ps1 両方)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-010.md)
- [ ] quality gate pass

### Blockers
T-009

## T-011 ドキュメント(README / USERGUIDE)+ traceability 最終化

Approval: Approved
Status: Planned
Risk: low
Risk Rationale: ドキュメント追記と traceability 表の Status 更新のみで、制御フロー・データ・セキュリティへの影響がない。
Required Workflow: test-after
Requirements: REQ-012
Rollback: 本タスクのコミットを revert。

### Goal
README / USERGUIDE に ci-mcp の概要・5 ツール一覧・セキュリティ境界(write 機能
なし・トークン取り扱い)・read-only PAT の必要な環境変数と設定手順・各クライアント
(Claude / Codex / Cursor / VS Code)の自動/手動登録手順を追記し、traceability.md /
traceability.json の全 AC / TEST の Status を最終化する。

### Scope
- README.md / USERGUIDE.md(ci-mcp 追記)
- specs/ci-mcp/traceability.md(Status 更新)

### Done When
- [ ] AC-019: README / USERGUIDE に ci-mcp の概要・ツール一覧・write 機能なしの境界・トークン取り扱い・read-only PAT の環境変数と設定手順・各クライアント自動/手動登録手順が記載される
- [ ] REQ→AC→TEST→Task チェーン全行の最終化(Verification Status)が addendum(reports/implementation/ci-mcp/T-011.md)に記録される — traceability.md 本体はタスクレビュー済みバイトで凍結(Post-review artifact freeze、WFI-004 に基づく)
- [ ] 実装レポート作成(reports/implementation/ci-mcp-T-011.md)
- [ ] quality gate pass

### Blockers
T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010, T-012, T-013
