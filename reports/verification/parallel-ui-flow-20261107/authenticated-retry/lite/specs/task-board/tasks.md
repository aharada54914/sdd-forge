# Tasks (lite): Task board

## T-001 Build and verify the local task board
Approval: Draft
Status: Planned

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
- Human review of requirements.md, design.md and this task is required. Only a human may change this task's Approval field to Approved. General authorization to create and test does not supply that task approval.
