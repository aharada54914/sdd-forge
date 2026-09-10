# PR381 registration loops — 2026-09-09

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`, preserved base `3971c93a5705dc15f86ba56cc62118613e4b19db` plus recovery changes.

Approved registration repair: facet-manifest-parity now executes actual runner `--list` for every one of the six original suite names and its self-check, requiring success and exact path membership. All six PowerShell checks and staged/live workflow checks remain unchanged. hook-guard-epic-a1-boundary replaces its two-runner source loop with a Bash actual-list check and the same PowerShell source check; twin existence and guard behavior assertions are unchanged. No hook implementation change.

Primary review: complete two-file diff inspected; no missing loop member, sibling assertion or failure branch. Critical 0; not formal independent QG.

Diagnostic controls: hook actual Bash block 5 passed. Facet actual six-suite loop and self-check 21 passed, including each individual missing member, near-match and PowerShell missing member, plus listing failure despite correct stdout. The standalone scripts are not inventory-wired suite coverage. Diff whitespace check passed.

Full suites launched in session 17452, preceded by `bash -n`, with output at `/tmp/pr381-posix-20260909.WaPopD/<suite>-after-registration-loop.log`. At this record the handle remains live, progressing through actual Python/Bash/PowerShell parity fixtures. Poll the SAME session; do not restart on an observation timeout. No full-suite success or failure is claimed yet.

Completion update: session 17452 subsequently terminated exit 0. Facet-manifest-parity: 329 passed, zero failed; hook-guard-epic-a1-boundary: 228 passed, zero failed. Both full suites passed. Do not poll/restart the now-terminal handle. Original unresolved baseline count is now ten. No whole-run PASS, formal QG, CI success, commit/push/merge or issue closure.

Next read-only investigation: generate-registry-digest's success message claims T-004/T-006 ordering while old predicate proves only membership. Task Global Constraints lines 92-95 require serialized registration order; preserve/prove order rather than silently discarding the claim. Other remaining consumers are listed in the preceding handoff.
