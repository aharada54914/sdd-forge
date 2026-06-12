---
name: sdd-sudo
description: Human-invoked toggle that lets the agent pass all human approval checkpoints without waiting, respecting AGENT_STOP and deterministic gates.
disable-model-invocation: true
---

# Sudo Mode

Human-invoked toggle that bypasses human approval checkpoints (tasks.md `Approval: Approved`, architecture review sign-off, quality-gate human sign-off) with an expiring token.

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

- `Approval: Approved` gate in tasks.md (human sign-off requirement)
- Architecture review sign-off (when `quality-gate` normally waits for human approval)
- Quality-gate human decision steps (contract decision, review completion)

At each approval checkpoint, record `Approval: Approved (sudo <ISO8601 UTC>)` in
tasks.md and continue; the approval guard permits it.

## What Is NOT Bypassed (Always Enforced)

- **AGENT_STOP kill switch**: if `AGENT_STOP` file exists, all tools are blocked
  regardless of sudo mode status
- **Agent-role guard**: agent role file validation and constraints still apply
- **All deterministic gate scripts**: `check-contract`, `check-placeholders`,
  `check-task-state`, `check-sdd-structure` still run and may reject the task

Sudo mode replaces human WAITING, not quality EVIDENCE. All automation and
deterministic gates run as normal.

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
