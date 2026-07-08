# Traceability Addendum: evidence-deep-verify / T-006

Task ID: T-006 (ドキュメント + traceability 最終化)

Post-review artifact freeze: specifications in `specs/evidence-deep-verify/traceability.md` remain byte-immutable. This addendum records Verification Status for every REQ/AC/TEST/Task row, as per WFI-004 Post-review artifact freeze protocol.

## REQ → Layer Spec Verification

| REQ-ID | 根拠 | Layer Spec | 説明 | Verification Status | Verified By |
|-----|---|---|---|---|---|
| REQ-001 | Issue #68 スコープ | N/A — cross-layer only | 6 番目の read-only ツール evidence_deep_verify の追加・登録 | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-tool.test.ts, mcp/sdd-forge-mcp/tests/smoke/ |
| REQ-002 | Issue #68 スコープ | security-spec.md#trust-boundaries | per-artifact sha256 再計算とディスク突合(path-guard 経由) | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts, mcp/sdd-forge-mcp/tests/error-paths/deep-verify-error-paths.test.ts |
| REQ-003 | Issue #68 スコープ | N/A — cross-layer only | 全体 verdict(pass/fail)と failures 列挙 | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts |
| REQ-004 | host スクリプト evidence_canonical | N/A — cross-layer only | 正準 artifacts ダイジェスト不変条件(ADR-0009) | verified-by-test | mcp/sdd-forge-mcp/tests/golden/deep-verify-parity.test.ts |
| REQ-005 | host スクリプト compute_spec_revision | security-spec.md#trust-boundaries | spec_revision 不変条件(specs/<feature> 読取・ADR-0009) | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts |
| REQ-006 | Issue #68 スコープ / no-exec 境界 | security-spec.md#stride-analysis | git_commit 40-hex 検証・祖先 host-deferred(ADR-0008) | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts, mcp/sdd-forge-mcp/tests/readonly/deep-verify-static-check.test.ts |
| REQ-007 | host スクリプト task_id/feature 整合 | N/A — cross-layer only | contract/report クロスバインド不変条件 | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts |
| REQ-008 | Issue #68 最重要セキュリティ不変条件 | security-spec.md#trust-boundaries; security-spec.md#secrets-management | 署名鍵非読取・署名非検証の硬境界(ADR-0008) | verified-by-test | mcp/sdd-forge-mcp/tests/no-secrets/deep-verify-signature.test.ts, mcp/sdd-forge-mcp/tests/readonly/deep-verify-static-check.test.ts |
| REQ-009 | Issue #68 agreement 要件 | security-spec.md#security-tests | host スクリプトとの判定一致(ADR-0009) | verified-by-test | mcp/sdd-forge-mcp/tests/golden/deep-verify-parity.test.ts |
| REQ-010 | 品質規約(決定論) | infra-spec.md#service-level-objectives | 決定論(同一入力 → 同一出力) | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-determinism.test.ts |
| REQ-011 | sdd-forge-mcp 基盤踏襲 | security-spec.md#trust-boundaries | path-guard 再利用・例外安全(欠落/巨大/denied) | verified-by-test | mcp/sdd-forge-mcp/tests/error-paths/deep-verify-error-paths.test.ts |
| REQ-012 | sdd-forge-mcp 契約規約 | N/A — cross-layer only | evidenceDeepVerifyData の加算的追加 | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts |
| REQ-013 | AGENTS.md 品質規約 | frontend-spec.md#testing | node:test / 静的 read-only 検査の踏襲 | verified-by-test | mcp/sdd-forge-mcp/tests/readonly/deep-verify-static-check.test.ts |

## AC → REQ Verification

| AC-ID | REQ-ID | 検証内容 | Verification Status | Verified By |
|-----|---|---|---|---|
| AC-001 | REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-007 | 整合バンドル → pass | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts |
| AC-002 | REQ-002, REQ-003, REQ-004 | 成果物 1 バイト改竄 → mismatch + fail | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts |
| AC-003 | REQ-002, REQ-003 | 記録ハッシュ改竄 → mismatch | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts |
| AC-004 | REQ-002, REQ-003, REQ-011 | 成果物欠落 → missing(throw しない) | verified-by-test | mcp/sdd-forge-mcp/tests/error-paths/deep-verify-error-paths.test.ts |
| AC-005 | REQ-002, REQ-011 | 2 MiB 超 → too-large / allowlist 外 → path-denied | verified-by-test | mcp/sdd-forge-mcp/tests/error-paths/deep-verify-error-paths.test.ts |
| AC-006 | REQ-005, REQ-003 | spec_revision ドリフト → mismatch | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts |
| AC-007 | REQ-006, REQ-003 | git_commit 非 40-hex → 形状不正で fail | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts |
| AC-008 | REQ-006, REQ-008 | 外部 40-hex → ancestry 未検証・git 不起動 | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts, mcp/sdd-forge-mcp/tests/readonly/deep-verify-static-check.test.ts |
| AC-009 | REQ-007, REQ-003 | contract クロスバインド不一致 → mismatch | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts |
| AC-010 | REQ-007, REQ-003 | report クロスバインド不一致 → mismatch | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts |
| AC-011 | REQ-008 | 署名 present/verified:false・鍵非読取・canary 非漏えい | verified-by-test | mcp/sdd-forge-mcp/tests/no-secrets/deep-verify-signature.test.ts |
| AC-012 | REQ-009 | host スクリプトとの判定一致(ゴールデン) | verified-by-test | mcp/sdd-forge-mcp/tests/golden/deep-verify-parity.test.ts |
| AC-013 | REQ-010 | 決定論(2 回呼び出しバイト等価) | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-determinism.test.ts |
| AC-014 | REQ-011, REQ-008 | 静的 read-only / no-exec / 鍵読取経路 0 件 | verified-by-test | mcp/sdd-forge-mcp/tests/readonly/deep-verify-static-check.test.ts |
| AC-015 | REQ-012 | evidenceDeepVerifyData 契約適合・エラーエンベロープ | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts |
| AC-016 | REQ-001, REQ-013 | tools/list スモーク(evidence 6 番目) | verified-by-test | mcp/sdd-forge-mcp/tests/smoke/ |
| AC-017 | REQ-002, REQ-003, REQ-011 | 非 64-hex 記録 sha → invalid-recorded-sha + fail | verified-by-test | mcp/sdd-forge-mcp/tests/error-paths/deep-verify-error-paths.test.ts |
| AC-018 | REQ-002, REQ-003, REQ-004, REQ-011 | 空 artifacts[] → 空集合 digest 比較で pass/fail | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts |
| AC-019 | REQ-005, REQ-003, REQ-011 | 全 spec 不在 spec_revision="" の match/mismatch | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts |

## Task → REQ Verification

| Task-ID | REQ-ID | 内容 | Verification Status | Verified By |
|---|-----|---|---|---|
| T-001 | REQ-002, REQ-003, REQ-004, REQ-011 | per-artifact 再計算エンジン(6 ステータス分類 + 正準 artifacts ダイジェスト) | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts, mcp/sdd-forge-mcp/tests/error-paths/deep-verify-error-paths.test.ts |
| T-002 | REQ-005, REQ-006, REQ-007 | 内部不変条件再計算(spec_revision / git_commit 形状 / cross-binding) | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts |
| T-003 | REQ-008 | 署名境界(no-key / no-verify)+ 静的 read-only 検査 | verified-by-test | mcp/sdd-forge-mcp/tests/no-secrets/deep-verify-signature.test.ts, mcp/sdd-forge-mcp/tests/readonly/deep-verify-static-check.test.ts |
| T-004 | REQ-001, REQ-012 | evidence_deep_verify ツール登録と統合応答(エラーエンベロープ写像含む) | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-tool.test.ts |
| T-007 | REQ-012 | evidenceDeepVerifyData 契約加算(v1 後方互換) | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts |
| T-008 | REQ-010, REQ-013 | 統合検証(決定論・tools/list スモーク)と dist 再ビルド | verified-by-test | mcp/sdd-forge-mcp/tests/tools/deep-verify-determinism.test.ts, mcp/sdd-forge-mcp/tests/smoke/ |
| T-005 | REQ-009 | host スクリプト判定一致ゴールデン(parity) | verified-by-test | mcp/sdd-forge-mcp/tests/golden/deep-verify-parity.test.ts |
| T-006 | REQ-001, REQ-013 | ドキュメント + traceability 最終化 | verified-by-documentation | README.md, USERGUIDE.md, implementation report |

## Notes

- すべてのテストは mcp/sdd-forge-mcp/tests/ 配下に実装されており、`npm test` で実行可能です
- T-001〜T-008 は Implementation Complete 状態で、全テストが green であることを確認済み
- REQ/AC/TEST の全行が実装済みテストファイルにマッピングされています
- T-006（本タスク）はドキュメント更新のため、README.md と USERGUIDE.md の更新により Verification Status を「verified-by-documentation」と記録します
