# Baseline Behavior: sdd-forge-refactor

このファイルはリファクタリング開始前の観察可能な振る舞いを記録する。
`Must Preserve: yes` の項目はリファクタリング後もすべて成立しなければならない。

| BL-ID | Trigger | Observable Behavior | Evidence | Must Preserve | Verification Hint |
|-------|---------|---------------------|----------|---|---|
| BL-001 | `/sdd-bootstrap feature <url>` 実行時 Phase 1 完了後 | `/sdd-impl-review:impl-review-loop` が自動起動する | `sdd-bootstrap/SKILL.md:L88` | yes | `/sdd-bootstrap feature <url>` を実行し impl-review が起動することを確認 |
| BL-002 | `/sdd-bootstrap feature <url>` 実行時 Phase 2 準備後 | `/sdd-task-review:task-review-loop` が自動起動する | `sdd-bootstrap/SKILL.md:L99` | yes | 同上、task-review が起動することを確認 |
| BL-003 | エージェントが `plugins/sdd-impl-review/skills/impl-review-loop/SKILL.md` を編集しようとする | hook guard が exit 2 で拒否する | `sdd-hook-guard.js:PROTECTED_GATE_SUFFIXES:L150-151` | yes | `echo '{"tool_name":"Edit","tool_input":{"file_path":"plugins/sdd-impl-review/skills/impl-review-loop/SKILL.md",...}}' \| node sdd-hook-guard.js; [ $? -eq 2 ]` |
| BL-004 | エージェントが `plugins/sdd-impl-review/agents/impl-reviewer-a.md` を編集しようとする | hook guard が exit 2 で拒否する | `sdd-hook-guard.js:L148-149` | yes | 同様のガードテストで exit 2 確認 |
| BL-005 | エージェントが `plugins/sdd-task-review/skills/task-review-loop/SKILL.md` を編集しようとする | hook guard が exit 2 で拒否する | `sdd-hook-guard.js:L152-153` | yes | 同上 |
| BL-006 | エージェントが `plugins/sdd-task-review/agents/task-reviewer-a.md` を編集しようとする | hook guard が exit 2 で拒否する | `sdd-hook-guard.js:L154-155` | yes | 同上 |
| BL-007 | エージェントが `tasks.md` の `Approval: Draft` を `Approval: Approved` に書き換えようとする | hook guard が exit 2 で拒否する | `sdd-hook-guard.js:Check 1` | yes | `echo '...'Approval: Approved'...' \| node sdd-hook-guard.js; [ $? -eq 2 ]` |
| BL-008 | JS ガードで verdict なしに `Impl-Review-Status: Passed` を `design.md` に書こうとする | hook guard (JS) が exit 2 で拒否する | `sdd-hook-guard.js:L1086 implReviewStatusPassedIncreases` | yes | guard-parity Scenario 19（追加予定） |
| BL-009 | `bash tests/guard-parity.tests.sh` 実行 | 18 シナリオすべてが pass する | `tests/guard-parity.tests.sh` | yes | `bash tests/guard-parity.tests.sh; [ $? -eq 0 ]` |
| BL-010 | `bash tests/scenario.tests.sh` 実行 | 全シナリオが pass する | `tests/scenario.tests.sh` | yes | `bash tests/scenario.tests.sh; [ $? -eq 0 ]` |
| BL-011 | `bash tests/install.tests.sh` 実行 | 全テストが pass する | `tests/install.tests.sh` | yes | `bash tests/install.tests.sh; [ $? -eq 0 ]` |
| BL-012 | `bash install.sh --plugins sdd-bootstrap,sdd-ship --source-directory . --skip-plugin-install` 実行 | sdd-bootstrap,sdd-ship の依存プラグインが auto-included される | `install.sh` | yes | 出力に auto-included 行が含まれることを確認 |
| BL-013 | `python3 -m json.tool .claude-plugin/marketplace.json` 実行 | sdd-ship が visible プラグインとして含まれる | `.claude-plugin/marketplace.json` | yes | 出力 JSON に sdd-ship が含まれることを確認 |
| BL-014 | `/sdd-ship specs/<feature>/tasks.md` 実行時 | approved タスクを実装し quality-gate に引き渡す | `sdd-ship/SKILL.md` | yes | sdd-ship の正常フロー確認 |

## 変更が意図的に許容される振る舞い

| BL-ID | 変更内容 | 理由 |
|-------|---------|------|
| BL-015 | `plugins/sdd-impl-review:impl-review-loop` パスへの Write が hook guard で exit 2 になる（削除後） | 旧プラグインディレクトリを削除するため。新パス `plugins/sdd-review-loop:impl-review-loop` への保護に移行。 |
| BL-016 | `plugins/sdd-task-review:task-review-loop` パスへの Write が hook guard で exit 2 になる（削除後） | 同上 |
