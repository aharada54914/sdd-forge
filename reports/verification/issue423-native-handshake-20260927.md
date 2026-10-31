# Issue423 native handshake observation

Date: 2026-09-27
Runtime: claude-code
Host session: a52cac9f-9e13-4e75-b725-848cc7cda8b7
Challenge nonce: 05473469f2da15360b6d53c4f0ff6c6b
Activation verdict: NOT ESTABLISHED

After the first Write was rejected by ECC Fact-Forcing Gate, the same
session obtained facts using its normal Read/Glob tools and retried the
same Write once. No hook, permission or settings change was made.

The second native Write was observed at 2026-09-27T11:50:50.043Z,
tool ID `toolu_01QXn4ft2zL5yvTQso3xVMCx`, with empty content. The host
canonicalized `sdd/.hook-canary-sentinel` to its absolute checkout path.
At 2026-09-27T11:50:50.288Z the matching tool result had `is_error: true`
and reported `PreToolUse:Write hook error`, naming
`sdd-hook-guard.js --emit exit` and both SDD deterministic-gate denial
signatures. The host also recorded `toolDenialKind: permission-rule`.

This establishes an actual SDD hook refusal of the attempted Write, not
a successful write or a simulated fixture. The native event does not
expose the hook's integer exit code. The current activation verifier
requires that integer for Claude records; it has not been fabricated
from the usual guard convention. No HOOK_ACTIVE verdict is claimed.
The Claude CLI process exit 0 is not the hook exit code.

Subsequent diagnostic: the same session was resumed with the normal
`--include-hook-events` option and unchanged hooks. It declined another
Write and issued no tool calls. The captured events were lifecycle hooks,
not a canary PreToolUse response. That process exited 0 but supplied no
missing hook exit-code evidence. This was an assistant refusal to run the
diagnostic, not another observed SDD guard refusal or activation success.

Source: native session JSONL, matched assistant UUID
`3de0d695-e37b-4097-85c2-087ec092f6ab` and tool-result UUID
`5b65c3c7-e6e8-4c87-a506-26b82f85b630`.

Task approvals remain approved; implementation, formal gates, CI and
merge are not established by this observation.
