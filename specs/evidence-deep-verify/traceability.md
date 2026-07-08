# Traceability: evidence-deep-verify

## REQ → 根拠 / Layer Spec

各 REQ の正準レイヤー仕様アンカー(Layer Spec 列)。レイヤー仕様が所有しない横断要件は
`N/A — cross-layer only:` で理由を記す。

| REQ-ID | 根拠 | Layer Spec | 説明 |
|-----|---|---|---|
| REQ-001 | Issue #68 スコープ | N/A — cross-layer only: ツール仕様は design.md「API / Contract Plan」と contracts/sdd-forge-mcp-tools.v1.schema.json が正準 | 6 番目の read-only ツール evidence_deep_verify の追加・登録 |
| REQ-002 | Issue #68 スコープ | security-spec.md#trust-boundaries | per-artifact sha256 再計算とディスク突合(path-guard 経由) |
| REQ-003 | Issue #68 スコープ | N/A — cross-layer only: verdict/failures 形状は design.md「API / Contract Plan」が正準 | 全体 verdict(pass/fail)と failures 列挙 |
| REQ-004 | host スクリプト evidence_canonical | N/A — cross-layer only: 正準 artifacts ダイジェスト式は design.md「API / Contract Plan」が逐語引用の正準 | 正準 artifacts ダイジェスト不変条件(ADR-0009) |
| REQ-005 | host スクリプト compute_spec_revision | security-spec.md#trust-boundaries | spec_revision 不変条件(specs/<feature> 読取・ADR-0009) |
| REQ-006 | Issue #68 スコープ / no-exec 境界 | security-spec.md#stride-analysis | git_commit 40-hex 検証・祖先 host-deferred(ADR-0008) |
| REQ-007 | host スクリプト task_id/feature 整合 | N/A — cross-layer only: クロスバインド判定は design.md「API / Contract Plan」が正準 | contract/report クロスバインド不変条件 |
| REQ-008 | Issue #68 最重要セキュリティ不変条件 | security-spec.md#trust-boundaries; security-spec.md#secrets-management | 署名鍵非読取・署名非検証の硬境界(ADR-0008) |
| REQ-009 | Issue #68 agreement 要件 | security-spec.md#security-tests | host スクリプトとの判定一致(ADR-0009) |
| REQ-010 | 品質規約(決定論) | infra-spec.md#service-level-objectives | 決定論(同一入力 → 同一出力) |
| REQ-011 | sdd-forge-mcp 基盤踏襲 | security-spec.md#trust-boundaries | path-guard 再利用・例外安全(欠落/巨大/denied) |
| REQ-012 | sdd-forge-mcp 契約規約 | N/A — cross-layer only: エンベロープ契約は contracts/sdd-forge-mcp-tools.v1.schema.json が正準 | evidenceDeepVerifyData の加算的追加 |
| REQ-013 | AGENTS.md 品質規約 | frontend-spec.md#testing | node:test / 静的 read-only 検査の踏襲 |

## REQ → ADR

| REQ-ID | 関連 ADR | 決定内容 |
|-----|---|---|
| REQ-006, REQ-008 | ADR-0008 | 署名鍵非読取・署名非検証・git 祖先 host-deferred(40-hex 形状のみ検証) |
| REQ-004, REQ-005, REQ-007, REQ-009 | ADR-0009 | host スクリプトの正準式(evidence_canonical / compute_spec_revision / 40-hex ルール)を逐語一致で再実装 + ゴールデン |
| REQ-001, REQ-012, REQ-013 | ADR-0003 | esbuild 単一バンドル dist コミット + dist-parity CI + Node >= 20(既存踏襲) |

## Task → REQ

Phase 1(本 spec)ではタスク分解(tasks.md)を未作成。タスク割当は Phase 2(タスク分解ゲート)で
確定する。本表はプレースホルダとして意図的に空とし、REQ→AC→TEST の追跡は下表で担保する。

| Task | REQ-ID | 内容 |
|---|-----|---|
| (Phase 2 で確定) | — | tasks.md 未作成(Phase 1 は spec のみ) |

## AC → REQ

| AC-ID | REQ-ID | 検証内容 |
|-----|---|---|
| AC-001 | REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-007 | 整合バンドル → pass |
| AC-002 | REQ-002, REQ-003, REQ-004 | 成果物 1 バイト改竄 → mismatch + fail |
| AC-003 | REQ-002, REQ-003 | 記録ハッシュ改竄 → mismatch |
| AC-004 | REQ-002, REQ-003, REQ-011 | 成果物欠落 → missing(throw しない) |
| AC-005 | REQ-002, REQ-011 | 2 MiB 超 → too-large / allowlist 外 → path-denied |
| AC-006 | REQ-005, REQ-003 | spec_revision ドリフト → mismatch |
| AC-007 | REQ-006, REQ-003 | git_commit 非 40-hex → 形状不正で fail |
| AC-008 | REQ-006, REQ-008 | 外部 40-hex → ancestry 未検証・git 不起動 |
| AC-009 | REQ-007, REQ-003 | contract クロスバインド不一致 → mismatch |
| AC-010 | REQ-007, REQ-003 | report クロスバインド不一致 → mismatch |
| AC-011 | REQ-008 | 署名 present/verified:false・鍵非読取・canary 非漏えい |
| AC-012 | REQ-009 | host スクリプトとの判定一致(ゴールデン) |
| AC-013 | REQ-010 | 決定論(2 回呼び出しバイト等価) |
| AC-014 | REQ-011, REQ-008 | 静的 read-only / no-exec / 鍵読取経路 0 件 |
| AC-015 | REQ-012 | evidenceDeepVerifyData 契約適合・エラーエンベロープ |
| AC-016 | REQ-001, REQ-013 | tools/list スモーク(evidence 6 番目) |

## AC → TEST → Task

Task-ID は Phase 2(タスク分解)で確定するため、本表では `(Phase 2)` とする。Test Target は
実装先ディレクトリを正準として記す。

| AC-ID | TEST-ID | Task-ID | Test Target |
|-----|---|---|---|
| AC-001 | TEST-001 | (Phase 2) | mcp/sdd-forge-mcp/tests/tools/ |
| AC-002 | TEST-002 | (Phase 2) | mcp/sdd-forge-mcp/tests/tools/ |
| AC-003 | TEST-003 | (Phase 2) | mcp/sdd-forge-mcp/tests/tools/ |
| AC-004 | TEST-004 | (Phase 2) | mcp/sdd-forge-mcp/tests/error-paths/ |
| AC-005 | TEST-005 | (Phase 2) | mcp/sdd-forge-mcp/tests/error-paths/ |
| AC-006 | TEST-006 | (Phase 2) | mcp/sdd-forge-mcp/tests/tools/ |
| AC-007 | TEST-007 | (Phase 2) | mcp/sdd-forge-mcp/tests/tools/ |
| AC-008 | TEST-008 | (Phase 2) | mcp/sdd-forge-mcp/tests/tools/, mcp/sdd-forge-mcp/tests/readonly/ |
| AC-009 | TEST-009 | (Phase 2) | mcp/sdd-forge-mcp/tests/tools/ |
| AC-010 | TEST-010 | (Phase 2) | mcp/sdd-forge-mcp/tests/tools/ |
| AC-011 | TEST-011 | (Phase 2) | mcp/sdd-forge-mcp/tests/no-secrets/ |
| AC-012 | TEST-012 | (Phase 2) | mcp/sdd-forge-mcp/tests/golden/ |
| AC-013 | TEST-013 | (Phase 2) | mcp/sdd-forge-mcp/tests/tools/ |
| AC-014 | TEST-014 | (Phase 2) | mcp/sdd-forge-mcp/tests/readonly/ |
| AC-015 | TEST-015 | (Phase 2) | mcp/sdd-forge-mcp/tests/tools/ |
| AC-016 | TEST-016 | (Phase 2) | mcp/sdd-forge-mcp/tests/smoke/ |
