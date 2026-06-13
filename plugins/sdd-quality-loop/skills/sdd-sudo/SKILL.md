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

1. **Ensure a signing key exists.** The guard verifies every token with a key
   stored outside the repo. Resolve the key in this order (same as the guard):
   - If `SDD_SUDO_KEY` env var is set and non-empty, use it directly.
   - Else if `SDD_SUDO_KEY_FILE` env var is set, use that file.
   - Else use `<HOME>/.sdd/sudo-key` (where `HOME` = env `HOME` or `USERPROFILE`).

   If `<HOME>/.sdd/sudo-key` does not exist and neither env var is set, create it:

   **POSIX:**
   ```sh
   mkdir -m 700 -p ~/.sdd
   openssl rand -hex 32 > ~/.sdd/sudo-key
   chmod 600 ~/.sdd/sudo-key
   # Alternative (no openssl):
   head -c32 /dev/urandom | xxd -p -c64 > ~/.sdd/sudo-key && chmod 600 ~/.sdd/sudo-key
   ```

   **PowerShell:**
   ```powershell
   $sddDir = Join-Path $env:USERPROFILE ".sdd"
   if (-not (Test-Path $sddDir)) { New-Item -ItemType Directory -Path $sddDir | Out-Null }
   $keyBytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
   $keyHex = -join ($keyBytes | ForEach-Object { $_.ToString("x2") })
   # Write WITHOUT a BOM: Set-Content -Encoding Utf8 on Windows PowerShell 5.1
   # prepends a UTF-8 BOM, which the Node/Python guards would fold into the HMAC
   # key bytes and reject every token. UTF8Encoding($false) emits no BOM.
   [System.IO.File]::WriteAllText((Join-Path $sddDir "sudo-key"), $keyHex, (New-Object System.Text.UTF8Encoding($false)))
   # Restrict permissions where supported (no-op on Windows ACLs):
   if ($IsLinux -or $IsMacOS) { chmod 600 (Join-Path $sddDir "sudo-key") }
   ```

2. **Compute token fields:**
   - `issued-epoch` = now (unix seconds)
   - `expires-epoch` = now + duration in seconds (default 8h = 28800; max 24h = 86400)
   - `nonce` = 32 random bytes as lowercase hex (≥ 64 hex chars)
   - `issuer` = `whoami@hostname` (or similar; no newlines)
   - `repo` = canonical absolute path (realpath) of the project root that will hold `SDD_SUDO`

3. **Compute the HMAC-SHA256 signature** over the canonical string:

   ```
   <issuer>\n<nonce>\n<repo>\n<issued-epoch>\n<expires-epoch>
   ```

   (Five values joined by a single LF `\n`; NO trailing newline. Epoch values are
   decimal integer strings with no leading zeros.)

   **POSIX (openssl):**
   ```sh
   CANONICAL="$(printf '%s\n%s\n%s\n%s\n%s' "$ISSUER" "$NONCE" "$REPO" "$ISSUED" "$EXPIRES")"
   SIG=$(printf '%s' "$CANONICAL" | openssl dgst -sha256 -hmac "$KEY" -hex | awk '{print $2}')
   # Or using Python:
   SIG=$(python3 -c "import os,hmac,hashlib,sys; key=open(os.path.expanduser('~/.sdd/sudo-key')).read().strip().encode(); msg=sys.stdin.buffer.read(); print(hmac.new(key, msg, hashlib.sha256).hexdigest())" <<< "$CANONICAL")
   ```

   **PowerShell:**
   ```powershell
   $canonical  = ($issuer, $nonce, $repoPath, [string]$issuedEpoch, [string]$expiresEpoch) -join "`n"
   $keyBytes   = [System.Text.Encoding]::UTF8.GetBytes($key)
   $msgBytes   = [System.Text.Encoding]::UTF8.GetBytes($canonical)
   $hmacObj    = New-Object System.Security.Cryptography.HMACSHA256(,$keyBytes)
   $sig        = -join ($hmacObj.ComputeHash($msgBytes) | ForEach-Object { $_.ToString("x2") })
   $hmacObj.Dispose()
   ```

4. **Write the `SDD_SUDO` file** at the project root with exactly these fields:

   ```
   enabled-by: human via /sdd-sudo
   enabled-at: <ISO8601 UTC timestamp of invocation>
   issuer: <issuer string>
   nonce: <lowercase hex, ≥ 64 chars>
   repo: <canonical absolute path of the project root>
   issued-epoch: <unix-seconds>
   expires-epoch: <unix-seconds>
   duration: <e.g. 8h>
   sig: <lowercase hex HMAC-SHA256>
   ```

5. Print a prominent banner stating:
   - What is bypassed (approval gates only)
   - What is NOT bypassed (kill switch, agent-role guard, deterministic gates)
   - Exact expiry time in human-readable form
   - How to disable (`/sdd-sudo off` or delete the file manually)
   - That the token is cryptographically signed and will be rejected without the key

When `/sdd-sudo off` is invoked, delete the `SDD_SUDO` file and confirm.

When `/sdd-sudo status` is invoked, check for an active `SDD_SUDO` file. If
present, not expired, signature valid, and key resolvable, report remaining time
and expiry. If the signature is missing or invalid, the key is absent, the token
is expired, or the file is absent, report inactive (and why if possible).

## Hard Policy

- The agent must **NEVER** create, modify, or extend `SDD_SUDO` unless the human
  explicitly invoked this skill in the current session
- Never re-enable after expiry on its own; the token is dead once the epoch passes
- If in doubt about the state or timing, ask the human before proceeding
- Always honor the `enabled-at` and `expires-epoch` fields exactly as written
- A token without a valid HMAC-SHA256 signature is **always inactive**, regardless
  of its epoch values — the guard verifies the signature on every check
- The signing key lives outside the repo (`<HOME>/.sdd/sudo-key` or env var); never
  commit or embed the key in the repo or in the token file itself

## Audit Trail

When sudo mode is active and an approval checkpoint is reached:

1. Record `Approval: Approved (sudo <ISO8601 UTC>)` in tasks.md to audit the
   passage
2. Keep all normal quality-gate reports, contracts, and verification artifacts
3. The `(sudo)` notation serves as a permanent audit mark that human oversight was
   deferred

## Expiry Behavior

Sudo mode is stateless and time-based:

- The agent checks `expires-epoch` at each approval checkpoint; the signature is
  also re-verified on every check
- If `current unix time >= expires-epoch`, the flag is treated as expired and
  inactive
- If the signature is missing, invalid, or the key cannot be resolved, the flag
  is treated as inactive (fail-closed: the approval gate stays enforced)
- Automatic expiry happens silently; no file deletion occurs
- To manually disable before expiry, use `/sdd-sudo off` or delete `SDD_SUDO`
  manually

See `plugins/sdd-quality-loop/references/sudo-mode-policy.md` for scope,
threat model, and operational guidance.
