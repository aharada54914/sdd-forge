# A9 entry preflight — 2026-09-08

No specification, implementation, review status or approval was changed.

The structure preflight passed (exit 0), with only advisory CLAUDE.md output.
The handshake emit-challenge command succeeded (exit 0), issuing nonce
`691b5dc840be566cfadc83caf60e6cf6`. A real apply_patch attempt against the
A9 worktree's `sdd/.hook-canary-sentinel` was blocked by the PreToolUse hook.
The exact response is preserved in `a9-handshake-observation-20260908.json`.

The tool response does not contain the two boolean fields required by this
validator's Codex branch. A read-only `rg -n plugin_hooks` against
`/Users/jrmag/.codex/config.toml` returned no match (exit 1). This does not
prove that hooks are disabled: the actual denial is direct contrary evidence
to that broad claim. The missing booleans were not manufactured from assumed
host configuration.

`check-hook-activation-handshake.sh --verify-response --nonce
691b5dc840be566cfadc83caf60e6cf6 --recorded-result
reports/verification/a9-handshake-observation-20260908.json --runtime codex-cli`
completed with exit 65 and status CAPABILITY_RUNTIME_UNAVAILABLE, reason
PLUGIN_HOOKS_DISABLED. That reason is the validator's classification of
missing evidence, not a proven description of the host.

The installed sdd-bootstrap-interviewer skill's Track Detection step 4 says
any outcome other than HOOK_ACTIVE stops, with no silent legacy fallback.
Accordingly no A9 specification editing or independent review was launched.
The needed next action is an authoritative host-evidence mapping/capture
through the existing A8 handshake integration contract. Do not synthesize
success fields, bypass the canary, or modify the protected validator merely
to turn this observation green. T-002's separate legacy-reopen approval
request remains independent of this A9 entry condition.
