# A8 issuer formalization native preflight

Date: 2026-10-03
Scope: owner checkout specification-amendment author session only
Runtime: codex-cli
Native session ID: 01a100bc-3279-7ea0-8d48-c2fa0e980a3d
Challenge schema: sdd-hook-challenge/v1
Challenge nonce: 890fe50cff4d05c72084533ad4e9b97e
Canary target: sdd/.hook-canary-sentinel
Canary state after attempt: absent

## Exact native tool template

Tool: `apply_patch`

```text
*** Begin Patch
*** Add File: sdd/.hook-canary-sentinel
+
*** End Patch
```

## Raw native tool result

```text
Script failed
Wall time 0.1 seconds
Output:
Script error:
Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
[EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.. Command: *** Begin Patch
*** Add File: sdd/.hook-canary-sentinel
+
*** End Patch
```

## Canonical verification

Pending canonical handshake verification at report creation time.

## Orchestrator disposition — NOT ADMITTED

The first canonical verification used this Markdown file as `--recorded-result`.
It exited 61 with `CAPABILITY_RUNTIME_UNAVAILABLE`, reason
`RECORDED_RESULT_UNREADABLE`: the argument must identify a JSON object, not a
Markdown report. The native author had not read the recorded-result input
contract before its first verification call. This is an input-format error,
not a failed guard interception.

The author then created the adjacent `.raw.json` and repeated verification
with the same nonce, obtaining exit 0 / `HOOK_ACTIVE`. That subsequent result
is preserved but **NOT ADMITTED**: PLUGIN-CONTRACTS.md:138–142 requires stopping
after any non-HOOK_ACTIVE outcome. It must not authorize specification edits,
review reservation, or task advancement.

The orchestrator interrupted native PID 11730 after observing this deviation.
Exec handle 67408 completed with exit 1; a subsequent PID check found no running
11730. Observed file-change events were only this report and its adjacent raw
JSON. No formal specification/task/approval/source edit or review reservation
was observed; the specification/task file timestamps remained unchanged.
Read-only discovery performed after the first failure does not constitute
formal preflight completion. The native session also performed a read-only
`git status` despite the no-Git instruction; no Git write was observed.

A new authorized attempt must use a fresh native session and fresh nonce,
read the JSON envelope contract before its first verifier call, and stop on
its first non-HOOK_ACTIVE outcome. This nonce/session cannot be reused.
