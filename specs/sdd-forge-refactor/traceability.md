# Traceability: sdd-forge-refactor

## REQ → INV (問題根拠)

| REQ-ID | 根拠 INV | 説明 |
|--------|---------|------|
| REQ-001 | INV-001 | 2プラグインに同構造ロジックが分散（475行重複）→ sdd-review-loop に統合移動 |
| REQ-002 | INV-002 | Python ガードに Check 2e 不在 → JS/Python パリティ回復 |
| REQ-003 | INV-003 | validate-repository.ps1 $expectedSkills 15件 vs 実数17件 → 修正 |
| REQ-004 | INV-005 | sdd-bootstrap-interviewer がベア命令で呼び出し → サイレント no-op リスク修正 |
| REQ-005 | INV-006 | ユーザー向けドキュメントに内部スキル詳細が混在 → 2層分割 |
| REQ-006 | INV-002 | Python Check 2e のテストカバレッジなし → guard-parity Scenarios 追加 |

## REQ → ADR (設計決定根拠)

| REQ-ID | 関連 ADR | 決定内容 |
|--------|---------|---------|
| REQ-001 | ADR-001 | プラグイン統合ではなく移動。2スキルの差異が大きいため --phase 統合を却下 |
| REQ-001 | ADR-002 | 旧プラグインディレクトリを完全削除（stub なし）— validate-repository.ps1 との互換性 |
| REQ-001 | ADR-003 | PROTECTED_GATE_SUFFIXES の更新戦略（新パス追加→移動→旧パス削除）|
| REQ-001 | ADR-005 | sdd-review-loop を marketplace.json に登録しない（内部プラグイン方針）|
| REQ-002 | ADR-004 | Python 版 Check 2e は bare relative path 使用（_resolve_project_root() 不使用）|

## REQ → Task (実装対応)

| REQ-ID | Task-ID | フェーズ |
|--------|---------|---------|
| REQ-001 | T-002 Phase 2 | plugins/sdd-review-loop/ 作成 |
| REQ-001 | T-002 Phase 3 | sdd-bootstrap/sdd-bootstrap-interviewer caller 更新 |
| REQ-001 | T-002 Phase 4 | plugins/sdd-impl-review/ + sdd-task-review/ 削除 |
| REQ-002 | T-002 Phase 1 | Python Check 2e 追加（human/sudo）|
| REQ-003 | T-005 | validate-repository.ps1 $expectedSkills 15→17、$forbiddenPaths 追加 |
| REQ-004 | T-002 Phase 3 | sdd-bootstrap-interviewer L105/L111/L118/L119/L145/L150 更新 |
| REQ-005 | T-003 | 内部 SKILL.md に Caller ヘッダー追加 |
| REQ-005 | T-004 | docs/skill-reference.md + docs/workflow-guide.md 再構成 |
| REQ-006 | T-005 | guard-parity.tests.sh Scenarios 19/20/21 追加 |

## AC → REQ (受け入れ基準 → 要件)

| AC-ID | REQ-ID | 検証内容 |
|-------|--------|---------|
| AC-001 | REQ-001, REQ-004 | /sdd-bootstrap 実行時に新パス /sdd-review-loop:impl-review-loop が起動 |
| AC-002 | REQ-001 | hook guard が新パス plugins/sdd-review-loop/ 配下への書き込みを拒否 |
| AC-003 | REQ-001 | 旧パスへの書き込みが削除後に no-op または exit 2 |
| AC-004 | REQ-002 | Python ガードが verdict なし Impl-Review-Status: Passed を exit 2 で拒否 |
| AC-005 | REQ-002 | Python ガードが valid PASS verdict ありなら exit 0 で許可 |
| AC-006 | REQ-006 | guard-parity.tests.sh が 21 シナリオ全て pass |
| AC-007 | REQ-003 | validate-repository.ps1 が 17 件のスキルを正常検出 |
| AC-008 | REQ-001 | scenario.tests.sh + install.tests.sh が変更前後で同じ結果 |
| AC-009 | REQ-001 | 承認ガードが健在（BL-007 維持確認）|
| AC-010 | REQ-001 | install.sh --plugins sdd-bootstrap,sdd-ship で依存が auto-included |

## AC → BL (受け入れ基準 → ベースライン)

| AC-ID | BL-ID | 保持確認 |
|-------|-------|---------|
| AC-001 | BL-001, BL-002 | impl-review / task-review 自動起動 |
| AC-002 | BL-003, BL-004, BL-005, BL-006 | 新パスへの書き込みが hook guard で拒否 |
| AC-003 | BL-015, BL-016 | 旧パスは削除後 no-op（intentionally changed）|
| AC-006 | BL-009 | guard-parity 全シナリオ pass |
| AC-008 | BL-010, BL-011 | scenario + install テスト変化なし |
| AC-009 | BL-007 | Approval: Approved 書き換え拒否 |
| AC-010 | BL-012, BL-013 | install.sh auto-included + marketplace に sdd-ship |

## Task → 実装ファイル

| Task-ID | 変更ファイル | 変更種別 |
|---------|-----------|---------|
| T-002 Phase 1 | plugins/sdd-quality-loop/scripts/sdd-hook-guard.js | 追記（human/sudo）|
| T-002 Phase 1 | plugins/sdd-quality-loop/scripts/sdd-hook-guard.py | 追記 + Check 2e 追加（human/sudo）|
| T-002 Phase 2 | plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md | 新規作成 + パス参照更新 |
| T-002 Phase 2 | plugins/sdd-review-loop/skills/task-review-loop/SKILL.md | 新規作成 + パス参照更新 |
| T-002 Phase 2 | plugins/sdd-review-loop/agents/impl-reviewer-a.md | 新規作成 |
| T-002 Phase 2 | plugins/sdd-review-loop/agents/impl-reviewer-b.md | 新規作成 |
| T-002 Phase 2 | plugins/sdd-review-loop/agents/task-reviewer-a.md | 新規作成 |
| T-002 Phase 2 | plugins/sdd-review-loop/agents/task-reviewer-b.md | 新規作成 |
| T-002 Phase 2 | plugins/sdd-review-loop/scripts/impl-review-precheck.sh | 移植（sdd-impl-review/scripts/）|
| T-002 Phase 2 | plugins/sdd-review-loop/scripts/task-review-precheck.sh | 移植（sdd-task-review/scripts/）|
| T-002 Phase 2 | plugins/sdd-review-loop/templates/impl-review-contract.template.json | 移植 |
| T-002 Phase 2 | plugins/sdd-review-loop/templates/impl-review-report.template.md | 移植 |
| T-002 Phase 2 | plugins/sdd-review-loop/templates/task-review-contract.template.json | 移植 |
| T-002 Phase 2 | plugins/sdd-review-loop/templates/task-review-report.template.md | 移植 |
| T-002 Phase 2 | plugins/sdd-review-loop/references/phase-review-checklist.md | 新規作成 |
| T-002 Phase 3 | plugins/sdd-bootstrap/skills/sdd-bootstrap/SKILL.md | L88, L99 更新 |
| T-002 Phase 3 | plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md | L105/111/118/119/145/150 更新 |
| T-002 Phase 4 | plugins/sdd-impl-review/ | 完全削除 |
| T-002 Phase 4 | plugins/sdd-task-review/ | 完全削除 |
| T-002 Phase 5 | plugins/sdd-quality-loop/scripts/sdd-hook-guard.js | 旧6パス削除（human/sudo）|
| T-002 Phase 5 | plugins/sdd-quality-loop/scripts/sdd-hook-guard.py | 旧6パス削除（human/sudo）|
| T-002 Phase 5 | tests/validate-repository.ps1 | $forbiddenPaths 追加 |
| T-003 | plugins/sdd-implementation/skills/implement-task/SKILL.md | Caller ヘッダー追加 |
| T-003 | plugins/sdd-implementation/skills/implement-tasks/SKILL.md | Caller ヘッダー追加 |
| T-003 | plugins/sdd-quality-loop/skills/quality-gate/SKILL.md | Caller ヘッダー追加 |
| T-004 | docs/skill-reference.md | L3/L16-17/L786-788/L851-853 更新 + 分割 |
| T-004 | docs/contributor/skill-reference-detail.md | 新規作成 |
| T-004 | docs/workflow-guide.md | コンパクト化 |
| T-004 | docs/contributor/workflow-detail.md | 新規作成 |
| T-004 | plugins/sdd-quality-loop/references/wfi-category-guide.md | forbidden terms 追記 |
| T-005 | tests/guard-parity.tests.sh | Scenarios 19/20/21 追加 |
| T-005 | tests/validate-repository.ps1 | $expectedSkills 15→17 |
| T-005 | CHANGELOG.md | v0.15.x エントリ追加 |
