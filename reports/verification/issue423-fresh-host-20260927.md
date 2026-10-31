# Issue423 fresh-host handshake observation (new session)

Date: 2026-09-27
Runtime: claude-code (model claude-sonnet-5)
Scope: activation verification only. No implementation, no approval/status
change, no reviewer identity reservation, no commit/push/merge, no public
comment.

## Step 1 — `check-hook-activation-handshake --emit-challenge`

Invocation attempted via the normal Bash tool:

```
python3 plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py --emit-challenge
```

Raw result (verbatim): the tool call was denied before any stdout (and
therefore no nonce) was produced.

```
PreToolUse:Bash hook error: [node /Users/jrmag/.local/share/sdd-plugins/plugins/sdd-quality-loop/scripts/sdd-hook-guard.js --emit exit]: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.
```

Consequence: no fresh nonce exists this session. Per instruction, the
historical nonce `05473469f2da15360b6d53c4f0ff6c6b` from an earlier session
was not substituted, and no alternate invocation (the `.sh`/`.ps1` wrapper,
or any other path to the same script) was attempted after this denial.

## Step 2 — canary Write attempt

Read-only precheck: `test -e sdd/.hook-canary-sentinel` → absent, before any
attempt (no stale sentinel).

Single native Write tool call: `file_path=sdd/.hook-canary-sentinel`,
`content=""` (the claude-code `tool_call_template` shape documented in
`check-hook-activation-handshake.py`).

- First attempt raw result: denied by an unrelated hook, the ECC
  Fact-Forcing Gate (not the SDD guard), requesting four facts before
  retry. Complied normally — no bypass flag (`ECC_GATEGUARD=off` /
  `ECC_DISABLED_HOOKS`) was used — by presenting the requested facts, then
  retried the same Write once.
- Second attempt raw result (verbatim):

```
PreToolUse:Write hook error: [node /Users/jrmag/.local/share/sdd-plugins/plugins/sdd-quality-loop/scripts/sdd-hook-guard.js --emit exit]: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.
```

Post-check: `test -e sdd/.hook-canary-sentinel` → absent. The write did not
execute (`executed: false`); no cleanup attempt was needed or made.

## Step 3 — `check-hook-activation-handshake --verify-response`

Not run, for two independently sufficient reasons:

1. No fresh nonce was obtainable this session (Step 1 was denied before a
   nonce could be emitted), and the instruction explicitly forbids
   substituting the historical nonce or inventing a new one.
2. Even granting a nonce, the claude-code branch of `--verify-response`
   requires the recorded-result JSON to carry `"guard_emit_mode": "exit"`
   and a non-zero integer `"exit_code"` field. The tool-call denial this
   agent session actually observes is free text only — the hook's command
   line plus its stderr message — with no discrete integer `exit_code`
   field exposed to the agent. That field is not inferred from the CLI's
   own exit status and was not invented.

## Verdict

`NOT ESTABLISHED` — no `HOOK_ACTIVE` / `CAPABILITY_RUNTIME_UNAVAILABLE`
verdict is claimed, because the official verifier was never run. What this
session did observe directly: a real, verbatim `sdd-hook-guard.js --emit
exit` denial of both (a) the `--emit-challenge` invocation and (b) the
actual canary Write against `sdd/.hook-canary-sentinel` — distinct from the
unrelated ECC Fact-Forcing Gate hook that fired first on the Write attempt
and was resolved normally, without a bypass. This is suggestive that the
SDD guard is active for both Bash and Write tool calls in this session, but
it is not the same as a verifier-confirmed `HOOK_ACTIVE`, and is reported
as an observation, not a verdict.

## Scope discipline

No settings/hooks/sandbox changes were made. No skip flags were used. No
alternate execution was attempted after either protected-tool denial. No
reviewer identity was reserved. No task/approval status was changed. No
implementation was performed. No commit, push, merge, or public comment was
made.
