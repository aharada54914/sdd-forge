# Caller transport regression recheck

This is a caller-side test observation, not a formal review or native activation verdict.

The primary agent reran `rtk proxy node --test handoffs/t004-fresh-01a107c3-2a6f-75b3-8704-56d694e60af4/caller-verification/native-controller.test.mjs handoffs/t004-fresh-01a107c3-2a6f-75b3-8704-56d694e60af4/caller-verification/native-audit.test.mjs` in the A8 owner worktree with `login=false`.

- Before the RPC-correlation repair: 13 passed, 1 failed; the new correlated initialize/allocation assertion observed 0 replies instead of 2.
- After the repair: exit 0, 14 passed, 0 failed, 0 skipped. The previously failing response/event coexistence test passed.
- Native process initialization, allocation and formal review remain unverified. The role-read refusal is recorded separately in `role-read-refusal-20261005.md`; no alternate route was used to read the denied role files.

These synthetic tests establish transport/audit behavior only. They do not establish installed-hook activation, task completion, CI or merge readiness.
