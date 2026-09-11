# Issue295: unPR duplicate selection and blocked runtime probe

## Exact sources

Live remote heads checked on 2026-09-09:

- `auto/improve-20260817`: f6e7427c9648085ca86a0d0835fa28df8e5ff300
- `auto/improve-20260831`: 32a81f5ebe3b71d72ef274c7bc3776b6db12a70c
- main: 4366438f3b243210a4ece5a17f873ca2d920600a

Each auto branch has one commit outside main. Both full commit diffs were
read. Both change precisely the Python command branch from raw regex matching
to `count(cmd) > 0`, and the PowerShell twin to `(Get-Count $command) -gt 0`.
They are duplicate production fixes with different comments and test additions,
not two independent features. Neither branch should be merged wholesale over
current main or deleted as already delivered.

The inspected local Python still uses `APPROVAL_RE.search(cmd)` at line 547;
Node uses `countApprovals(command) > 0` at line 1327. This is source evidence,
not a measured current protection verdict or proof of the full issue's closure.

## Regression selection

The August17 variant checks Copilot exit 0 and the English Second Approval
reason for Python and Node, and exit 0 plus reason for PowerShell. The August31
variant swallows Python subprocess failure with `|| true` and checks only a
Japanese substring; its new PowerShell assertion also omits the exit check.
Use August17's stronger assertion intent as the starting point, but do not
copy its early-exit grep pipelines into this pipefail-sensitive repository.
Neither new variant explicitly parses the structured deny decision. A repaired
regression must assert exit, parsed decision, and exact reason class, alongside
primary-only and mixed primary/secondary controls and runtime parity. Existing
sudo-denial tests must remain; no sudo flag or enforcement change was applied.

## Actual runtime attempt

A direct Node orchestrator was submitted to feed the synthetic bash command
`echo "Second Approval: Approved" >> tasks.md` as JSON stdin to each original
Python, Node and PowerShell guard in Copilot output mode. It did not execute
the command string. The host rejected the orchestration before execution:

> Command blocked by PreToolUse hook: SDD deterministic gate: agents must not
> modify gate scripts, hook configuration, or critical test files. These are
> part of the enforcement chain and cannot be bypassed by sudo.

There are NO runtime results from that attempt. In particular this is not a
test FAIL in the product, not evidence of three guard denials, and not a red
feedback loop. Per `diagnose` Phase1's stop condition, no fix/hypothesis-testing
or encoded/renamed retry was performed. Source comparison is complete; dynamic
diagnosis requires an admitted original-guard invocation or human execution.

## Remaining issue scope

Live issue295 also lists CI wiring, installer tar exit handling and two document
links. Its historical statement that a corresponding PR fixed the guard does
not establish main delivery: both inspected fixes remain outside main. Keep
the issue open until each outstanding finding is resolved or explicitly mapped
to its existing issue/PR, and the guard repair clears approved formal review,
regressions and mandatory CI. No task approval or review verdict changed.
