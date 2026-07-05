# Tasks: local-env-mcp

Task-Review-Status: Pending

Source: specs/local-env-mcp/requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed) / Issue #64

Lifecycle: `Draft -> Approved -> In Progress -> Implementation Complete -> Done`

## T-001 local-env-mcp 基盤 + probe-engine + エラーエンベロープ

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: probe-engine と allowlist は「実行機能を提供しない」境界(ADR-0004、REQ-003)の唯一のチョークポイントであり、欠陥は任意コマンド実行・リソース枯渇(DoS)に直結する(security-spec.md B2)。
Required Workflow: tdd
Requirements: REQ-001, REQ-003, REQ-012
Rollback: 本タスクのコミットを revert(未リリース段階、後続タスクは Blockers で未着手のため影響なし)。infra-spec.md「Rollback」節参照。

### Goal
mcp/local-env-mcp/ の TypeScript プロジェクト基盤(package.json / tsconfig /
tsconfig.test.json / run-tests.mjs)を sdd-forge-mcp と同型で作り、エラー
エンベロープ(sdd-forge-mcp と同一構造・同一 code enum)、コンパイル時定数の
probe allowlist(14 CLI、command/args/versionStream)、probe-engine
(execFile shell なし、タイムアウト 2 秒、出力上限 8 KiB、並列上限 4、
kill 保証、先頭行 200 文字正規化、TTL 60 秒キャッシュ)を実装する。

### Scope
- mcp/local-env-mcp/{package.json,tsconfig.json,tsconfig.test.json}
- mcp/local-env-mcp/src/{envelope.ts,allowlist.ts,probe-engine.ts}
- mcp/local-env-mcp/scripts/run-tests.mjs
- mcp/local-env-mcp/tests/error-paths/(AC-004: フェイク slow/verbose CLI
  フィクスチャで timeout / 出力上限 / kill)
- mcp/local-env-mcp/tests/readonly/(AC-006: fs 書込み API・exec・
  spawn(shell)・eval 不在の静的検査)

### Done When
- [ ] AC-004: タイムアウト(2s)超過・出力(8 KiB)超過でプロセス kill、per-entry 失敗報告、応答は契約準拠
- [ ] AC-006: 静的検査が src 全体で fs 書込み API / child_process.exec / spawn(shell) / eval を 0 件と判定
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-001.md)
- [ ] quality gate pass

### Blockers
None

## T-002 MCP ツール 3 種 + server/index + 契約・no-secrets 検証

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: ツール入力スキーマは B1 境界(REQ-003: コマンド/引数/パス系フィールド非提供、enum のみ)そのものであり、欠陥は injection 経路と秘密情報漏えい(REQ-005)に直結する(security-spec.md B1/B2)。
Required Workflow: tdd
Requirements: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005
Rollback: 本タスクのコミットを revert(T-001 基盤は独立して残置可能)。

### Goal
`get_os_info` / `get_toolchain_versions` / `list_available_clis` の 3 ツールと
server.ts / index.ts(stdio 起動、起動時プローブなし)を実装し、
contracts/local-env-mcp-tools.v1.schema.json への契約準拠(ajv)、
no-secrets(canary)検査、MCP Inspector スモークまでを green にする。

### Scope
- mcp/local-env-mcp/src/{server.ts,index.ts,tools/env.ts}
- mcp/local-env-mcp/tests/tools/(AC-001 snapshot + ajv、AC-002 integration)
- mcp/local-env-mcp/tests/no-exec/(AC-003: allowlist 外 name / 追加プロパティ /
  パス文字列 → invalid-input、入力スキーマにコマンド系フィールド不在)
- mcp/local-env-mcp/tests/no-secrets/(AC-005: canary env・HOME・ユーザー名・
  ホスト名・PATH 全文の不在検査)
- mcp/local-env-mcp/tests/smoke/(AC-007: Inspector CLI tools/list)

### Done When
- [ ] AC-001: get_os_info が契約準拠エンベロープで全フィールドを返す
- [ ] AC-002: get_toolchain_versions が per-entry available/version を返し全体 ok
- [ ] AC-003: allowlist 外入力が invalid-input、スキーマにコマンド系フィールド不在
- [ ] AC-005: canary 検査で応答・stderr に秘密情報・準 PII が不在
- [ ] AC-007: Inspector スモークで 3 ツールが列挙される
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-002.md)
- [ ] quality gate pass

### Blockers
T-001

## T-003 esbuild バンドル + dist コミット + CI(test.yml)dist-parity

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: 配布物(dist)と CI 検証の追加。挙動面は既存 ADR-0003 パターンの踏襲で、欠陥は CI で検出可能(改竄検知は dist-parity 自体が担う)。
Required Workflow: acceptance-first
Requirements: REQ-006, REQ-012
Rollback: 本タスクのコミットを revert(dist と CI ジョブが同一コミットで戻る)。

### Goal
esbuild 単一バンドル `mcp/local-env-mcp/dist/index.js` を生成・コミットし、
.github/workflows/test.yml に local-env-mcp の typecheck / test / dist-parity
ジョブ(sdd-forge-mcp と同型)を追加する。

### Scope
- mcp/local-env-mcp/package.json(build スクリプト確定)
- mcp/local-env-mcp/dist/index.js(コミット)
- .github/workflows/test.yml(local-env-mcp ジョブ追加)

### Done When
- [ ] AC-008: CI の dist-parity(src 再ビルド → コミット済み dist と diff 一致)が PASS
- [ ] local-env-mcp の typecheck / 全テストが CI で green
- [ ] acceptance テスト(AC-008 相当の検証手順)が実装に先行して記述される
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-003.md)
- [ ] quality gate pass

### Blockers
T-002

## T-004 installer(install.sh)拡張: local-env-mcp 同梱 + Cursor / VS Code 登録

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: ユーザーの IDE 設定ファイル(~/.cursor/mcp.json、VS Code user-profile mcp.json)を書き換えるデータ変異であり、欠陥はユーザーの既存 MCP 設定の破壊に直結する(REQ-008/REQ-009、security-spec.md B3、ADR-0005)。
Required Workflow: tdd
Requirements: REQ-007, REQ-008, REQ-009
Rollback: 本タスクのコミットを revert。登録済みエントリは uninstall.sh(T-006)または手動でキー削除。壊れ JSON フェイルセーフにより設定ファイルの非可逆破壊は発生しない設計。

### Goal
タスク冒頭で OQ-001(Cursor / VS Code の設定パス・スキーマ)を公式ドキュメント
で確定し design.md を更新した上で、install.sh を拡張する: VALID_MCPS /
MCP_LIST に local-env-mcp を追加(デフォルト同梱、--mcp / --skip-mcp 尊重)、
Cursor(mcpServers キー)/ VS Code(servers キー、OS 別パス)への冪等 JSON
upsert 登録(Node ワンライナー、他エントリ保持、壊れ JSON は不変更 + エラー
通知、クライアント未導入はスキップ通知)。

### Scope
- install.sh(VALID_MCPS / MCP_LIST / register_cursor_mcp / register_vscode_mcp)
- specs/local-env-mcp/design.md(OQ-001 解消の登録形式確定を反映)
- tests/install.tests.sh(AC-009 / AC-010 / AC-011 / AC-015 の HOME 隔離ケース)

### Done When
- [ ] OQ-001 解消: 公式ドキュメント確認結果が design.md「API / Contract Plan」に反映される
- [ ] AC-009: デフォルト同梱 / --mcp 選択 / --skip-mcp の 3 挙動が green
- [ ] AC-010: Cursor 登録が他エントリ保持・再実行冪等・未導入スキップ通知
- [ ] AC-011: VS Code 登録が他エントリ保持・再実行冪等・未導入スキップ通知
- [ ] AC-015: 壊れ JSON で不変更 + エラー通知 + 他クライアント継続
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-004.md)
- [ ] quality gate pass

### Blockers
T-003

## T-005 installer(install.ps1)パリティ

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: T-004 と同一の IDE 設定ファイル変異面を Windows/PowerShell 経路で持つ(REQ-007〜REQ-009、security-spec.md B3)。sh/ps1 の挙動差異は片系統でのみ設定破壊を起こす silent defect になる。
Required Workflow: tdd
Requirements: REQ-007, REQ-008, REQ-009
Rollback: 本タスクのコミットを revert(install.sh 側 T-004 には影響しない)。

### Goal
install.ps1 に T-004 と同一挙動(local-env-mcp 既定同梱・-Mcp / -SkipMcp、
Cursor / VS Code 冪等 upsert、フェイルセーフ、スキップ通知)を実装する。

### Scope
- install.ps1(Mcp 既定値 / Register-CursorMcp / Register-VSCodeMcp)
- tests/install.tests.ps1(AC-013 と AC-010/011/015 の ps1 相当ケース)

### Done When
- [ ] AC-013: install.ps1 が install.sh と同一挙動(同梱・選択・登録・冪等性)
- [ ] AC-010/011/015 相当の ps1 ケースが green(他エントリ保持・冪等・フェイルセーフ)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-005.md)
- [ ] quality gate pass

### Blockers
T-004

## T-006 uninstall(sh / ps1): 配置削除 + 4 クライアント登録解除

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: uninstall は削除系操作であり、欠陥はユーザー定義の他 MCP エントリの誤削除(非可逆的なユーザーデータ喪失)に直結する(REQ-010、security-spec.md B3 の誤削除 STRIDE 行)。
Required Workflow: tdd
Requirements: REQ-010
Rollback: 本タスクのコミットを revert。誤削除防止は「installer 管理名のみ削除」の設計とテストで担保。

### Goal
uninstall.sh / uninstall.ps1 を拡張し、配置済み local-env-mcp の削除と、
Claude / Codex / Cursor / VS Code からの installer 管理エントリ
(sdd-forge-mcp / local-env-mcp)のみの登録解除を実装する。ユーザー定義の
他エントリは無傷であること。

### Scope
- uninstall.sh / uninstall.ps1
- tests/uninstall.tests.sh または tests/install.tests.sh 内 uninstall ケース、
  tests/install.tests.ps1 の ps1 相当ケース(AC-012)

### Done When
- [ ] AC-012: 配置削除 + 4 クライアントから管理エントリのみ除去、他エントリ無傷(sh/ps1 両方)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-006.md)
- [ ] quality gate pass

### Blockers
T-004, T-005

## T-007 ドキュメント(README / USERGUIDE)+ traceability 最終化

Approval: Draft
Status: Planned
Risk: low
Risk Rationale: ドキュメント追記と traceability 表の Status 更新のみで、制御フロー・データ・セキュリティへの影響がない。
Required Workflow: test-after
Requirements: REQ-011
Rollback: 本タスクのコミットを revert。

### Goal
README / USERGUIDE に local-env-mcp の概要・3 ツール・セキュリティ境界
(実行機能なし)・Cursor / VS Code の自動/手動登録手順を追記し、
traceability.md の全 AC / TEST の Status を最終化する。

### Scope
- README.md / USERGUIDE.md
- specs/local-env-mcp/traceability.md(Status 更新)

### Done When
- [ ] AC-014: README / USERGUIDE に所定の 4 項目(概要・ツール一覧・境界・登録手順)が記載される
- [ ] traceability.md の REQ→AC→TEST→Task チェーンが全行最終化される
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-007.md)
- [ ] quality gate pass

### Blockers
T-001, T-002, T-003, T-004, T-005, T-006
