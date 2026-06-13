# Sudo Mode Policy

Sudo mode is a human-invoked, time-limited toggle that bypasses human approval
checkpoints while preserving all machine-enforced gates and audit trails.

## Scope: Gates Bypassed vs. Enforced

### Bypassed (Sudo Disables)

These are **routine approval gates** — human *sign-off waiting*, not judgment:

- **Approval: Approved gate**: The hook that prevents agents from writing
  `Approval: Approved` to tasks.md is bypassed. When an agent reaches the task
  sign-off checkpoint, it records `Approval: Approved (sudo <ISO8601 UTC>)` and
  continues.
- **Routine quality-gate sign-off**: Contract approval and the routine `Done`
  sign-off in `quality-gate` are auto-passed after deterministic checks succeed.
- **Accepted baseline-diff approval**: For `refactor`/`bugfix` work, a BL diff
  classified `accepted` (an intentional, task-described behavior change) is an
  approval checkpoint; under sudo it auto-passes with an `(sudo <ISO8601 UTC>)`
  mark and `baseline-behavior.md` is updated. A `fix-required` diff is never
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

### Human Judgment (Never Auto-Passed — Distinct From Approval)

Sudo eliminates *waiting on approval*; it never substitutes for *judgment* or
*workflow governance*. The following remain human-owned even under sudo and
form the second class of human touchpoint alongside the kill switch:

- **`requires_human_decision: true` review tickets**: genuine business/technical
  judgment. `fix-by-review-ticket` still stops; the agent defers to the human.
- **Architecture / auth / authz / breaking-API / security decisions**: ADR-level
  judgment. `implement-task` still goes `Blocked` and `sdd-bootstrap-interviewer`
  still records them as Open Questions; sudo does not let the agent decide them.
- **WFI (Workflow Improvement) approval**: setting a WFI `Status: Approved`
  changes the SDD workflow itself (governance), so `workflow-retrospective` still
  awaits a human even under sudo. A hook guard denies any agent edit that
  introduces `Status: Approved` in `docs/workflow-improvements/WFI-*.md`; unlike
  the tasks.md approval guard, it is never bypassed by sudo.

**Summary:** under sudo the only human touchpoints that remain are (1) genuine
judgment forks — where the agent stops (Blocked / Open Question) and defers — and
(2) the AGENT_STOP kill switch. All routine approval *waiting* is eliminated.

## Flag-File Format

The `SDD_SUDO` file is written to the project root (same directory as `AGENTS.md`)
by the `/sdd-sudo` skill and read by hook guards and skills.

### Syntax

```
enabled-by: human via /sdd-sudo
enabled-at: <ISO8601 UTC timestamp>
issuer: <string, no newlines — e.g. whoami@hostname>
nonce: <lowercase hex, >= 32 hex chars>
repo: <absolute canonical path of the project root that holds SDD_SUDO>
issued-epoch: <unix-seconds>
expires-epoch: <unix-seconds>
duration: <e.g. 8h>
sig: <lowercase hex HMAC-SHA256>
```

### Signing Key Location

The signing key lives **outside the repository working tree**, never inside it. Resolution
order (identical across all guard implementations):

1. Env var `SDD_SUDO_KEY` (non-empty) — key bytes are its UTF-8 bytes.
2. Else env var `SDD_SUDO_KEY_FILE` — read that file, strip trailing whitespace.
3. Else `<HOME>/.sdd/sudo-key` (where HOME = env `HOME` or `USERPROFILE`) — read + strip.
4. Else no key → token is inactive.

### Canonical String for Signing/Verification

The HMAC-SHA256 input is the following five values joined by a single LF (`\n`), with
no trailing newline:

```
<issuer>\n<nonce>\n<repo>\n<issued-epoch>\n<expires-epoch>
```

Epoch values are decimal integer strings (no leading zeros, no spaces). String values
are the stripped field values verbatim.

### Validation

All of the following must hold; if any check fails the flag is inactive (fail-closed):

1. File exists at the resolved project root, is a regular file, NOT a symlink.
2. All required fields present and non-empty: `issuer`, `nonce`, `repo`, `issued-epoch`,
   `expires-epoch`, `sig`.
3. `nonce` matches `^[0-9a-fA-F]{32,}$`.
4. `issued-epoch <= now < expires-epoch` AND `expires-epoch - issued-epoch <= 86400` (24 hours).
5. **Repo-binding**: the `repo` field (after stripping) equals the canonical realpath of
   the directory containing `SDD_SUDO`. Prevents cross-repo token reuse.
6. **Signature**: recomputed HMAC-SHA256 of the canonical string matches the `sig` field,
   using the resolved key. Verified constant-time in Python/Node; string-compare in PowerShell.
   If no key is resolvable, the flag is inactive.

The file is read by hook guards and quality-gate skill; no writing occurs
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

### What the Signature Defends Against

- **Forged/hand-written tokens**: An agent (or script) that writes a `SDD_SUDO` file
  with plausible epoch values cannot produce a valid `sig` field without the key.
  The guard rejects such tokens as inactive — approval gate stays enforced.
- **Committed or copied tokens**: A token committed to git or copied from another
  checkout fails repo-binding: the `repo` field will not match the canonical realpath
  of the current project root. Cross-repo reuse is rejected.
- **Stale/replayed tokens**: Expired tokens (now >= expires-epoch) are rejected even
  if the signature is valid. The nonce + issued-epoch combination prevents exact
  replay within the TTL window from being useful across different installations (the
  repo-binding check would also catch it).

### Attack Scenarios

1. **Misbehaving agent writes its own SDD_SUDO**: An agent could theoretically
   create the flag file on its own to bypass approval gates.
   - **Mitigation**: Without the signing key (which lives outside the repo), the
     agent cannot produce a valid `sig`. The guard rejects any unsigned or
     incorrectly-signed token as inactive — fail closed.

2. **Agent modifies or extends SDD_SUDO after human invocation**: The agent could
   attempt to extend `expires-epoch` or change other fields.
   - **Mitigation**: Modifying any signed field invalidates the HMAC; the guard
     rejects the altered token. The agent would need the key to re-sign, which
     it should not have write access to.

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

- **Key read access**: An agent that can read `~/.sdd/sudo-key` (or the relevant env
  var) can compute a valid HMAC and mint its own token. The signature raises the bar
  significantly — it blocks stale, committed, copied, and forged tokens — but it is
  **not** a defense against an attacker with full read access to the key material.
  Protect the key file accordingly (mode 600, outside the repo).
- **Session isolation**: If sudo mode is enabled in one session and the flag
  file persists after the session ends, a different session on the same machine
  with the same key may accept the still-valid token. **Mitigation**: Sudo mode has
  a hard TTL; the token expires at most 24 hours after issuance.
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

## See Also

- `/sdd-sudo` skill: `plugins/sdd-quality-loop/skills/sdd-sudo/SKILL.md`
- Approval guard implementation: `plugins/sdd-quality-loop/hooks/` and
  `plugins/sdd-quality-loop/scripts/sdd-hook-guard.*`
- Deterministic check policy: `plugins/sdd-quality-loop/references/deterministic-check-policy.md`
