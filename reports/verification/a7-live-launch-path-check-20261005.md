# A7 live launch path check

Observed 2026-10-05 JST. Diagnostic only; no reviewer reservation or verdict.

- The historical executable `/Applications/ChatGPT.app/Contents/Resources/codex` does not exist (rtk returned exit 1 / os error 2).
- The installed application contains `codex-cli/bin/codex`. Its inspected shell wrapper delegates to `codex-cli/CodexCLI.app/Contents/MacOS/codex`, without changing permissions or configuration.
- `rtk proxy /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex app-server --help` exited 0 and advertised stdio transport.
- This proves executable discovery only. It does not prove idle host allocation, first-turn identity binding, hook activation or reviewer read permissions.

Attempt 10 round 1 already has a successful precheck. Do not reset or rerun allocation/reservation merely to change the executable path. A separate diagnostic must establish the required host lifecycle before any formal reviewer launch. Keep the historical attempt outputs diagnostic-only and preserve their reservations.

The applied v2 regression results remain in `a7-v2-applied-regressions-20261005.md`: 24 fresh-recovery and 30 interrupted-recovery groups succeeded, with PowerShell on macOS rather than Windows. These are not a formal specification PASS, CI or delivery proof.
