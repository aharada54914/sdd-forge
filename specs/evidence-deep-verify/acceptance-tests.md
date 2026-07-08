# Acceptance Tests: evidence-deep-verify

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 整合バンドル(全 `artifacts[]` のディスク内容が記録 sha256 と一致、artifactsDigest recorded==onDisk、spec_revision 一致、全 crossBindings 一致、git_commit 40-hex)に対し `verdict: "pass"` かつ `failures: []` を契約準拠エンベロープで返す | REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-007 | TEST-001 | integration (golden fixture) | mcp/sdd-forge-mcp/tests/tools/ | Planned |
| AC-002 ある成果物のディスク上ファイルを 1 バイト改竄すると、当該成果物 `status: "mismatch"`(computedSha256 != recordedSha256)、`artifactsDigest.status: "mismatch"`、全体 `verdict: "fail"`、`failures` に当該 path が現れる | REQ-002, REQ-003, REQ-004 | TEST-002 | integration (tamper) | mcp/sdd-forge-mcp/tests/tools/ | Planned |
| AC-003 バンドルの記録 `artifacts[].sha256` を実ファイルと異なる 64-hex に書換えると、当該成果物 `status: "mismatch"`(computed != recorded)で `verdict: "fail"` | REQ-002, REQ-003 | TEST-003 | integration (tamper) | mcp/sdd-forge-mcp/tests/tools/ | Planned |
| AC-004 成果物パスがディスクに存在しない場合、throw せず当該 `status: "missing"` を報告し `verdict: "fail"` | REQ-002, REQ-003, REQ-011 | TEST-004 | integration (error-path) | mcp/sdd-forge-mcp/tests/error-paths/ | Planned |
| AC-005 成果物が path-guard の 2 MiB 上限を超える場合、当該 `status: "too-large"` を報告し throw しない(`verdict: "fail"`)。allowlist 外パスは `status: "path-denied"` | REQ-002, REQ-011 | TEST-005 | integration (error-path, oversize/denied fixture) | mcp/sdd-forge-mcp/tests/error-paths/ | Planned |
| AC-006 `specs/<feature>/{requirements,design,acceptance-tests}.md` のいずれかを改変して spec_revision がドリフトすると、`specRevision.status: "mismatch"`(computed に再計算値、filesHashed に連結ファイル)で `verdict: "fail"` | REQ-005, REQ-003 | TEST-006 | integration (drift) | mcp/sdd-forge-mcp/tests/tools/ | Planned |
| AC-007 `git_commit` が 40 桁小文字 16 進でない(欠落・短い・非 hex)場合、`gitCommit.shapeValid: false` で `verdict: "fail"` | REQ-006, REQ-003 | TEST-007 | unit | mcp/sdd-forge-mcp/tests/tools/ | Planned |
| AC-008 `git_commit` が整形式だが外部/未来コミット(40-hex かつ HEAD 祖先でない)の場合、`gitCommit.shapeValid: true`・`gitCommit.ancestryVerified: false`・`value` を echo・`reason` に host-deferred を明示し、祖先の真偽で verdict を上下させない。ツールは git サブプロセスを起動しない | REQ-006, REQ-008 | TEST-008 | integration + static (no-exec) | mcp/sdd-forge-mcp/tests/tools/, mcp/sdd-forge-mcp/tests/readonly/ | Planned |
| AC-009 `verification_contract` の task_id または feature が bundle と不一致の場合、該当 `crossBindings[]` が `status: "mismatch"`(detail に理由)で `verdict: "fail"` | REQ-007, REQ-003 | TEST-009 | integration | mcp/sdd-forge-mcp/tests/tools/ | Planned |
| AC-010 `quality_report` の `Task ID:` / `Feature:` が bundle.task_id / feature と不一致、または report が読めない場合、該当 `crossBindings[]` が `status: "mismatch"` で `verdict: "fail"` | REQ-007, REQ-003 | TEST-010 | integration | mcp/sdd-forge-mcp/tests/tools/ | Planned |
| AC-011 `signature`(hmac-sha256)を含むバンドルに対し `signature.present: true`・`alg` を echo・`verified: false` を返し、canary の鍵(`SDD_EVIDENCE_KEY` / ダミー `~/.sdd/evidence-key`)を設定しても応答・stderr に canary 値が現れず鍵ファイルが読まれない。署名の有無は verdict に寄与しない | REQ-008 | TEST-011 | integration (no-key / no-secret grep) | mcp/sdd-forge-mcp/tests/no-secrets/ | Planned |
| AC-012 リポジトリにコミット済みの実バンドル群に対し、deep-verify の per-artifact match/mismatch・artifactsDigest・spec_revision・git_commit 40-hex 形状・task_id/feature クロスバインド判定が `check-evidence-bundle.sh` の対応判定と一致する(署名暗号検証・git 祖先検証を除く) | REQ-009 | TEST-012 | golden (host-script parity) | mcp/sdd-forge-mcp/tests/golden/ | Planned |
| AC-013 同一入力(バンドル + ディスク状態)で `evidence_deep_verify` を 2 回呼ぶと `data` がバイト等価(決定論) | REQ-010 | TEST-013 | unit | mcp/sdd-forge-mcp/tests/tools/ | Planned |
| AC-014 静的 read-only / no-exec 検査: 追加コードに fs 書込み API(writeFile/appendFile/mkdir/rm 等)・`child_process` / `exec` / `spawn` / `eval`・署名鍵読取経路が 0 件で、ディスク読取が全て path-guard 経由であることが PASS | REQ-011, REQ-008 | TEST-014 | static (grep) | mcp/sdd-forge-mcp/tests/readonly/ | Planned |
| AC-015 応答が `contracts/sdd-forge-mcp-tools.v1.schema.json` の `evidenceDeepVerifyData` に適合し、既存 5 応答形状の適合が不変。不正 feature/taskId → `invalid-input`、バンドル欠落 → `not-found`、JSON 不正 → `cannot-parse` | REQ-012 | TEST-015 | unit + contract (ajv) | mcp/sdd-forge-mcp/tests/tools/ | Planned |
| AC-016 MCP Inspector CLI スモーク: `tools/list` に `evidence_deep_verify` が evidence の 6 番目のツールとして現れる | REQ-001, REQ-013 | TEST-016 | smoke | mcp/sdd-forge-mcp/tests/smoke/ | Planned |

## UI Integration Checklist

N/A — 本 feature はシェル UI(view / dialog / menu item / context action)を追加しない。
ユーザー接点は MCP ツール(AI クライアント経由)のみ。
