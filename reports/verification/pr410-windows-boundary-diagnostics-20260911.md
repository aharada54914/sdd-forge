# PR #410: Windows boundary failure investigation

Not a fix-completion or PASS declaration.

At head e1e3aa124286b161de77e60eea35840982ae926c, CI run 34558171248,
Windows job 103135281609 failed the first GPT and first Gemini boundary cases:
62 passed, 2 failed. The remaining four iterations of each runner passed.
The installer job succeeded. The boundary fixture is identical to main and
the existing A7 work branch; no prior branch fix was found in that file.

Possible causes to distinguish: JSON serialization after the wait consumes
the remaining deadline on cold Windows runs; unread redirected stdin affects
shutdown; or process/wait scheduling differs between operating systems.
The existing log omitted the runner error and actual output completion time.

Added diagnostic-only logging of wait completion and output flush timestamps
for the synthetic CLI, plus bounded failure output with terminal control bytes
removed. No timeout, assertion, repetition count, or production code changed.
The timestamp fields are allowlisted before printing. Logging itself has some
overhead; a subsequent successful run alone will not establish a root cause.

macOS PowerShell baseline: 64 passed, 0 failed, exit 0.
With diagnostics: 64 passed, 0 failed, exit 0.
Logs: /tmp/pr410-cross-model-baseline-20260911.log and
/tmp/pr410-cross-model-diagnostic-20260911.log.
Author-side diff review and git diff --check passed. This does not replace
the required third-party approval. Windows evidence and a cause-directed
repair, if needed, remain outstanding; no issue is closed on this evidence.
