# A7 T-009 bounded Claude handoff

Checkout HEAD: `3a9141eece88695612831a82336e53a8688cb779`
Task: `specs/epic-195-a7-compatibility/tasks.md#T-009`
State: Approved / Implementation Complete, high risk, security-sensitive.

This is an engineering preflight, not an authorized formal evaluator launch.
Read the applicable AGENTS.md and the task's Must Read references before acting.
Do not reserve identities, change approval/status, edit frozen artifacts, modify
historical reports, commit, push, merge, or claim quality-gate PASS.
Use Sonnet only, shell through rtk with login disabled, no permission bypass.
Stop any operation genuinely refused by a guard; never use an alternate route.
Preserve unrelated changes and the three prior untracked verification reports.

## Already executed on this HEAD

Codex ran these on 2026-10-01 at approximately 06:11 Asia/Tokyo:

```text
rtk proxy env TZ=UTC LC_ALL=C bash tests/emit-run-record-feature-scope.tests.sh
exit 0; 54 passed, 0 failed
rtk proxy env TZ=UTC LC_ALL=C pwsh -NoProfile -File tests/emit-run-record-feature-scope.tests.ps1
exit 0; 58 passed, 0 failed
```

These are macOS Bash/PowerShell checks, not native Windows proof or formal QG.
Do not repeat them unchanged. The PowerShell count now includes four native
newline byte-guard assertions; historical 54/54 is not the current measurement.

## Bounded assignment

Inspect the actual emitter twins, their callers and existing contracts. Resolve
whether design.md:645-653's exhaustive two-axis table must explicitly exclude
invalid `--capability-block-id` input without enforcement. The production twins
already reject that input before writing output; both test suites now cover it.
The old implementation report has contradictory dated prose and stale Outputs
hashes. Treat it as historical claims, not permission to edit it or declare PASS.

Find existing review tickets, approved amendments and Post-Fix Artifacts records
for this exact issue before proposing another artifact. Report the smallest
remaining correction, exact file:line references, current hash mismatches, and
whether an existing authorized correction path can perform it. If an approval
or frozen boundary blocks it, report the exact boundary rather than inventing
an exception. No speculative refactor, new framework or later-task work.

Return a concise machine-verifiable handoff in a fresh task-only scratch
directory, with executed commands/exits and proposed patch if applicable.
Root Codex owns design judgment, formal gate orchestration and Git integration.

## Dispatch

Codex launched local `claude --model sonnet --effort medium -p` from this
checkout at 2026-10-01 06:20:30 Asia/Tokyo. Shell session: 18279; PID: 77287.
This invocation is read-only, with no Git, ledger, approval or frozen-file
mutation. It returns its correction proposal for Codex's final judgment.
The 06:25 quota-recovery automation was deleted after launch to prevent a
duplicate worker. Process launch is not successful completion or formal PASS.

## Result

Claude completed successfully as an engineering investigation, exit 0,
session `ee94f043-9b23-4c1a-aaa1-2ed608757f25`, actual model `claude-sonnet-5`.
It confirmed the already disclosed design-table/input-validation discrepancy;
no applicable T-009 repair ticket or Post-Fix Artifacts record was found.
Codex independently read the table and both production guards: Bash lines
109-116 and PowerShell lines 84-90. The proposed minimum is one note clarifying
that block-id without enforcement is rejected before the two-axis table.
This proposal is not an applied frozen-design amendment or a formal verdict.

Four Bash tool calls requested permission and did not execute. Current output
hashes were therefore not computed in this delegation. The worker repeated
two refused forms despite the stop instruction; future dispatch must explicitly
stop at the first denial instead of trying another shell form. No tracked
changes, ledger reservations, Git mutations, or test reruns were observed.
