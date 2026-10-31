# PR #517: common lightweight fixture

Commit: f51b6b9e

The user approved this limited repair and one additional verification. The previous macOS run failed correctly: the synthetic PowerShell CLI overshot its wait and remained alive at the deadline. Its FAIL remains recorded in pr517-latest-head-macos-20260927.md.

Reuse the existing Windows Python synthetic CLI on macOS/Linux. Delete the duplicate PowerShell worker; production runners are unchanged. Retain the two-second deadline, five iterations per runner, exit code zero, verdict, successful wait, no forced termination, timing-negative cases and descendant cleanup checks.

Verification: `rtk proxy pwsh -NoProfile -File tests/cross-model.tests.ps1` on macOS / PowerShell 7.6.2: 85 PASS, 0 FAIL, exit 0. All ten boundary repetitions succeeded without forced termination. This proves the fixture checks, not live model activation or Windows/Linux execution. Exact child exit timestamps are not measured. Independent read-only reviewer /root/pr517_final_review: PASS, no findings; suite not rerun by reviewer. `git diff --cached --check`: exit 0.

Push succeeded to codex/issue427-restore-two-second-bound. Latest-head CI run 36292190291 completed with failure at f51b6b9e1b139431ea7a49da6661ca15b0902e61: test-windows-heavy and required-checks failed. Merge and postmerge checks remain unperformed; old-head CI is not evidence for this commit.

Latest-head CI run 36292190291, Windows heavy job 108544281478: 81 PASS, 4 FAIL. Two boundary invocations (gpt repetition 1, gemini repetition 3) failed both completion and process-observation assertions. Each recorded wait_end 199ms before the deadline, but had no output receipt; the runner observed an alive process at/after the deadline and terminated it. This is a genuine timeout, not late parent-side logging. Successful repetitions also show Windows output flush overhead (up to 147ms in the inspected records). Logs do not isolate the cost of phase-file writes, stdout flush, Python exit and cmd-wrapper exit. No unmodified rerun or merge was performed. Additional limited repair/verification authorization requested; current approval's local trial is exhausted.
