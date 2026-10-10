# PR 513 Node 14 compatibility verification

Date: 2026-10-02 JST

Human-applied source: `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js`
SHA-256: `fa3cc8cad5661f8fbc6ee313fd8982762392adb3f08dd2ed13c736f985ccab0f`
Base HEAD / GitHub PR head: `3a06933f6f9b5f51781dca4dc4c0f40b94f6382f`

The production diff replaces seven calls to `Object.hasOwn` with
`Object.prototype.hasOwnProperty.call`. No protection decision is removed.

## Executed checks

- `rtk proxy bash tests/guard-parity.tests.sh`: exit 0; 110 passed, 0 failed.
- `rtk proxy pwsh -NoProfile -File tests/hooks.tests.ps1`: exit 0; Hook guard tests passed.
- `rtk proxy pwsh -NoProfile -File tests/guard-r10-port.tests.ps1`: exit 0; 83 passed, 0 failed, including native Copilot argument validation across three implementations.
- `rtk proxy git diff --check`: exit 0.
- `reports/verification/pr513-node14-runtime-check.cjs`: exit 0; 18 passed, 0 failed under actual Node 14.21.3 on Linux. It asserts the runtime version and absence of `Object.hasOwn`; exercises native view/create, malformed/mixed/batch payloads, protected writes, approval increases, and legacy reads. Each guard subprocess must return exit 0 and exactly one parseable JSON decision matching the expected result.

Runtime command (replace OWNER_WORKTREE with the checkout path):

```sh
rtk proxy docker run --rm --network none --read-only \
  --mount type=bind,source=OWNER_WORKTREE,target=/repo,readonly \
  node@sha256:0f5b374fae506741ff14db84daff2937ae788e88fb48a6c66d15de5ee808ccd3 \
  node /repo/reports/verification/pr513-node14-runtime-check.cjs
```

Host Node was v24.13.0. Native macOS Node 14 acquisition was unsuccessful:
the npm arm64 version was unavailable and x64 attempts were incompatible with
the host. The existing stopped Colima VM was started for the isolated Linux test.
The container had networking disabled and the checkout mounted read-only.
After verification, Colima was stopped and the Docker context restored to
`default`, matching the initial state.

Independent ordinary code review by `pr513_node14_review_oct02` found no
actionable findings in the seven replacements and the runtime harness.
The reviewer inspected source only; this is not a formal SDD gate or a second
execution of the tests.

A preliminary `rg` command was rejected by PreToolUse; it was not rerouted.
The separately invoked existing test drivers were allowed and completed.

## Remaining boundaries

These are synthetic guard runtime checks, not installed Copilot/Claude/Codex
activation or A8 live handoff proof. PowerShell ran on macOS, not Windows.
At evidence capture, formal review, quality gate, current-change CI,
commit/push, merge and postmerge checks remained pending. The successful base
PR head is not evidence for this fix. No task status, approval, or formal
review verdict was changed.
