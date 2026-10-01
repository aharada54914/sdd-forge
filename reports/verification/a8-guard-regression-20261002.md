# A8 limited Copilot guard repair: local regression results

Observed on 2026-10-02 in the PR #513 owner worktree. These results supersede only the earlier application/test-pending statements for the guard repair; they do not change task approvals, statuses, historical reviews, or acceptance verdicts.

## Executed checks

- `git diff --check`: exit 0.
- `pwsh -NoProfile -File tests/guard-r10-port.tests.ps1`: exit 0; **83 passed, 0 failed**. Python, JavaScript, and PowerShell decisions agree for the tested native/legacy inputs, including protected writes, singleton envelope arrays, and nonfinite timestamps.
- `pwsh -NoProfile -File tests/hooks.tests.ps1`: exit 0; `Hook guard tests passed.` Existing approval, second-approval, protected-role, kill-switch, malformed-input, and hook-registration assertions passed.

Both PowerShell commands ran on macOS through `rtk proxy`. This is not native Windows execution. The commands completed in exec sessions 2989 and 83714, respectively; results were read from those existing sessions, not inferred from a prior run.

## Tested source hashes (SHA-256)

| File | Hash |
|---|---|
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` | `620ce25007bcbe7f6936e6985c9477f026bfc2881e8f55d67daed19420a132ad` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | `dd791f28d1f247c404197e3dbcc2960a664b18f4bc324fc1b967fbc4ee03e448` |
| `plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` | `433888e8afae4c414ea4dda8501ae98cb00b2ae330b3223d3d07b4d86f93aa6c` |
| `tests/guard-r10-port.tests.ps1` | `53e5b742b85c4a3d0cd88d4186e3288fd8fcbe7c98486d04a577fed84f04946e` |

## Independent code audit and supplemental diagnostic

On 2026-10-02, independent agent `a8_guard_review_oct02` inspected the applied
four-file diff and found no blocking code defect in the approved limited scope.
This was a code audit, not a formal SDD quality-gate verdict. The audit identified
missing direct suite coverage for some native argument and metadata branches.

The same agent then invoked the existing Python, JavaScript, and PowerShell guard
CLIs with read-only native `view` input: `[1,2]` view range was allowed; `[1,"2"]`,
missing sessionId, numeric cwd, and an extra view argument were denied. All 15
runtime/case combinations returned one parseable JSON decision, exit 0, and no
stderr. Exit 0 here means the guard returned its decision, not that the requested
operation was allowed. No files, canary, live Copilot session, or formal review
state were changed. These spot checks do not add persistent automated coverage
and do not establish native Windows or live host activation.

## Delivery boundary

This record accompanies a scoped checkpoint of the four tested files; checkpoint publication is not completion. Formal independent repair review, current-head CI, and actual Copilot handoff/activation have not been established by these tests. AC-003/AC-004 remain unverified. No reservation, review verdict, or task status was changed by this verification. Preserve the existing separate-repair scope and real-refusal boundary before any live retry.
