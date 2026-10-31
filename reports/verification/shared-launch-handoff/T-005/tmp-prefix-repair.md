# T-005 native shell temporary-path repair

Owner: shared-review-launch-integration/sdd-forge.
HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807.
Scope: approved T-005 attempt 6 launch preparation; retain all existing dirty work.
Risk: bounded runtime configuration repair; no sandbox, approval, ledger, frozen input or product-contract change.

Native thread `01a11dad-e8e2-7e30-b591-b1d3909325e4` rejected a Python here-document before task execution. Same-session read-only diagnosis showed TMPDIR/TMP/TEMP inside output/tmp, but zsh TMPPREFIX remained `/tmp/zsh`. `/tmp` is intentionally excluded from writable roots.

Set TMPPREFIX to the existing output/tmp/zsh in the child environment and shell environment policy. Keep executor, cwd, network denial, MCP/plugin disabling and sandbox exclusions unchanged. Preserve original failure records. Validate same-shell heredoc execution and returned effective sandbox before resuming admitted task work. This is not a formal verdict or permission to expand access. Product regressions and formal review remain pending.
