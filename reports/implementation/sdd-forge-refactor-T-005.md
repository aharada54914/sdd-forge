# Implementation Report: T-005 (sdd-forge-refactor)

Task ID: T-005
Feature: sdd-forge-refactor
Risk: low
Required Workflow: acceptance-first
Requirements: REQ-003, REQ-006

## What was produced

- tests/guard-parity.tests.sh: parity_check_in() helper + Scenarios 19/20/21 (impl-review-status guard parity, JS vs Python)
- tests/validate-repository.ps1: $expectedSkills 15→17 (added sdd-bootstrap, sdd-ship); $forbiddenPaths: added plugins/sdd-impl-review and plugins/sdd-task-review
- CHANGELOG.md: v0.15.1 entry documenting sdd-forge-refactor changes

## Verification

- guard-parity.tests.sh: 21 passed, 0 failed (all 3 new scenarios pass)
- scenario.tests.sh: 19 passed, 0 failed
- install.tests.sh: 19 passed, 0 failed

## Done-When status

- [x] guard-parity.tests.sh が 21 シナリオで pass する (AC-006)
- [x] validate-repository.ps1 が 17 件のスキルを検出 (AC-007)
- [x] $forbiddenPaths に旧プラグインパスが含まれる
- [x] CHANGELOG に v0.15.x エントリがある
- [x] BL-009/010/011 が pass する
- [x] 実装レポート作成
- [ ] quality gate pass
