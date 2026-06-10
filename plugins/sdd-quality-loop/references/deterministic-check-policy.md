# Deterministic Check Policy

Machine-verified gates that do not trust agent self-reports. All logic lives
in `scripts/` as paired POSIX shell (`.sh`) and PowerShell 5.1+ (`.ps1`)
implementations, so every gate runs the same way on Claude Code, Codex, or
any other CLI. The Claude Code `hooks/hooks.json` layer only automates what
can also be run manually.

## Default-FAIL Verification Contract

1. When quality-gate starts on a task, copy
   `templates/verification-contract.template.json` to
   `specs/<feature>/verification/<task-id>.contract.json`. Every check starts
   at `passes: false` with empty `evidence`.
2. A check may be flipped to `true` only after its verification command
   actually ran and its output was saved to a file (log, report, or
   screenshot) whose repository-relative path is written into `evidence`.
3. Mark checks that do not apply to the project as `"required": false` and
   record why in the quality-gate report. Never delete a check to pass.
4. Before any `Done` decision, run `scripts/check-contract.(sh|ps1)
   <contract>`. The gate fails closed: missing evidence files fail it.

## Required Scripted Gates

| Script | Purpose | When |
| --- | --- | --- |
| `check-placeholders` | Detect placeholder/stub/generic-fallback code in changed production files | Every quality-gate run |
| `check-task-state` | Validate the tasks.md state machine; `Done` requires a quality-gate report naming the task | Every quality-gate run |
| `check-contract` | Refuse Done while any required contract check fails or lacks evidence | Before the Done decision |

Run the `.sh` variants from POSIX shells (including Git Bash on Windows) and
the `.ps1` variants from PowerShell. Both behave identically.

## Smoke Run

When the project can be started (dev server, Docker, CLI binary), start it
and hit the main entry points touched by the task. Detect placeholder pages,
generic fallbacks, and error screens that unit tests miss. Save the output or
screenshots as evidence for the `smoke-run` check. If the project cannot be
started, set `smoke-run` to `"required": false` and record why.

## Claude Code Enforcement Layer

`hooks/hooks.json` wires two guards into `PreToolUse`:

- `kill-switch.sh`: while a human-created `AGENT_STOP` file exists at the
  project root, every tool call is blocked. Delete the file to resume.
- `guard-task-approval.sh`: blocks any edit that adds `Approval: Approved`
  to a tasks.md file. Only a human may approve, by editing the file outside
  the agent.

On Codex these hooks do not fire. The same invariants still hold because
`check-task-state` validates the resulting file state on every quality-gate
run, and the skills forbid self-approval. Treat the hooks as defense in
depth, not as the only line of defense.
