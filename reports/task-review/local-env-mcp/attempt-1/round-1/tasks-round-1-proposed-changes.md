# Task Review Round 1 — Proposed Changes: local-env-mcp

Verdict: NEEDS_WORK (findings: Critical 0 / Major 2 / Minor 0)

- Reviewer A (task-a-localenvmcp-a1r1-20260705-a175): PASS 14/14
- Reviewer B (task-b2-localenvmcp-a1r1-20260705-8bd7): NEEDS_WORK
  (TASK-SIZE Major, EDGE-CASE-COVERAGE Major)

Note: a first reviewer-B launch (task-b-localenvmcp-a1r1-20260705-6851)
self-aborted on a launch-boundary misreading (it re-ran
validate-review-context-set.sh after its own reservation and interpreted its
own ledger record as identity reuse). Its output is archived as
`reviewer-b.launch-1.aborted.json` / `invocation-b.launch-1.json`; no tasks.md
content was reviewed in that launch. The recorded reviewer-B verdict comes
from the fresh identity task-b2-… (ledger record 39).

## Finding 1 — TASK-SIZE (Major)

- T-002 bundled 3 tools + 4 test suites (10 Done When items).
- T-004 bundled OQ-001 spec research + install.sh core logic + Cursor and
  VS Code integrations (10 Done When items).

### Proposed change (applied)

Re-decompose 7 tasks into 10 single-concern tasks:

| New | Concern | ACs |
|---|---|---|
| T-001 | 基盤 + probe-engine + envelope(不変) | AC-004, AC-006 |
| T-002 | 3 ツール + server/index + 契約(ajv)+ no-exec | AC-001, AC-002, AC-003 |
| T-003 | stderr 診断ロガー(redaction)+ no-secrets 検査 | AC-005 |
| T-004 | esbuild バンドル + dist + CI + Inspector smoke | AC-007, AC-008 |
| T-005 | OQ-001 解消(Cursor / VS Code 設定形式の確定、design.md 更新) | — |
| T-006 | install.sh コア: 同梱・選択・Node<20 ゲート | AC-009 + Node<20 edge |
| T-007 | install.sh Cursor / VS Code 冪等登録 | AC-010, AC-011, AC-015 |
| T-008 | install.ps1 パリティ | AC-013 |
| T-009 | uninstall(sh / ps1) | AC-012 |
| T-010 | ドキュメント + traceability 最終化 | AC-014 |

Every high-risk task now has <= 8 Done When items and a single concern.

## Finding 2 — EDGE-CASE-COVERAGE (Major)

requirements.md Edge Cases の「Node < 20 → MCP_NODE_OK ゲートにより配置・
登録とも行わない」がどのタスクにも請け負われていなかった。

### Proposed change (applied)

T-006(install.sh コア)の Scope / Done When に「Node < 20 フェイク環境
(PATH 制御)で local-env-mcp を含む MCP の配置・登録が行われず警告が出る
ケース(tests/install.tests.sh、requirements.md Edge Cases 対応)」を追加。
T-008(ps1 パリティ)にも相当ケースを追加。

## Edit summary (for round 2 re-invocation)

"Split oversized T-002/T-004 into single-concern tasks (7 -> 10 tasks,
renumbered T-001..T-010, all Draft/Planned) and add explicit Node<20
MCP_NODE_OK gate coverage to installer tasks (T-006 sh / T-008 ps1).
traceability.md Task->REQ and AC->TEST->Task tables updated to match.
Edits applied by the orchestrating agent under the human-delegated
autonomous run (Issue #64); tasks remain Draft for human approval."
