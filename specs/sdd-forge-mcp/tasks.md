# Tasks: sdd-forge-mcp

Task-Review-Status: Passed

Source: specs/sdd-forge-mcp/requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed) / Issue #60

Lifecycle: `Draft -> Approved -> In Progress -> Implementation Complete -> Done`
Tasks approved by humans (Approval line). `implement-task` sets In
Progress/Blocked/Implementation Complete. Only `quality-gate` may set Done.

実行順序（Blockers で機械的に強制）: T-001 → (T-002 / T-003 / T-011) → T-004 → (T-009 / T-005) → T-010 → (T-006 / T-007) → T-008

## T-001 Node 基盤 + path-guard + root 解決 + エラーエンベロープ

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: path-guard は allowlist/denylist・traversal 拒否の唯一のチョークポイントであり、欠陥は SDD_SUDO・署名鍵等の restricted 情報漏えいに直結する（REQ-006/REQ-007、security-spec.md B2）。
Required Workflow: tdd
Requirements: REQ-001, REQ-006, REQ-007, REQ-008
Rollback: 本タスクのコミットを revert（未リリース段階、他タスクは Blockers で未着手のため影響なし）。infra-spec.md「Rollback」節参照。

### Goal
mcp/sdd-forge-mcp/ の TypeScript プロジェクト基盤（package.json / tsconfig /
esbuild ビルド）を作り、root 解決（--root > SDD_FORGE_ROOT > cwd、起動時固定）、
path-guard（realpath → allowlist 前方一致 → denylist 拒否 → 2 MiB サイズ上限、
fail-closed）、共通エラーエンベロープ（cannot-parse / cannot-determine /
not-found / path-denied / not-sdd-root / too-large / invalid-input）を実装する。

### Scope
- mcp/sdd-forge-mcp/{package.json,tsconfig.json,src/root.ts,src/path-guard.ts,src/envelope.ts}
- tests/path-security/（AC-003/AC-004）、tests/root-immutable/（AC-016）、
  tests/error-paths/ の too-large / not-sdd-root 分（AC-017 部分）
- esbuild バンドル設定と `npm run build`（dist/ コミットは T-007 の dist-parity
  検証と対）
- 静的 read-only 検証スクリプト（fs 書込み API の grep 検査、AC-011 静的部分）

### Done When
- [ ] AC-003 / AC-004: traversal（`..`・絶対パス・symlink 脱出）と allowlist 外・denylist（SDD_SUDO・署名鍵・.env）が `path-denied` で拒否され、応答/ログに値が現れない
- [ ] AC-016: tool 入力スキーマに root 相当引数がなく、起動後の env/cwd 変更が応答に影響しない
- [ ] AC-017（部分）: 2 MiB 超過 → `too-large`、SDD 構造なし root → `not-sdd-root`
- [ ] Red→Green evidence 記録（tdd）
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance（spec_revision 含む）付き evidence bundle 生成
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-001.md）
- [ ] quality gate pass

### Blockers
None

## T-002 tasks.md 状態機械パーサー + シェル等価ゴールデンテスト

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: get_task_state の判定は quality gate 判断の入力源であり、check-task-state.sh との不一致は品質ゲートの誤通過を招く（REQ-005、Issue #60 リスク欄）。
Required Workflow: tdd
Requirements: REQ-005
Rollback: 本タスクのコミットを revert。パーサーは他モジュールから独立（T-004 以降が未着手の段階では参照なし）。infra-spec.md「Rollback」節参照。

### Goal
check-task-state.sh とシェル等価な tasks.md パーサー（Approval / Status / Risk /
Second Approval / Blockers、Done 遷移要件、critical 二重承認、重複 T-ID 検出）を
実装し、既存 6 spec に対するゴールデンテストで完全一致を証明する。

### Scope
- mcp/sdd-forge-mcp/src/parsers/tasks.ts
- tests/parser/（cannot-parse 系、AC-002）、tests/golden/（AC-001。POSIX では
  シェル実行と突合、Windows 用に記録済みフィクスチャを生成）
- 判定不能入力は `cannot-parse` + 該当行情報（推測値を返さない）

### Done When
- [ ] AC-001: 既存 6 spec で verdict/failures が check-task-state.sh の exit code・失敗メッセージと完全一致
- [ ] AC-002: 不正 tasks.md（重複 T-ID・不正 Status・Approval 欠落）で `cannot-parse` を返す
- [ ] Red→Green evidence 記録（tdd）
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance（spec_revision 含む）付き evidence bundle 生成
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-002.md）
- [ ] quality gate pass

### Blockers
T-001

## T-003 SDD 状態系パーサー（AGENTS.md / review tickets / quality reports）

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: これらのパーサー出力（active specs、RT 状態、QG verdict）は quality gate 前処理・次コマンド判断の入力源であり、誤抽出は誤った状態認識に直結する（REQ-002 の入力層）。
Required Workflow: tdd
Requirements: REQ-002
Rollback: 本タスクのコミットを revert。パーサーは相互独立（T-004 が未着手の段階では参照なし）。infra-spec.md「Rollback」節参照。

### Goal
AGENTS.md（Active Spec Directories / フェーズ定義）、RT-*.yml（js-yaml）、
reports/quality-gate/*.md（VERDICT/counts 抽出）の 3 パーサーを実装する。
すべて「解釈できないものは cannot-parse」原則に従う。

### Scope
- mcp/sdd-forge-mcp/src/parsers/{agents-md,review-ticket,quality-report}.ts
- 各パーサーのユニットテスト（正常系 + cannot-parse 系、実 spec からの
  決定論フィクスチャ）

### Done When
- [ ] 3 パーサーが実ファイル（AGENTS.md、RT-20260623-001.yml、既存 QG レポート）を正しく解釈する
- [ ] 異常系フィクスチャで `cannot-parse` + 詳細を返す
- [ ] Red→Green evidence 記録（tdd）
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance（spec_revision 含む）付き evidence bundle 生成
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-003.md）
- [ ] quality gate pass

### Blockers
T-001

## T-011 evidence 系パーサー（evidence bundle / verification contract / traceability）

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: evidence.json / contract.json / traceability.md のパーサー出力は evidence tools（T-005）の突合判断の入力源であり、誤抽出は evidence 不備の見落としに直結する（REQ-003 の入力層）。
Required Workflow: tdd
Requirements: REQ-003
Rollback: 本タスクのコミットを revert。パーサーは相互独立（T-005 が未着手の段階では参照なし）。infra-spec.md「Rollback」節参照。

### Goal
*.evidence.json / *.contract.json（構造・task_id 整合）と traceability.md
（表抽出）の 2 パーサーを実装する。すべて「解釈できないものは cannot-parse」
原則に従う。

### Scope
- mcp/sdd-forge-mcp/src/parsers/{evidence,traceability}.ts
- 各パーサーのユニットテスト（正常系 + cannot-parse 系、既存
  specs/sdd-forge-refactor/verification/ の実ファイルからの決定論フィクスチャ）

### Done When
- [ ] 2 パーサーが実ファイル（既存 evidence/contract、既存 traceability.md）を正しく解釈する
- [ ] 異常系フィクスチャで `cannot-parse` + 詳細を返す
- [ ] Red→Green evidence 記録（tdd）
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance（spec_revision 含む）付き evidence bundle 生成
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-011.md）
- [ ] quality gate pass

### Blockers
T-001

## T-004 MCP サーバー本体 + core tools 8 種

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: サーバー本体が read-only 保証（REQ-001）と quality gate 判断入力の提供者であり、tool 応答の欠陥・書込み混入は品質ゲートの完全性を毀損する。
Required Workflow: tdd
Requirements: REQ-001, REQ-002
Rollback: 本タスクのコミットを revert（dist/ 未コミット段階のため revert のみで完結）。導入済み環境が存在する場合は uninstall.sh --mcp sdd-forge-mcp。infra-spec.md「Rollback」節参照。

### Goal
@modelcontextprotocol/sdk（stdio）でサーバーを組み立て、core tools 8 種
（list_active_specs / get_spec_status / get_task_state / list_approved_tasks /
list_blocked_tasks / list_review_tickets / get_quality_gate_summary /
get_next_sdd_command のツール登録枠。next-command の判定ロジック本体は T-010）を
実装する。応答は contracts/sdd-forge-mcp-tools.v1.schema.json 準拠。

### Scope
- mcp/sdd-forge-mcp/src/{index,server}.ts, src/tools/core.ts
- tests/core-tools/（AC-015: 8 tools × スキーマ検証+主要フィールド。
  get_next_sdd_command は T-010 完了までスタブ判定＝cannot-determine を返す
  暫定実装で、スキーマ準拠のみ検証）
- tests/readonly/（AC-011 実行時スナップショット比較）
- エラーパス: tasks.md 欠落 feature → `not-found`（AC-017 残り）

### Done When
- [ ] AC-015: 8 core tools すべてがスキーマ準拠応答+期待フィールド一致
- [ ] AC-011: 全 tool 実行前後でリポジトリ内容が不変（スナップショット比較）
- [ ] AC-017（残り）: tasks.md 欠落 feature → `not-found`
- [ ] Red→Green evidence 記録（tdd）
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance（spec_revision 含む）付き evidence bundle 生成
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-004.md）
- [ ] quality gate pass

### Blockers
T-001, T-002, T-003

## T-009 resources 5 種

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: resources は quality gate 前処理の入力源（sdd:// URI 経由の状態読み取り）であり、誤った内容の返却は誤った状態認識に直結する（REQ-004）。
Required Workflow: tdd
Requirements: REQ-004
Rollback: 本タスクのコミットを revert。導入済み環境が存在する場合は uninstall.sh --mcp sdd-forge-mcp。infra-spec.md「Rollback」節参照。

### Goal
resources 5 種（sdd://active-specs, sdd://spec/{feature}, sdd://tasks/{feature},
sdd://review-tickets, sdd://quality-reports）を実装する。各 resource は対応
tool と同一の data を application/json で返す読み取りビュー。

### Scope
- mcp/sdd-forge-mcp/src/resources.ts
- tests/resources/（AC-013: 5 resources × 実 spec フィクスチャで内容検証）

### Done When
- [ ] AC-013: resources 5 種が正しい内容を返す
- [ ] Red→Green evidence 記録（tdd）
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance（spec_revision 含む）付き evidence bundle 生成
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-009.md）
- [ ] quality gate pass

### Blockers
T-004

## T-010 next-command 決定論マッピング + Inspector smoke

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: get_next_sdd_command は次に実行すべき SDD コマンドの決定論的判断を提供し、誤マッピングはワークフロー誤誘導（未承認タスクの実装開始等）につながる（REQ-011）。
Required Workflow: tdd
Requirements: REQ-011
Rollback: 本タスクのコミットを revert。導入済み環境が存在する場合は uninstall.sh --mcp sdd-forge-mcp。infra-spec.md「Rollback」節参照。

### Goal
next-command 決定論マッピング（AGENTS.md フェーズ定義 + sdd-ship 選択規則、
判定不能 → cannot-determine）を実装して T-004 のスタブを置換し、サーバー全体の
MCP Inspector smoke を通す。

### Scope
- mcp/sdd-forge-mcp/src/next-command.ts（T-004 のスタブを置換）
- tests/next-command/（AC-012: フェーズ網羅 fixture + cannot-determine）
- tests/smoke/（AC-005: MCP Inspector CLI — tools/list, resources/list, 代表呼び出し）

### Done When
- [ ] AC-012: get_next_sdd_command が AGENTS.md フェーズ・sdd-ship 選択規則と整合、判定不能で cannot-determine
- [ ] AC-005: MCP Inspector smoke が macOS で通過
- [ ] Red→Green evidence 記録（tdd）
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance（spec_revision 含む）付き evidence bundle 生成
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-010.md）
- [ ] quality gate pass

### Blockers
T-004, T-009

## T-005 evidence tools 5 種

Approval: Approved
Status: Implementation Complete
Risk: high
Risk Rationale: evidence_find_missing / evidence_compare_to_traceability は Done 遷移前準備・品質判断の直接入力であり、不足の見落としは evidence 不備のまま Done を通す誘因になる（REQ-003）。
Required Workflow: tdd
Requirements: REQ-003
Rollback: 本タスクのコミットを revert。導入済み環境が存在する場合は uninstall.sh --mcp sdd-forge-mcp。infra-spec.md「Rollback」節参照。

### Goal
evidence_get_bundle / evidence_validate_paths / evidence_find_missing /
evidence_summarize_contract_checks / evidence_compare_to_traceability を実装する
（署名鍵には一切アクセスしない。署名検証は非目標）。

### Scope
- mcp/sdd-forge-mcp/src/tools/evidence.ts
- tests/evidence/（AC-014: 実 evidence/contract フィクスチャ + 不足・不一致
  合成フィクスチャ）

### Done When
- [ ] AC-014: evidence.json / contract.json / traceability.md を正しく解釈し不足・不一致を構造化して返す
- [ ] Done 遷移要件（evidence.json + contract.json + QG レポート VERDICT: PASS）基準の missing 判定が check-task-state.sh の Done 要件と整合
- [ ] Red→Green evidence 記録（tdd）
- [ ] 独立レビュー verdict PASS が evidence に記録される
- [ ] provenance（spec_revision 含む）付き evidence bundle 生成
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-005.md）
- [ ] quality gate pass

### Blockers
T-001, T-011, T-004

## T-006 installer / uninstaller 統合（--skip-mcp / --mcp、Claude/Codex 登録）

Approval: Approved
Status: Implementation Complete
Risk: medium
Risk Rationale: ユーザー環境の設定ファイル（MCP 登録）への書込みを伴うが、既存 installer の確立パターンの拡張であり、失敗モードは導入不全（回復可能）。bash 3.2 互換維持が主要リスク。
Required Workflow: acceptance-first
Requirements: REQ-009
Rollback: installer 変更のコミットを revert。誤登録が発生した環境は uninstall.sh（登録解除 + 配置除去）で復帰。infra-spec.md「Rollback」節参照。

### Goal
install.sh / install.ps1 にデフォルト MCP 配置 + Claude Code（claude mcp add）/
Codex 登録を追加し、`--skip-mcp` で除外、`--mcp <list>` で選択導入できるように
する。uninstall.sh / uninstall.ps1 は登録解除 + 配置除去（best-effort）。
OQ-001（Codex 登録手段）はこのタスク内で解決し実装レポートに記録する。

### Scope
- install.sh / install.ps1 / uninstall.sh / uninstall.ps1（bash 3.2 互換、
  連想配列不使用）
- Node >= 20 不在時は警告して MCP 部分のみスキップ
- tests/install.tests.sh / .ps1、tests/uninstall.tests.sh / .ps1 へのケース追加

### Done When
- [ ] AC-007: デフォルト install で配置+登録、--skip-mcp で両方スキップ
- [ ] AC-008: --mcp <list> で指定 MCP のみ導入（不正名はエラー）
- [ ] AC-009: uninstall で配置除去+登録解除（未導入時 best-effort 成功）
- [ ] 受入テスト先行（acceptance-first）で実装
- [ ] OQ-001 の解決内容（Codex 登録手段）を実装レポートに記録
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-006.md）
- [ ] quality gate pass

### Blockers
T-005, T-009, T-010

## T-007 CI 統合（mcp-tests 3 OS + dist-parity + npm audit）

Approval: Approved
Status: Implementation Complete
Risk: medium
Risk Rationale: CI 追加は既存パイプラインの拡張で回復可能だが、dist-parity は dist 改ざん検出の唯一の保証であり、設定ミスは検出漏れにつながる（REQ-008/REQ-010）。
Required Workflow: acceptance-first
Requirements: REQ-008, REQ-010
Rollback: workflow 変更のコミットを revert（既存ジョブは無変更のため revert で完全復帰）。infra-spec.md「Rollback」節参照。

### Goal
.github/workflows/test.yml に mcp-tests ジョブ（3 OS マトリクス: npm ci →
tsc --noEmit → node --test）、dist-parity ステップ（再ビルド + git diff
--exit-code dist/）、npm audit --omit=dev（High 以上 fail）を追加する。
POSIX ではゴールデンテストがシェル実行と突合、Windows ではフィクスチャ比較。

### Scope
- .github/workflows/test.yml（既存ジョブは変更しない）
- dist/ の初回コミット（T-001〜T-005 / T-009〜T-011 の成果物をバンドル）

### Done When
- [ ] AC-006: windows-latest でパーサー・パス処理テスト通過
- [ ] AC-010: dist-parity（src/ 再ビルド = コミット済み dist/）が CI で検証される
- [ ] npm audit --omit=dev が CI に組み込まれ High 以上で fail
- [ ] 既存の shell/pwsh テストジョブが変更前後で同一結果
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-007.md）
- [ ] quality gate pass

### Blockers
T-005, T-009, T-010

## T-008 ドキュメント（USERGUIDE への MCP 節追加）

Approval: Approved
Status: Implementation Complete
Risk: low
Risk Rationale: ドキュメントのみの変更。コード・制御フロー・セキュリティへの影響なし。
Required Workflow: test-after
Requirements: REQ-009
Rollback: ドキュメント変更のコミットを revert。

### Goal
USERGUIDE.md に sdd-forge-mcp の導入（デフォルト/--skip-mcp/--mcp）、tool 一覧、
root 指定（--root / SDD_FORGE_ROOT / cwd）、トラブルシュート（stderr ログの
読み方、rollback 手順 = uninstall）を追記する。

### Scope
- USERGUIDE.md（および必要なら README.md の1段落）
- infra-spec.md Observability 欄の Runbook 参照先を確定

### Done When
- [ ] 導入・除外・選択導入・rollback の手順が USERGUIDE.md に記載される
- [ ] tool 13 種 + resources 5 種の一覧と用途が記載される
- [ ] 実装レポート作成（reports/implementation/sdd-forge-mcp-T-008.md）
- [ ] quality gate pass

### Blockers
T-006, T-007
