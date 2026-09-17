# PR 404 current-head provenance investigation

Commit under CI: `65785e5d1f197cf47cac29497318f230b029f705`.
Run: https://github.com/aharada54914/sdd-forge/actions/runs/34562172288

All three basic jobs reject the same existing design provenance mismatch:

- macOS job `103147068442`, 2026-09-11T04:27:28Z.
- Windows job `103147068245`, 2026-09-11T04:27:30Z.
- Ubuntu job `103147068435`, 2026-09-11T04:27:43Z.

Diagnostic: `epic-195-a7-compatibility: stage-provenance: implementation design hash is stale`.
These jobs stop before the newly activated structural assertions. This does not
prove that every later CI step passes.

The latest persisted implementation contract (attempt 4, round 3) binds design
hash `ef0a43714f623e92ba7b5e2a583a53bc7dbcd4b8e2481b0df2aa96cef2fa2c96`.
Current design is `f4cbe691e6f11d8ae1424285007c1110e817ed677925591bd04725eb7187fc29`.
Its existing commit `95cd3a87` sanctions T-012's non-gating live-model integration.
The current repair does not revert that authorized design change or rewrite the
old review artifacts.

## New attempt, not an inherited PASS

The existing `--provenance-rereview` entry point successfully generated attempt 5,
round 1 precheck. `--verify-inputs` returned exit 0. Reviewer A's reservation
returned `REVIEW_CONTEXT_OK` at sequence 960, record
`148aab6212c2622d703c5997d1bca1549c8c3387c51f20c2c89b1f5d570d7e34`.
This is launch evidence only, not a review verdict, CI success, or Issue completion.
Independent reviews and downstream workflow validation remain pending.

Separately, the current-head skip-allowlist regression suites were rerun:
Bash 16 passed / 0 failed; PowerShell 16 passed / 0 failed. Expected negative
diagnostics are counted as successful rejection cases, not swallowed failures.
