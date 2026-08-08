# Drift note: implement-task Blockers 追記 vs. task-review-precheck.sh の Blockers 文法

**Discovered**: 2026-07-28, feature `epic-189-a1-project-context`,
task-review attempt-2 (Post-Implementation Provenance Re-Review) precheck.

**Symptom**: `task-review-precheck.sh` STEP 3 は各 `### Blockers` 見出し直後の
最初の非空行のみを機械可読値として読み、`None` または `T-NNN(,T-NNN)*` の
厳密な文法を要求する (`record_blockers`, lines ~380-401)。implement-task
セッション (commits `4bd2ec3b` / `1018c10b` / `2f8f3243`) は T-001/T-002/T-004
の Blockers 節でこの機械可読行を prose（BLOCKED 記録・"T-001 (satisfied …)"
等)で上書き/置換したため、attempt-2 precheck が
`Blockers has invalid format` で fail した。

**Repair applied** (2026-07-28, task-review attempt-2 直前):
task-review PASS 時点 (38d525f1) の機械可読値 — T-001 `None` / T-002 `T-001`
/ T-004 `T-003` — を各節の先頭行として復元し、implement-task の prose は
一字も変えず直下（空行1つ挟む)へ移動。依存グラフはレビュー済み状態と
同一に戻り、情報損失ゼロ。Approval / Status 行は未接触。

**Upstream fix candidate** (未着手): implement-task SKILL の Block-And-Stop
手順が Blockers 節へ記録を追加する際、「機械可読の先頭行を保持し、その
下に prose を追記する」ことを明文化する（task-review-precheck.sh の文法は
変更しない)。
