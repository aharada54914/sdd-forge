# RT002 child-process resource disposal

The remaining tracked repair is limited to `Invoke-ChildProcess` in
`tests/check-hook-activation-handshake.tests.ps1`: dispose the child process
and both output buffers in `finally`, after collecting output and exit status.
Temporary full stdout/stderr JSON-parse diagnostics were removed.

The main agent ran `pwsh -NoProfile -File
tests/check-hook-activation-handshake.tests.ps1` through `rtk proxy` on macOS.
The completed tool session reported `PASS: 985`, `FAIL: 0`, exit code 0.
`git diff --check` also returned 0. Complete output was not saved to a file.

An independent read-only reviewer found no correctness or regression issue in
this disposal-only diff: output bytes are saved and the exit status is captured
before disposal. The reviewer checked callers and whitespace, but did not rerun
the suite. This bounded review is not the formal RT002 quality gate.

This establishes the current macOS fixture result only. It does not prove
that resource disposal caused the earlier exit 134, native Windows execution,
installed plugin activation, formal review, CI, or integration.
