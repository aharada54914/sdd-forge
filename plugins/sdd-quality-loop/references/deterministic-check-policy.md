# Deterministic Check Policy

Machine-verified gates that do not trust agent self-reports. All logic lives
in `scripts/` as paired POSIX shell (`.sh`) and PowerShell 5.1+ (`.ps1`)
implementations, so every gate runs the same way on Claude Code, Codex, or
Copilot CLI. The hook layer only automates what can also be run manually;
the deterministic scripts remain the final line of defense regardless of
whether hooks fire.

## Default-FAIL Verification Contract

1. When quality-gate starts on a task, copy
   `templates/verification-contract.template.json` to
   `specs/<feature>/verification/<task-id>.contract.json`. Every check starts
   at `passes: false` with empty `evidence`.
2. A check may be flipped to `true` only after its verification command
   actually ran and its output was saved to a file (log, report, or
   screenshot) whose repository-relative path is written into `evidence`.
   The evidence path must be within the repository root (path traversal
   sequences such as `../` are rejected).
3. Mark checks that do not apply to the project as `"required": false` and
   record the reason in `waiver_reason`. Never delete a check to pass. A
   non-required check with `passes: false` must have a non-empty
   `waiver_reason` — an empty string fails `check-contract`.
4. Before any `Done` decision, run `scripts/check-contract.(sh|ps1)
   <contract>` and `scripts/check-evidence-bundle.(sh|ps1) <bundle>`. The
   gates fail closed: missing evidence files or missing bundle artifacts fail
   them.
5. Duplicate check IDs within a single contract are rejected by
   `check-contract`.
6. The baseline required-set (`lint`, `unit-tests`, `build`,
   `placeholder-scan`, `task-state-check`) may not be removed from the
   template.
7. When a task is ready for `Done`, create
   `specs/<feature>/verification/<task-id>.evidence.json`. The bundle must
   name the `quality_report`, the `verification_contract`, and all passing
   evidence artifacts referenced by the contract.

## Required Scripted Gates

| Script | Purpose | When |
| --- | --- | --- |
| `check-risk` | Validate the task's `Risk:` tier + rationale, and (high/critical) `Required Workflow: tdd` | Every quality-gate run |
| `check-placeholders` | Detect placeholder/stub/generic-fallback code in changed production files | Every quality-gate run |
| `check-task-state` | Validate the tasks.md state machine; `Done` requires an evidence bundle naming the task | Every quality-gate run |
| `check-contract` | Refuse Done while any required (tier-minimum) contract check fails or lacks evidence | Before the Done decision |
| `check-traceability` | Validate REQ → AC → TEST → evidence chains (required for high/critical) | Before the Done decision |
| `check-evidence-bundle` | Validate the Done evidence bundle, report, contract, passing artifact hashes, and (high/critical) provenance + signature | Before the Done decision |

Run the `.sh` variants from POSIX shells (including Git Bash on Windows) and
the `.ps1` variants from PowerShell. Both behave identically.

### Risk-tiered enforcement

The task's `Risk:` tier selects which checks are mandatory, via the canonical
`risk-gate-matrix.md`. Each higher tier's required set is a superset of the one
below (non-downgradable):

- `low` → baseline set (`lint`, `typecheck`, `build`, `placeholder-scan`,
  `task-state-check`); `unit-tests` waivable with a reason.
- `medium` → adds `unit-tests`, `acceptance-tests`, `regression`.
- `high` → adds `requirement-traceability`, Red→Green `tdd` evidence, and
  evidence-bundle provenance (`spec_revision`, `build_env`,
  `review_verdict.verdict == PASS`).
- `critical` → adds an HMAC `signature` over a clean tree
  (`git_generated_dirty == true` is a hard fail) and a second distinct named
  approver (`check-task-state`, never sudo-bypassed).

**Legacy mode:** a contract/task with **no** `risk` field keeps the historical
behavior — only baseline-protection, no tier minimum. Absent is NOT mapped to
`medium`; tier enforcement is opt-in and activates only when `risk` is present,
so pre-feature contracts pass unchanged.

### check-placeholders Scope and Waivers

`check-placeholders` scans whatever path it is given — a file, or recursively a
directory — and has no Git-diff filtering of its own. The quality-gate skill is
therefore responsible for invoking it on **only the production files the task
changed**; passing a whole directory would also scan pre-existing markers in
untouched files and could block the task. Keep the caller scoped to changed files.

The scan is intentionally conservative: it flags ALL-CAPS `TODO`/`FIXME`/stub
markers and `raise NotImplementedError` / `panic("TODO")`-style bodies (marker
keywords match case-sensitively per RT-20260706-001; multi-word phrases stay
case-insensitive). `placeholder-scan` is **required at every risk tier and
cannot be waived** — `check-contract` enforces this: only the compile-check
set (`lint`, `typecheck`, `build`) may be `required: false` on a non-code
stack, and a `placeholder-scan` left at `passes: false` fails the contract
unconditionally (WFI-005 resolved the earlier waiver wording in this stricter
direction; the tool behavior itself never permitted the waiver). The remedy
for a finding — including a genuine false positive on a changed line, such as
prose that quotes a marker keyword — is to fix or reword the flagged content,
with that edit reviewed like any other change and the resolution recorded in
the quality-gate report. Pre-existing markers in files the task did NOT
change are handled by scoping (previous paragraph), not by waiving the check.
Do not weaken the scan itself to silence the prompt.

## Smoke Run

When the project can be started (dev server, Docker, CLI binary), start it
and hit the main entry points touched by the task. Detect placeholder pages,
generic fallbacks, and error screens that unit tests miss. Save the output or
screenshots as evidence for the `smoke-run` check. If the project cannot be
started, set `smoke-run` to `"required": false` and record why.

## Hook Enforcement Layer

The unified `sdd-hook-guard` script (`scripts/sdd-hook-guard.{sh,ps1,py}`)
is wired into `PreToolUse` across three runtimes:

- **Claude Code** — `hooks/hooks.json` registers it for `Edit|Write|MultiEdit|apply_patch`
  and a separate `kill-switch` entry for all tools (`*`).
- **Codex CLI** — reads the same `hooks/hooks.json` when the `plugin_hooks`
  feature flag is enabled. The `command_windows` field provides the PowerShell
  override. `apply_patch` payloads are intercepted via the `tool_input.command`
  field and processed by `sdd-hook-guard`.
- **Copilot CLI** — reads `hooks/copilot-hooks.json`, which emits a
  `permissionDecision` JSON response on stdout and fails safe (deny) when the
  guard script cannot be located. Known limitation: plugin-defined preToolUse
  hooks may not fire inside Copilot subagents.

The two enforced invariants are:

- **Kill-switch**: while a human-created `AGENT_STOP` file exists at the
  project root, every tool call is blocked. Delete the file to resume.
- **Approval guard**: blocks any edit that adds `Approval: Approved` to a
  tasks.md file. Only a human may approve, by editing the file outside the
  agent.

Treat the hooks as defense in depth (auxiliary line). `check-task-state`
validates the resulting file state on every quality-gate run, and the skills
forbid self-approval. The deterministic scripts are the final defense.

## Task-State Validation Rules

`check-task-state` enforces the following additional invariants:

- Duplicate task IDs within a `tasks.md` file are rejected.
- A task in `Implementation Complete` state must have a corresponding
  `reports/implementation/<task-id>.md` file.
- A task in `Blocked` state must have a non-empty `Blockers` field.
- A task in `Done` state must have a corresponding
  `specs/<feature>/verification/<task-id>.evidence.json` file.
- The evidence bundle must point at a `quality_report` containing `Task ID:
  T-NNN` and `VERDICT: PASS`, a verification contract that passes
  `check-contract`, and artifact entries for the contract plus every passing
  evidence path from the contract.
