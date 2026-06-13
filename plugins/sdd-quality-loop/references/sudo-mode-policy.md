# Sudo Mode Policy

Sudo mode is a human-invoked, time-limited toggle that bypasses human approval
checkpoints while preserving all machine-enforced gates and audit trails.

## Scope: Gates Bypassed vs. Enforced

### Bypassed (Sudo Disables)

- **Approval: Approved gate**: The hook that prevents agents from writing
  `Approval: Approved` to tasks.md is bypassed. When an agent encounters a
  human-approval checkpoint during task implementation or quality review, it
  records `Approval: Approved (sudo <ISO8601 UTC>)` and continues.
- **Architecture review sign-off**: The quality-gate skill normally pauses for
  human sign-off on architectural decisions. Under sudo, the gate passes
  automatically after deterministic checks.
- **Quality-gate human decision steps**: Contract approval, critical review
  completion, and Done decision gates that normally require human input are
  auto-passed.

### Enforced (Sudo Never Disables)

- **AGENT_STOP kill switch**: If `AGENT_STOP` file exists at the project root,
  all tool calls are blocked. Sudo mode has zero effect on this.
- **Agent-role guard**: Agent role file validation (Codex `developer_instructions`
  check, agent policy enforcement) still applies and may reject the agent's
  continuation.
- **Deterministic gate scripts**:
  - `check-contract`: Verifies every required contract check has real evidence.
    May reject Done if evidence is missing or contract checks fail.
  - `check-placeholders`: Scans production files for stub/placeholder code.
    May reject Done if placeholders are detected.
  - `check-task-state`: Validates tasks.md state machine, IDs, blockers, and
    implementation report presence. May reject Done if validation fails.
  - `check-sdd-structure`: Validates SDD project structure (AGENTS.md, ADRs,
    review-tickets, etc.). May fail even with sudo active.

## Flag-File Format

The `SDD_SUDO` file is written to the project root (same directory as `AGENTS.md`)
by the `/sdd-sudo` skill and read by hook guards and skills.

### Syntax

```
enabled-by: human via /sdd-sudo
enabled-at: <ISO8601 UTC timestamp>
issued-epoch: <unix-seconds>
expires-epoch: <unix-seconds>
duration: <e.g. 8h>
```

### Validation

- All five lines are required. Missing any line renders the flag inactive.
- `issued-epoch` and `expires-epoch` are decimal integers (output of `date -u +%s` or
  `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()`).
- All four checks must pass: `issued-epoch <= now < expires-epoch` AND `expires-epoch - issued-epoch <= 86400` (24 hours).
- Symlink SDD_SUDO files are always invalid (even if contents are correct).
- Current time is checked as `if (now_unix_time > expires_epoch) { inactive }` or `if (issued_unix_time > now_unix_time) { inactive }`.
- TTL (time-to-live) is computed as `expires-epoch - issued-epoch` and must not exceed 86400 seconds (24 hours).
- The file is read by hook guards and quality-gate skill; no writing occurs
  outside `/sdd-sudo` invocation. Agents cannot create, edit, or delete SDD_SUDO.

## Audit Trail Requirements

Every gate passage under sudo mode must be recorded with `(sudo <ISO8601 UTC>)`
notation:

- In tasks.md: `Approval: Approved (sudo 2026-06-12T15:30:45Z)`
- In quality-gate report heading or footer: mention that approval gates were
  bypassed under sudo mode and the expiry time
- All supporting reports, contracts, and verification artifacts are retained as
  normal and attached to the Done decision

This ensures that historical record clearly identifies which sign-offs were
deferred and when they expire.

## Threat Model and Residual Risk

### Attack Scenarios

1. **Misbehaving agent writes its own SDD_SUDO**: An agent could theoretically
   create the flag file on its own to bypass approval gates indefinitely.
   - **Mitigation**: The skill explicitly forbids write-without-invocation in its
     hard policy. Hook guards and skill implementations check whether the agent
     explicitly invoked `/sdd-sudo` in the current session before accepting the
     flag. (In practice, a session-scoped invocation log or explicit human
     prompt verifies this.)

2. **Agent modifies or extends SDD_SUDO after human invocation**: The agent could
   extend the duration, update `expires-epoch`, or change `enabled-by`.
   - **Mitigation**: The flag is immutable after the initial `/sdd-sudo`
     invocation. Only `/sdd-sudo off` or manual file deletion may modify it.
     Hook guards validate the format strictly; malformed flags are treated as
     inactive.

3. **Token re-enablement after expiry**: An agent could attempt to invoke
   `/sdd-sudo` again to keep the flag alive indefinitely.
   - **Mitigation**: Each invocation of `/sdd-sudo` is a new human action and
     creates a fresh token with its own expiry. The skill's hard policy forbids
     automatic re-enablement. If the token has expired, the human must
     explicitly invoke `/sdd-sudo` again.

4. **AGENT_STOP and deterministic gates bypassed together**: Could a sufficiently
   misbehaving system bypass both sudo mode AND the kill switch?
   - **Mitigation**: The kill switch is checked independently in every hook entry
     point, before approval-gate logic runs. It cannot be disabled by sudo mode,
     which is logically separate. Deterministic scripts run in a separate process
     and cannot be suppressed by an in-memory flag.

### Residual Risk

- **Session isolation**: If sudo mode is enabled in one session and the flag
  file persists after the session ends, a different (possibly unrelated) session
  may inherit the token. **Mitigation**: Sudo mode has a hard expiry; the token
  becomes inactive after the specified duration regardless of who runs the agent.
- **Audit visibility**: If the `(sudo)` notation is lost or removed from tasks.md,
  historical record of the deferral is obscured. **Mitigation**: Quality-gate
  reports and contracts are immutable artifacts stored separately from tasks.md
  and serve as the authoritative record.

## Operational Guidance

### When to Use Sudo Mode

**Appropriate Use Cases:**

- Solo, low-risk work (e.g., documentation, comments, small refactoring).
- Working in a sandbox or personal branch where the team has agreed to defer
  review.
- Time-sensitive tasks where round-trip human review delay is unacceptable and
  deterministic gates are sufficient to catch errors.
- Testing the SDD workflow itself (dry-run mode).

**Inappropriate Use Cases:**

- Shared or production repositories where approval sign-off is a team control.
- Major architecture changes, dependency upgrades, security-sensitive work.
- When deterministic gates are not robust for the task type (missing evidence
  templates, incomplete contracts).

### Duration Recommendation

- **Default (8h)**: Suitable for a focused work session. Expires overnight.
- **Maximum (24h)**: For a full day's work span. Provides buffer for async team
  communication.
- **Shorter (1-2h)**: For isolated, high-confidence tasks. Minimizes exposure.

### Expiry Handling

- Sudo mode expires silently. Once the epoch passes, the next gate check finds
  the flag inactive.
- To manually disable before expiry, run `/sdd-sudo off` or delete `SDD_SUDO`.
- If a task needs more time, the human can invoke `/sdd-sudo` again (starting a
  fresh, audited token).

### Audit Review

After a task is approved and merged with `(sudo)` notation:

1. Verify the quality-gate report attests that deterministic gates passed.
2. Check the tasks.md Approval line to confirm the expiry time.
3. Confirm that no AGENT_STOP was present during the session.
4. Review the residual risk of deferring human sign-off for this specific change.

If deterministic gates gave sufficient confidence and the change was low-risk,
the audit is complete. If gates detected issues or risk is high, escalate for
post-hoc human review.

## Future Work

- **Signature-backed capability tokens**: Replace the plaintext SDD_SUDO file with a
  cryptographically signed token (issuer signature, nonce, repository binding, expiry).
  This would eliminate the risk of unauthorized token creation or extension within a
  single session.

## See Also

- `/sdd-sudo` skill: `plugins/sdd-quality-loop/skills/sdd-sudo/SKILL.md`
- Approval guard implementation: `plugins/sdd-quality-loop/hooks/` and
  `plugins/sdd-quality-loop/scripts/sdd-hook-guard.*`
- Deterministic check policy: `plugins/sdd-quality-loop/references/deterministic-check-policy.md`
