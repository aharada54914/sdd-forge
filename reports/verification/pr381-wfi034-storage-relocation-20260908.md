# PR381 WFI-034 storage-only relocation — 2026-09-08

Checkout: /Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908
Base: 3971c93a5705dc15f86ba56cc62118613e4b19db
Scope: recover the approved non-spec storage relocation recorded in pr381-ci-triage-20260906.md. No patch payload applied, gate relaxed, registry exception added, historical evidence rewritten, or formal status changed.

Moved three tracked files from specs/wfi-034-scratch-isolation/human-copy/ to docs/ci-staging/wfi-034-scratch-isolation/human-copy/. Updated four README command paths and one current reference in docs/workflow-improvements/WFI-034.md. Historical branch name, Draft status, and human-only application boundary remain unchanged. Removed only the two now-empty old directories with rmdir; files remain recoverable in Git and at their new paths.

## Review and integrity

Primary review: no Critical findings in the storage-only change; this is not an independent quality gate. Both patch payload hashes equal their pre-move hashes:

- WFI-034.patch: 7c119d189ac5be7407d8083e3bd0b328989417a8cbbe7dfb2fcea286f31c4df7
- WFI-034-test-fix.patch: c1a67bb2b5cfb64c007264ee5ec3a1e50767da17df2807cb7bf65480f85be97d

`rtk proxy rg -n 'specs/wfi-034-scratch-isolation' .`: exit 1, no remaining matches.
`rtk proxy git diff --check`: exit 0.

## Actual repository validation

Before relocation, `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh` exited 1 with `workflow-state: wfi-034-scratch-isolation: registry-unregistered-directory: specification directory is not registered`.

After relocation:

- Same Bash command: exit 0, `workflow-state: ok`.
- `rtk proxy pwsh -NoProfile -File plugins/sdd-quality-loop/scripts/check-workflow-state.ps1`: exit 0, `workflow-state: ok`.

Both runs retained the existing amendment-record-growth notices for epic-196-a8-integration and epic-195-a7-compatibility. This was macOS execution, not native Windows. The preceding invocation with a positional dot was invalid CLI usage, not a repository defect or test result.

## Remaining integration conditions

GitHub refresh still reports PR381 head 3971c93a with completed failed mandatory jobs, not running CI. These local changes are not pushed. Other CI failures, including bump-version registration, formal independent review/QG, and native CI verification remain. No commit, push, merge, issue closure, task Done, or WFI fully-applied claim made.
