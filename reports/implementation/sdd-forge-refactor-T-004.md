# Implementation Report: T-004 (sdd-forge-refactor)

Task ID: T-004
Feature: sdd-forge-refactor
Risk: low
Required Workflow: acceptance-first
Requirements: REQ-005

## What was produced

- docs/skill-reference.md: 1374→576 lines; sdd-impl-review/sdd-task-review → sdd-review-loop (L3, L16-17, L786-788, L851-853); internal skills moved to contributor/
- docs/contributor/skill-reference-detail.md: new (803 lines) — 14 internal skill descriptions
- docs/workflow-guide.md: 998→297 lines; sections 4/5/7/branch-protection moved to contributor/
- docs/contributor/workflow-detail.md: new (708 lines) — exception flows, retrospective, risk gate
- plugins/sdd-quality-loop/references/wfi-category-guide.md: sdd-review-loop added to forbidden terms

## Verification

- workflow-guide.md: 297 lines (< 450 ✓)
- README.md / USERGUIDE.md links to skill-reference.md / workflow-guide.md still valid (files preserved)

## Done-When status

- [x] skill-reference.md が L3/L16-17/L786-788/L851-853 で新プラグイン名を使用
- [x] docs/contributor/ が存在し skill-reference-detail.md を含む
- [x] workflow-guide.md が 450 行以内 (297 lines)
- [x] wfi-category-guide.md の forbidden terms に sdd-review-loop が含まれる
- [x] README と USERGUIDE のリンクが有効
- [x] 実装レポート作成
- [ ] quality gate pass
