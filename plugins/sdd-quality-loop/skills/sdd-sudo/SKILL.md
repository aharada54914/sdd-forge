---
name: sdd-sudo
description: Human-invoked toggle that lets the agent pass all human approval checkpoints without waiting, respecting AGENT_STOP and deterministic gates.
disable-model-invocation: true
---

# Sudo Mode

Human-invoked toggle that auto-passes routine human *approval* checkpoints (tasks.md `Approval: Approved`, routine quality-gate sign-off, `accepted` baseline-diff approval) with an expiring token. It never auto-passes genuine *judgment* (see "What Is NOT Bypassed").

## How to Turn It On (Quick Start)

Sudo mode is **human-only**: you type the command yourself; the agent can never
enable it. Three steps:

1. **Turn on** — type one command in your CLI (pick a duration, default 8h):

   ```txt
   /sdd-sudo            # 8 hours (default)
   /sdd-sudo 4h         # 4 hours
   /sdd-sudo 24h        # maximum
   ```

   This writes an expiring `SDD_SUDO` token at the project root and prints a
   banner showing exactly what is and is not bypassed and when it expires.

2. **Work** — the agent now passes routine approval *waiting* (task approval,
   `accepted` baseline diffs) automatically, recording an `(sudo <time>)` audit
   mark at each. Deterministic gates, the kill switch, and genuine judgment
   forks still stop it (see below).

3. **Turn off** — when done, or to end early:

   ```txt
   /sdd-sudo off        # delete the token now
   /sdd-sudo status     # check remaining time / expiry
   ```

   The token also expires on its own after the duration; nothing is left active.

> The agent cannot create, extend, or re-enable `SDD_SUDO`. If it ever claims
> sudo is on without you having typed `/sdd-sudo`, treat that as a bug.

## Usage

### Enable with Duration

```txt
/sdd-sudo [duration]
```

Default duration is 8 hours; maximum is 24 hours. Examples:

```txt
/sdd-sudo              # 8h default
/sdd-sudo 4h           # 4 hours
/sdd-sudo 1h30m        # 1 hour 30 minutes (parsed as duration)
/sdd-sudo 24h          # maximum
```

### Check Status

```txt
/sdd-sudo status
```

Reports whether sudo mode is active, remaining time, and expiry timestamp.

### Disable Immediately

```txt
/sdd-sudo off
```

Deletes the `SDD_SUDO` flag file and confirms.

## What Is Bypassed

Routine **approval** gates only (human sign-off *waiting*):

- `Approval: Approved` gate in tasks.md (routine task sign-off)
- Contract approval / routine `Done` sign-off in `quality-gate`
- `accepted` baseline-diff approval for `refactor`/`bugfix` work (intentional,
  task-described behavior change); update `baseline-behavior.md` and mark `(sudo)`

At each approval checkpoint, record `Approval: Approved (sudo <ISO8601 UTC>)` in
tasks.md and continue; the approval guard permits it.

## What Is NOT Bypassed (Always Enforced)

- **AGENT_STOP kill switch**: if `AGENT_STOP` file exists, all tools are blocked
  regardless of sudo mode status
- **Agent-role guard**: agent role file validation and constraints still apply
- **All deterministic gate scripts**: `check-contract`, `check-placeholders`,
  `check-task-state`, `check-sdd-structure` still run and may reject the task
- **Genuine human judgment (not approval)** — sudo never auto-passes these; the
  agent stops and defers to you:
  - `requires_human_decision: true` review tickets
  - architecture / auth / authz / breaking-API / security decisions (ADR-level)
  - WFI (Workflow Improvement) approval — it changes the workflow itself

Sudo mode replaces human *waiting on approval*, not quality *evidence* and not
human *judgment*. All automation and deterministic gates run as normal.

## Implementation

When `/sdd-sudo` is invoked with a duration:

1. Compute expiry epoch as `date -u +%s` + duration in seconds
   (PowerShell: `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()`)
2. Write a flag file `SDD_SUDO` at the project root (same directory as `AGENTS.md`)
   with exactly these lines:

```
enabled-by: human via /sdd-sudo
enabled-at: <ISO8601 UTC timestamp of invocation>
expires-epoch: <unix-seconds until expiry>
duration: <e.g. 8h>
```

3. Print a prominent banner stating:
   - What is bypassed (approval gates only)
   - What is NOT bypassed (kill switch, agent-role guard, deterministic gates)
   - Exact expiry time in human-readable form
   - How to disable (`/sdd-sudo off` or delete the file manually)

When `/sdd-sudo off` is invoked, delete the `SDD_SUDO` file and confirm.

When `/sdd-sudo status` is invoked, check for an active `SDD_SUDO` file. If
present and not expired, report remaining time and expiry. If expired or absent,
report inactive.

## Hard Policy

- The agent must **NEVER** create, modify, or extend `SDD_SUDO` unless the human
  explicitly invoked this skill in the current session
- Never re-enable after expiry on its own; the token is dead once the epoch passes
- If in doubt about the state or timing, ask the human before proceeding
- Always honor the `enabled-at` and `expires-epoch` fields exactly as written

## Audit Trail

When sudo mode is active and an approval checkpoint is reached:

1. Record `Approval: Approved (sudo <ISO8601 UTC>)` in tasks.md to audit the
   passage
2. Keep all normal quality-gate reports, contracts, and verification artifacts
3. The `(sudo)` notation serves as a permanent audit mark that human oversight was
   deferred

## Expiry Behavior

Sudo mode is stateless and time-based:

- The agent checks `expires-epoch` at each approval checkpoint
- If `current unix time > expires-epoch`, the flag is treated as expired and
  inactive
- Automatic expiry happens silently; no file deletion occurs
- To manually disable before expiry, use `/sdd-sudo off` or delete `SDD_SUDO`
  manually

See `plugins/sdd-quality-loop/references/sudo-mode-policy.md` for scope,
threat model, and operational guidance.
