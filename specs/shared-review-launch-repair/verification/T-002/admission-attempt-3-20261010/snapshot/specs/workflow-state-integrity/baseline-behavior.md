# Baseline Behavior: workflow-state-integrity

| BL-ID | Trigger | Observable behavior before this change | Must preserve |
|-------|---------|----------------------------------------|---------------|
| BL-001 | Run task-review precheck with predecessor status not `Passed` | Precheck fails before reviewer execution. | yes |
| BL-002 | Run impl-review precheck with Spec status not `Passed` | Precheck fails before reviewer execution. | yes |
| BL-003 | Run `check-task-state` on a valid task file | Task approval, lifecycle, evidence, report, and critical two-person approval rules are validated. | yes |
| BL-004 | Run repository validation on current `main` | Packaging and release metadata are validated on all supported hosts. | yes |
| BL-005 | Run the shell and PowerShell gate suites | Both implementations produce equivalent pass/fail outcomes for covered scenarios. | yes |
| BL-006 | Install or uninstall supported plugin selections | Existing install/uninstall behavior and tests remain unchanged. | yes |

## Known invalid baseline

| BL-ID | Current behavior | Required change |
|-------|------------------|-----------------|
| BL-007 | Repository validation accepts a feature whose Task review is `Passed` while Spec and Impl reviews are `Pending`. | Reject unless the exact historical state is explicitly registered as legacy. |
| BL-008 | Quality gate can evaluate task state without proving the feature's upstream review chain. | Require workflow-state validation before task lifecycle validation. |
| BL-009 | A new spec directory can be added without a centrally auditable workflow profile. | Reject unregistered specification directories. |
| BL-010 | Historical missing review evidence is indistinguishable from accidental omission. | Record bounded legacy metadata without fabricating review evidence. |
