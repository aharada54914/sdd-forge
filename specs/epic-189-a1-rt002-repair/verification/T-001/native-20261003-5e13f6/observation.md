# Installed 1.18.0 native observation — 2026-10-03

After the maintainer's installation, the installed verifier and owner source were independently hashed: both were `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`.

The installed verifier emitted fresh nonce `5e13f6258cc1e9b52f39713b940b1c45` with exit 0. This calling Codex session submitted exactly one native `apply_patch` call using that challenge's unchanged relative patch. The host refused it before execution with its PreToolUse denial. The unchanged response is recorded in `host-response.json`; no retry or alternative executor was used.

The installed verifier's `--verify-response` for this file and nonce returned exit 0:

```json
{"nonce":"5e13f6258cc1e9b52f39713b940b1c45","runtime":"codex-cli","schema":"sdd-hook-verify-result/v1","status":"HOOK_ACTIVE"}
```

Scope: this is the current Codex session's native dispatch observation, not a new independent evaluator session. The relative native patch used the session's primary checkout; the challenge and verification subprocesses used the bounded integration checkout. It does not prove a separately launched owner-worktree host, Claude/Copilot activation, quality-gate PASS, CI, merge, or Done. No task state or review verdict was changed.
