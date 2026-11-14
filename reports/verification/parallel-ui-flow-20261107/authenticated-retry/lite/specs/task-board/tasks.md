# Tasks (lite): Task board

## T-001 Build and verify the local task board
Approval: Approved
Status: Done

### Scope
- Implement REQ-001 through REQ-006 using the files and data contract in design.md.
- Document local startup and test commands.
- Run browser acceptance checks and capture UI evidence.
- Run sdd-lite:lite-gate after implementation; record actual outcomes.

### Done When
- Tasks can be added, completed, reopened and deleted through the UI.
- Mutations survive page reload; empty and invalid input states behave as specified.
- Malformed or unavailable storage does not prevent session use and produces a visible warning.
- Keyboard and narrow viewport checks pass; task titles render as literal text.
- Browser test results, screenshot, implementation report and passing lite gate are recorded.

### Blockers
- Parent-set test permission is recorded in evidence/test-approval-fixture.json. This is disposable test permission, no application access-control requirement, and no proof of normal human approval. Other workflow guards remain active.
- Prior sandbox blocker resolved: this CLI context reran lint and browser tests successfully. See evidence/T-001/current-context/. Independent lite-gate is pending in a fresh parent-launched native CLI context.
