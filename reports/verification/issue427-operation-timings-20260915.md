# Issue 427 operation timing diagnostic (not a repair verdict)

Worktree: `/Users/jrmag/.local/share/sdd-forge-pr381-main-sync-20260912`
Branch: `codex/issue427-timeout-measurements`
Base HEAD: `2eae1bb2f36610448987741ded106bdebeff7d0c`

The uncommitted change to `tests/cross-model.tests.ps1` separates completion
of the wait receipt append, console acquisition, WriteLine and Flush. It
publishes those numeric observations in the existing final receipt append.
This adds clock reads inside the deadline: it is NOT zero-overhead evidence.
The two-second budget, 800 ms target margin, five repetitions per vendor,
verdict requirement and cleanup assertions are unchanged.

Review correction: the initial diagnostic used stderr, which successful
runner cleanup would discard. The current version uses the phase receipt
already collected by the harness, with a strict numeric-key allowlist.
No product script, approval, review verdict, or task status was modified.

Verification on macOS:

- `pwsh -NoProfile -File tests/cross-model.tests.ps1`: exit 0, 64 passed,
  0 failed; terminal session 51981.
- Parsed all ten boundary sequences and verified all six timestamps exist
  and are nondecreasing: 10 sequences, 0 invalid, exit 0.
- `git diff --check`: exit 0.
- Test SHA-256: `4e1e64e43240379c4594696b067b42ed40427589367f1fb544e63eadbc2fc40d`.
- Log: `/tmp/sdd-427-operation-timings-20260915.log`.
- Log SHA-256: `2864e877add9ce3e4dd4142521782214c90642c088abc4ea43209faf2b66f52e`.

## Awaited-process follow-up

The two PowerShell runners now retain the exact `WaitForExit` result, the
observation time and that same handle's subsequent `HasExited` result. They
emit only numeric fields after cleanup (timeout) or the existing final wait
(natural completion). `cleanup_kill=1` describes the cleanup call, not a claim
that the process could not exit naturally between observations. The original
deadline, cleanup calls and exit-code decisions are unchanged.

Added tests first: existing 64 cases passed and all 12 missing-observation
cases failed (exit 1), log `/tmp/sdd-427-process-observation-red-20260915.log`.
After implementation: 76 passed, 0 failed, exit 0, terminal session 56167;
log `/tmp/sdd-427-process-observation-green-20260915.log`. This covers both
deliberately hanging processes and all ten boundary completion cases on macOS.
Whitespace check passed. Review found no input/prompt/credential values in
the new numeric output and no changed timeout acceptance or cleanup policy.

Unresolved: operation timings cannot be recovered if killed before the final
receipt append. HasExited is a later observation than the timed wait, not an
exact process-exit timestamp. Additional observation has overhead. Windows
execution is still required; this diagnostic is not a root-cause fix or a
reason to merge PR 429. Preserve the unrelated dirty README. Earlier test
hashes above describe the first diagnostic version, not this follow-up.
