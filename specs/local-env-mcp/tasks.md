# Tasks: local-env-mcp

Task-Review-Status: Passed

Source: specs/local-env-mcp/requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed) / Issue #64

Lifecycle: `Draft -> Approved -> In Progress -> Implementation Complete -> Done`

## T-001 local-env-mcp 基盤 + probe-engine + エラーエンベロープ

Approval: Approved (sudo 2026-07-05T10:33:11Z)
Status: Done
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

## T-002 MCP ツール 3 種 + server/index + 契約・no-exec 検証

Approval: Approved (sudo 2026-07-05T10:33:11Z)
Status: Implementation Complete
Risk: high
Risk Rationale: ツール入力スキーマは B1 境界(REQ-003: コマンド/引数/パス系フィールド非提供、enum のみ)そのものであり、欠陥は injection 経路に直結する(security-spec.md B1)。
Required Workflow: tdd
Requirements: REQ-001, REQ-002, REQ-003, REQ-004
Rollback: 本タスクのコミットを revert(T-001 基盤は独立して残置可能)。

### Goal
`get_os_info` / `get_toolchain_versions` / `list_available_clis` の 3 ツールと
server.ts / index.ts(stdio 起動、起動時プローブなし)を実装し、
contracts/local-env-mcp-tools.v1.schema.json への契約準拠(ajv)と
入力スキーマ境界(no-exec)検査までを green にする。

### Scope
- mcp/local-env-mcp/src/{server.ts,index.ts,tools/env.ts}
- mcp/local-env-mcp/tests/tools/(AC-001 snapshot + ajv、AC-002 integration)
- mcp/local-env-mcp/tests/no-exec/(AC-003: allowlist 外 name / 追加プロパティ /
  パス文字列 → invalid-input、入力スキーマにコマンド系フィールド不在)

### Done When
- [ ] AC-001: get_os_info が契約準拠エンベロープで全フィールドを返す
- [ ] AC-002: get_toolchain_versions が per-entry available/version を返し全体 ok
- [ ] AC-003: allowlist 外入力が invalid-input、スキーマにコマンド系フィールド不在
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-002.md)
- [ ] quality gate pass

### Blockers
T-001

## T-003 stderr 診断ロガー(redaction)+ no-secrets 検査

Approval: Approved (sudo 2026-07-05T10:33:11Z)
Status: Implementation Complete
Risk: high
Risk Rationale: 診断ログと応答の秘匿値混入は秘密情報・準 PII 漏えい(REQ-005)に直結する(security-spec.md B1/B2 の Information Disclosure)。
Required Workflow: tdd
Requirements: REQ-001, REQ-005
Rollback: 本タスクのコミットを revert(T-002 までの機能は独立して残置可能)。

### Goal
起動診断・致命エラーのみを stderr に JSON 出力する診断ロガーを実装し
(環境変数値・ユーザー名・ホスト名・ホームパス・PATH 全文を出力しない
redaction 設計)、canary 環境変数を用いた no-secrets 検査で全ツール応答と
stderr の非漏えいを検証する。

### Scope
- mcp/local-env-mcp/src/diagnostics.ts(redaction 付き stderr 診断)
- mcp/local-env-mcp/src/index.ts(診断ロガー組込み)
- mcp/local-env-mcp/tests/no-secrets/(AC-005: canary env・HOME・ユーザー名・
  ホスト名・PATH 全文の不在検査)

### Done When
- [ ] AC-005: canary 検査で応答・stderr に秘密情報・準 PII が不在
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-003.md)
- [ ] quality gate pass

### Blockers
T-002

## T-004 esbuild バンドル + dist コミット + CI dist-parity + Inspector スモーク

Approval: Approved (sudo 2026-07-05T10:33:11Z)
Status: Implementation Complete
Risk: medium
Risk Rationale: 配布物(dist)と CI 検証・スモークの追加。挙動面は既存 ADR-0003 パターンの踏襲で、欠陥は CI で検出可能(改竄検知は dist-parity 自体が担う)。
Required Workflow: acceptance-first
Requirements: REQ-001, REQ-002, REQ-006, REQ-012
Rollback: 本タスクのコミットを revert(dist と CI ジョブが同一コミットで戻る)。

### Goal
esbuild 単一バンドル `mcp/local-env-mcp/dist/index.js` を生成・コミットし、
.github/workflows/test.yml に local-env-mcp の typecheck / test / dist-parity
ジョブ(sdd-forge-mcp と同型)を追加する。MCP Inspector CLI スモークで
stdio 起動と 3 ツール列挙を検証する。

### Scope
- mcp/local-env-mcp/package.json(build スクリプト確定)
- mcp/local-env-mcp/dist/index.js(コミット)
- mcp/local-env-mcp/tests/smoke/(AC-007: Inspector CLI tools/list)
- .github/workflows/test.yml(local-env-mcp ジョブ追加)

### Done When
- [ ] AC-007: Inspector スモークで 3 ツールが列挙される
- [ ] AC-008: CI の dist-parity(src 再ビルド → コミット済み dist と diff 一致)が PASS
- [ ] acceptance テスト(AC-007 / AC-008 の検証手順)が実装に先行して記述される
- [ ] local-env-mcp の typecheck / 全テストが CI で green
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-004.md)
- [ ] quality gate pass

### Blockers
T-003

## T-005 OQ-001 解消: Cursor / VS Code 設定形式の確定(design.md 更新)

Approval: Approved (sudo 2026-07-05T10:33:11Z)
Status: Implementation Complete
Risk: low
Risk Rationale: 公式ドキュメント調査と design.md「API / Contract Plan」の更新のみで、コード・データ・セキュリティ制御への変更がない(実装への反映は T-007/T-008 が担う)。
Required Workflow: test-after
Requirements: REQ-008, REQ-009
Rollback: design.md の該当節の変更を revert。

### Goal
Cursor / VS Code(Copilot MCP)の MCP 設定ファイルの正確なパスとスキーマ
(`~/.cursor/mcp.json` の `mcpServers` / VS Code ユーザープロファイル
`mcp.json` の `servers`、OS 別パス)を各公式ドキュメントで確認し、確認結果
(出典 URL・確認日)を design.md「API / Contract Plan」に反映して OQ-001 を
解消する。

### Scope
- specs/local-env-mcp/design.md(「API / Contract Plan」の登録形式確定、
  「Open Questions」OQ-001 の解消記録)

### Done When
- [ ] Cursor / VS Code の設定パス・スキーマが出典付きで確定記載される — 記録先は凍結対象外の addenda(reports/implementation/local-env-mcp/T-005.md および USERGUIDE.md)。design.md はデザインレビュー済みバイトで凍結(文言修正: 2026-07-05 人間承認、AGENTS.md「Post-review artifact freeze」(WFI-004)に基づく)
- [ ] OQ-001 の解消記録(確定形式・出典 URL・確認日)が addendum(reports/implementation/local-env-mcp/T-005.md)に記載される(文言修正: 2026-07-05 人間承認、同上)
- [ ] validate-layer-traceability が green のまま
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-005.md)
- [ ] quality gate pass

### Blockers
None

## T-006 install.sh コア拡張: local-env-mcp 同梱・選択・Node<20 ゲート

Approval: Approved (sudo 2026-07-05T10:33:11Z)
Status: Implementation Complete
Risk: high
Risk Rationale: installer の MCP 配置経路の変更であり、欠陥は誤配置・意図しない登録(REQ-007)としてユーザー環境に影響する。Node<20 ゲートの退行は非対応環境への配置事故になる(requirements.md Edge Cases)。
Required Workflow: tdd
Requirements: REQ-007
Rollback: 本タスクのコミットを revert(既存 sdd-forge-mcp の配置経路は変更前挙動に戻る)。

### Goal
install.sh の `VALID_MCPS` / 既定 `MCP_LIST` に local-env-mcp を追加し
(デフォルト同梱)、`--mcp <list>` 選択・`--skip-mcp`・Node >= 20 ゲート
(MCP_NODE_OK)が local-env-mcp を含む複数 MCP で正しく機能することを
検証する。

### Scope
- install.sh(VALID_MCPS / MCP_LIST、既存 place/register 経路の複数 MCP 動作確認)
- tests/install.tests.sh(AC-009 の 3 挙動 + Node<20 ゲートのケース)

### Done When
- [ ] AC-009: デフォルト同梱 / --mcp 選択 / --skip-mcp の 3 挙動が green
- [ ] Node < 20 フェイク環境(PATH 制御)で local-env-mcp を含む MCP の配置・登録が行われず警告が出る(requirements.md Edge Cases 対応、tests/install.tests.sh)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-006.md)
- [ ] quality gate pass

### Blockers
T-004

## T-007 install.sh Cursor / VS Code 冪等登録

Approval: Approved (sudo 2026-07-05T10:33:11Z)
Status: Implementation Complete
Risk: high
Risk Rationale: ユーザーの IDE 設定ファイル(~/.cursor/mcp.json、VS Code user-profile mcp.json)を書き換えるデータ変異であり、欠陥はユーザーの既存 MCP 設定の破壊に直結する(REQ-008/REQ-009、security-spec.md B3、ADR-0005)。
Required Workflow: tdd
Requirements: REQ-008, REQ-009
Rollback: 本タスクのコミットを revert。登録済みエントリは uninstall(T-009)または手動でキー削除。壊れ JSON フェイルセーフにより設定ファイルの非可逆破壊は発生しない設計。

### Goal
install.sh に Cursor(`mcpServers` キー)/ VS Code(`servers` キー、OS 別
パス)への冪等 JSON upsert 登録を実装する(Node ワンライナーによる JSON
操作、他エントリ保持、壊れ JSON は不変更 + エラー通知、クライアント未導入は
スキップ通知)。登録形式は T-005 で確定した design.md の記載に従う。

### Scope
- install.sh(register_cursor_mcp / register_vscode_mcp / JSON upsert ヘルパー)
- tests/install.tests.sh(AC-010 / AC-011 / AC-015 の HOME 隔離ケース)

### Done When
- [ ] AC-010: Cursor 登録が他エントリ保持・再実行冪等・未導入スキップ通知
- [ ] AC-011: VS Code 登録が他エントリ保持・再実行冪等・未導入スキップ通知
- [ ] AC-015: 壊れ JSON で不変更 + エラー通知 + 他クライアント継続
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-007.md)
- [ ] quality gate pass

### Blockers
T-005, T-006

## T-008 install.ps1 パリティ

Approval: Approved (sudo 2026-07-05T10:33:11Z)
Status: Implementation Complete
Risk: high
Risk Rationale: T-006/T-007 と同一の IDE 設定ファイル変異面を Windows/PowerShell 経路で持つ(REQ-007〜REQ-009、security-spec.md B3)。sh/ps1 の挙動差異は片系統でのみ設定破壊を起こす silent defect になる。
Required Workflow: tdd
Requirements: REQ-007, REQ-008, REQ-009
Rollback: 本タスクのコミットを revert(install.sh 側 T-006/T-007 には影響しない)。

### Goal
install.ps1 に T-006/T-007 と同一挙動(local-env-mcp 既定同梱・-Mcp /
-SkipMcp・Node<20 ゲート、Cursor / VS Code 冪等 upsert、フェイルセーフ、
スキップ通知)を実装する。

### Scope
- install.ps1(Mcp 既定値 / Register-CursorMcp / Register-VSCodeMcp)
- tests/install.tests.ps1(AC-013、AC-010/011/015 相当と Node<20 相当の ps1 ケース)

### Done When
- [ ] AC-013: install.ps1 が install.sh と同一挙動(同梱・選択・Node<20 ゲート・登録・冪等性・フェイルセーフ)
- [ ] Red→Green evidence 記録(tdd)
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance(spec_revision 含む)付き evidence bundle 生成
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-008.md)
- [ ] quality gate pass

### Blockers
T-007

## T-009 uninstall(sh / ps1): 配置削除 + 4 クライアント登録解除

Approval: Approved (sudo 2026-07-05T10:33:11Z)
Status: Implementation Complete
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
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-009.md)
- [ ] quality gate pass

### Blockers
T-007, T-008

## T-010 ドキュメント(README / USERGUIDE)+ traceability 最終化

Approval: Approved (sudo 2026-07-05T10:33:11Z)
Status: Implementation Complete
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
- [ ] REQ→AC→TEST→Task チェーン全行の最終化(Verification Status 表)が addendum(reports/implementation/local-env-mcp/T-010.md)に記録される — traceability.md 本体はタスクレビュー済みバイトで凍結(文言修正: 2026-07-05 人間承認、AGENTS.md「Post-review artifact freeze」(WFI-004)に基づく)
- [ ] 実装レポート作成(reports/implementation/local-env-mcp-T-010.md)
- [ ] quality gate pass

### Blockers
T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009
