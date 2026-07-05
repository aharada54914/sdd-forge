# Traceability: ci-mcp

## REQ → 根拠 / Layer Spec

各 REQ の正準レイヤー仕様アンカー(Layer Spec 列)。レイヤー仕様が所有しない
横断要件は `N/A — cross-layer only:` で理由を記す。

| REQ-ID | 根拠 | Layer Spec | 説明 |
|-----|---|---|---|
| REQ-001 | Issue #67 スコープ | security-spec.md#trust-boundaries; infra-spec.md#deployment-topology | read-only CI 情報 MCP(GET 専用・FS 書込みなし) |
| REQ-002 | Issue #67 スコープ | N/A — cross-layer only: ツール仕様は design.md「API / Contract Plan」と contracts/ci-mcp-tools.v1.schema.json が正準 | 5 ツール(run 一覧 / run 詳細 / ジョブ一覧 / ジョブログ / artifacts) |
| REQ-003 | Issue #67 承認済み決定(ADR-0006) | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | write 非提供境界(GET 固定・write ツール/write API なし) |
| REQ-004 | sdd-forge-mcp / local-env-mcp 基盤踏襲 | N/A — cross-layer only: エンベロープ契約は contracts/ci-mcp-tools.v1.schema.json が正準 | エラーエンベロープ + 追加 error code + 契約化 |
| REQ-005 | セキュリティ方針(GitHub read/write 分離) | security-spec.md#secrets-management; security-spec.md#data-classification-and-protection | トークン非漏えい(env のみ・スクラビング・exec なし) |
| REQ-006 | Issue #67 スコープ | security-spec.md#stride-analysis; security-spec.md#trust-boundaries | 上流エラー / rate limit の決定的正規化・本文非転載 |
| REQ-007 | Issue #67 スコープ | security-spec.md#trust-boundaries | owner/repo 解決(引数 / env、exec なし、SSRF ガード) |
| REQ-008 | Issue #67 スコープ | N/A — cross-layer only: ジョブログ上限は design.md「API / Contract Plan」が正準 | ジョブログ 256 KiB 末尾優先 truncate + `truncated` |
| REQ-009 | ADR-0003(Issue #67 前提) | infra-spec.md#deployment-topology; security-spec.md#sbom-and-supply-chain | esbuild 単一バンドル + dist-parity CI |
| REQ-010 | Issue #67 スコープ | infra-spec.md#deployment-topology; security-spec.md#trust-boundaries | installer 同梱・選択・4 クライアント冪等登録 |
| REQ-011 | ADR-0003 の uninstall 対称性 | infra-spec.md#deployment-topology; security-spec.md#trust-boundaries | uninstall 登録解除・配置削除(管理エントリのみ) |
| REQ-012 | Issue #67 スコープ | N/A — cross-layer only: README / USERGUIDE のドキュメント要件でレイヤー仕様の対象外 | README / USERGUIDE 追記 |
| REQ-013 | AGENTS.md 品質規約 | N/A — cross-layer only: テストハーネス方針は design.md「Test Strategy」が正準 | node:test / 既存テストハーネス・fake HTTP 準拠 |

## REQ → ADR

| 関連 ADR | REQ-ID | 決定内容 |
|---|-----|---|
| ADR-0006 | REQ-001, REQ-003, REQ-005, REQ-006 | GitHub Actions を read-only(GET 専用)で提供・write ツールなし・env の read-only PAT のみ・値をスクラビング・上流エラー正規化 |
| ADR-0003 | REQ-009 | esbuild 単一バンドル dist コミット + dist-parity CI + Node >= 20 |
| ADR-0005(local-env-mcp 継承) | REQ-010, REQ-011 | Cursor / VS Code / Codex / Claude への冪等 upsert 登録と管理キー限定の解除・壊れ JSON フェイルセーフ |

## Task → REQ

| Task | REQ-ID | 内容 |
|---|-----|---|
| T-001 | REQ-001, REQ-004, REQ-013 | サーバー基盤(scaffold)・エンベロープ(追加 error code) |
| T-002 | REQ-001, REQ-003, REQ-006 | github-client(GET 専用)+ error-normalizer(決定的写像) |
| T-003 | REQ-005 | auth(トークン解決)+ スクラビング + no-secrets |
| T-004 | REQ-007 | repo-resolve(owner/repo 解決、exec なし) |
| T-005 | REQ-002, REQ-008 | 5 ツール実装 + ジョブログ truncation |
| T-006 | REQ-001, REQ-003 | read-only 静的検査 + no-write テスト(write 境界) |
| T-007 | REQ-004 | 契約 schema(ci-mcp-tools.v1)+ ajv 検証 |
| T-008 | REQ-009 | esbuild dist + dist-parity CI + Inspector スモーク |
| T-009 | REQ-010 | installer 拡張(sh / ps1 パリティ) |
| T-010 | REQ-011 | uninstall 登録解除・配置削除 |
| T-011 | REQ-012 | ドキュメント + traceability 最終化 |

## AC → REQ

| AC-ID | REQ-ID | 検証内容 |
|-----|---|---|
| AC-001 | REQ-002, REQ-004 | list_workflow_runs の契約準拠応答・絞り込み受理 |
| AC-002 | REQ-002, REQ-006 | get_workflow_run の詳細応答・存在しない run で not-found |
| AC-003 | REQ-002 | list_run_jobs のジョブ一覧応答 |
| AC-004 | REQ-002, REQ-008 | get_job_log の 256 KiB truncation + truncated フラグ |
| AC-005 | REQ-002 | list_run_artifacts のメタデータ応答・expired 非エラー |
| AC-006 | REQ-003, REQ-007 | 入力スキーマに write 誘発フィールド不在・不正入力 invalid-input |
| AC-007 | REQ-001, REQ-003 | 静的 read-only / no-write 検査(GET 固定・exec/fs 書込み/eval 0 件) |
| AC-008 | REQ-005 | トークン未設定で auth-missing・プロセス継続 |
| AC-009 | REQ-005 | canary によるトークン・Authorization 値の非漏えい |
| AC-010 | REQ-006 | 上流エラーの決定的写像・本文非転載 |
| AC-011 | REQ-006 | rate-limited の非機微 details のみ |
| AC-012 | REQ-007 | owner/repo 解決不能で invalid-input・exec なし |
| AC-013 | REQ-004 | ajv 契約適合(ok / error 両分岐 + 追加 error code) |
| AC-014 | REQ-009 | dist-parity CI |
| AC-015 | REQ-001, REQ-002 | Inspector スモーク(5 ツール列挙) |
| AC-016 | REQ-010 | install.sh 同梱・選択・skip・4 クライアント登録・トークン変数案内 |
| AC-017 | REQ-010 | install.ps1 パリティ |
| AC-018 | REQ-011 | uninstall 管理 ci-mcp エントリのみ除去・他エントリ無傷 |
| AC-019 | REQ-012 | README / USERGUIDE のドキュメント項目 |

## AC → TEST → Task

| AC-ID | TEST-ID | Task-ID | Test Target |
|-----|---|---|---|
| AC-001 | TEST-001 | T-005 | mcp/ci-mcp/tests/tools/ |
| AC-002 | TEST-002 | T-005 | mcp/ci-mcp/tests/tools/ |
| AC-003 | TEST-003 | T-005 | mcp/ci-mcp/tests/tools/ |
| AC-004 | TEST-004 | T-005 | mcp/ci-mcp/tests/tools/ |
| AC-005 | TEST-005 | T-005 | mcp/ci-mcp/tests/tools/ |
| AC-006 | TEST-006 | T-006 | mcp/ci-mcp/tests/no-write/ |
| AC-007 | TEST-007 | T-006 | mcp/ci-mcp/tests/readonly/ |
| AC-008 | TEST-008 | T-003 | mcp/ci-mcp/tests/auth/ |
| AC-009 | TEST-009 | T-003 | mcp/ci-mcp/tests/no-secrets/ |
| AC-010 | TEST-010 | T-002 | mcp/ci-mcp/tests/error-paths/ |
| AC-011 | TEST-011 | T-002 | mcp/ci-mcp/tests/error-paths/ |
| AC-012 | TEST-012 | T-004 | mcp/ci-mcp/tests/repo-resolve/ |
| AC-013 | TEST-013 | T-007 | mcp/ci-mcp/tests/contract/ |
| AC-014 | TEST-014 | T-008 | .github/workflows/test.yml |
| AC-015 | TEST-015 | T-008 | mcp/ci-mcp/tests/smoke/ |
| AC-016 | TEST-016 | T-009 | tests/install.tests.sh |
| AC-017 | TEST-017 | T-009 | tests/install.tests.ps1 |
| AC-018 | TEST-018 | T-010 | tests/uninstall.tests.sh / tests/install.tests.ps1 |
| AC-019 | TEST-019 | T-011 | README.md / USERGUIDE.md(quality gate レビュー) |
