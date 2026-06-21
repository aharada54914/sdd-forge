# Acceptance Tests: sdd-forge-refactor

各 AC は baseline-behavior.md の BL-xxx と対応する。
リファクタリング後も BL が保持されることを以下のテストで検証する。

| AC-ID | TEST-ID | 対応 BL | シナリオ | Pass 条件 | Fail 条件 |
|-------|---------|---------|---------|----------|----------|
| AC-001 | TEST-001 | BL-001, BL-002 | `/sdd-bootstrap feature <url>` を実行し、Phase 1 完了後に impl-review が、Phase 2 準備後に task-review が起動する | 新パス `/sdd-review-loop:impl-review-loop` と `/sdd-review-loop:task-review-loop` が実行される | 旧パスが参照される、またはいずれかが起動しない |
| AC-002 | TEST-002 | BL-003, BL-004, BL-005, BL-006 | 新パス `plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md` への Write を hook guard に通す | exit 2 で拒否される | exit 0 で通過する |
| AC-003 | TEST-003 | BL-003, BL-004, BL-005, BL-006 | 旧パス `plugins/sdd-impl-review/skills/impl-review-loop/SKILL.md` への Write を hook guard に通す（旧ディレクトリ削除後） | hook guard は存在しないファイルを無害に通過（exit 0）または存在チェック不要 | ガードが誤動作する |
| AC-004 | TEST-004 | BL-008 | Python ガード経由で verdict なしに `specs/foo/design.md` に `Impl-Review-Status: Passed` を書く | exit 2 で拒否される（INV-002 修正確認） | exit 0 で通過する |
| AC-005 | TEST-005 | BL-008 | 有効な PASS verdict ファイル（`reports/impl-review/foo/attempt-1/round-1/integrated-verdict.json` に `{"verdict":"PASS"}`）が存在する状態で同じ書き込みを行う | exit 0 で許可される | exit 2 で拒否される |
| AC-006 | TEST-006 | BL-009 | `bash tests/guard-parity.tests.sh` を実行する（Scenarios 19/20/21 が追加済みの状態） | 全 21 シナリオが pass する | いずれかのシナリオが fail する |
| AC-007 | TEST-007 | — | `pwsh tests/validate-repository.ps1` を実行する（$expectedSkills 修正後） | 17 件のスキルが検出され、スキル数チェックが pass する（INV-003 修正確認） | カウント不整合で fail する |
| AC-008 | TEST-008 | BL-010, BL-011 | `bash tests/scenario.tests.sh && bash tests/install.tests.sh` を実行する | すべてのシナリオが変更前後で同じ結果（pass）を返す | いずれかのシナリオが fail する |
| AC-009 | TEST-009 | BL-007 | エージェントが `Approval: Draft` → `Approval: Approved` の書き換えを試みる | hook guard が exit 2 で拒否する（承認ガード健在） | exit 0 で通過する |
| AC-010 | TEST-010 | BL-012, BL-013 | `install.sh --plugins sdd-bootstrap,sdd-ship --skip-plugin-install` と marketplace JSON 検証を実行する | auto-included ログが出力され、marketplace に sdd-ship が含まれる | いずれかが欠落する |
