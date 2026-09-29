# Issue 137 Windows new-store checkpoint

Run ID: issue137-windows-store-local-20260930
Task: T-001; implementation remains In Progress.

The RED-only checkpoint is `88de4a38`. The implementation adds Windows dispatch to the existing shared store-preparation entrance, reuses validation before and after creation, and invokes a fixed PowerShell helper under the remaining original deadline. The helper supplies the current user's protected DACL at directory creation; an existing target is refused without permission repair. Opened handles are checked for reparse points, canonical path, owner, exact single-user access rule, and identity.

Actual checks on macOS:

- `rtk proxy node --experimental-vm-modules --test tests/sdd-context/*.test.mjs`: exit 0; 207 passed, 0 failed, 0 skipped. Includes the approved independently confirmed registry-owner checks and two synthetic Windows module tests.
- Focused synthetic Windows tests: 2 passed, 0 failed. Existing POSIX new-store tests: 5 passed, 0 failed.
- PowerShell AST parsing passed for the helper and native test. The literal C# block compiled on macOS without invoking Windows APIs.
- An independent ordinary code review found no concrete defect. This is not a formal implementation review, quality-gate decision, or native Windows proof.

The synthetic module suite requires `--experimental-vm-modules`; it is not evidence that an unflagged runner invokes those tests successfully. No CI registration is claimed here.

Still pending: actual Windows creation-time ACL and junction rejection, the real Node-to-PowerShell path including cold compilation within the unchanged 1,000 ms budget, complete T-001 acceptance, formal quality verification, CI, merge, and issue closure. The native PowerShell test calls the helper directly and does not prove the Node budget. Cold PowerShell compilation may cause the valid-input path to fail closed. No immunity to concurrent same-user ancestor replacement is claimed. No workflow, installer, frozen artifact, approval, or review verdict was changed by this checkpoint.
