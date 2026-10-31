# PR411 Windows boundary failure follow-up

The Windows basic job 103158356798 on CI run 34566055007 (head
28503d7d8e803dec97c2a75c03e7afdf14835626) failed TEST-004(c), Gemini
iteration 4: exit=1, verdict=0, stub_launch_ms=875, elapsed_ms=2643,
budget_ms=2000. The complete suite reported 63 passed / 1 failed.
That head changed four documentation files, not the failing runtime or test.

Root cause remains unproven. The captured failure does not distinguish late
stub output/process exit, runner timeout handling, or output validation failure.
The outer elapsed measurement includes runner startup and is not by itself
proof that the inner deadline implementation is incorrect.

Reused PR410 commit b4a3d425fbbab4a635db6d1779484cba22df3afd as
256a0f4eea44590eb86524c93f3286e40f69b215. This only adds synthetic CLI wait/output
timestamps and bounded, control-character-stripped failure output. No budget,
assertion, production runner, workflow, or acceptance condition was relaxed.
The historical PR410 report retains its original identity; this file records
the separate PR411 verification.

Validation on macOS with PowerShell:

- `pwsh -NoProfile -File tests/cross-model.tests.ps1`: exit 0, 64 passed / 0 failed.
- Both timeout cases leave neither stub nor child alive; no verdict is produced.
- All ten boundary iterations passed. wait_end to output_end was 32–54 ms;
  output_end preceded the internal deadline by 738–764 ms.
- `git diff HEAD^ HEAD --check`: exit 0 for the reused diagnostic commit.
- Full diagnostic diff reviewed: no Critical finding. Warning: logging itself
  adds small I/O overhead; timestamps are observations, not a timing fix or
  Windows reproduction. No independent approval is claimed.

New-head Windows CI is required. A green rerun alone will not establish the
root cause or prove the intermittent failure fixed. No Issue is closed.
