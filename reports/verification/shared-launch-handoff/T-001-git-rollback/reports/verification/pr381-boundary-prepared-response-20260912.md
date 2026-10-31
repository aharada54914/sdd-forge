# PR #381: prepare the timed fixture response before waiting

## Observed failure

Windows job https://github.com/aharada54914/sdd-forge/actions/runs/34626082033/job/103351769173
tested commit `5a33e72f41fbd808e8633c2a8ec37a2f394bf3be` and reported
62 passing checks and two failures in `tests/cross-model.tests.ps1`.
GPT boundary iteration 5 reached wait_end at 1789147002320 and output_end
at 1789147003104, only 8 ms before its deadline 1789147003112; it timed
out without a verdict. Gemini iteration 1 reached wait_end but timed out
before output_end. These are real failures, not waived results.

The observed GPT post-wait delay was 784 ms. The fixture serialized its
fixed JSON response after waiting. Cold serialization/pipeline overhead is
a plausible contributor; the logs do not isolate JIT time or establish
the complete Windows scheduling cause.

## Limited change and review

Prepare the identical fixed JSON before the deadline-relative wait and
write it directly to standard output afterward. Preparation still occurs
inside the runner's process deadline. Keep the 2-second timeout, 800-ms
completion margin, five iterations per runner, descendant termination
checks, and failure conditions unchanged. No product runner is changed.

Self-review found no Critical finding in this limited diff. Outstanding
Warning: macOS cannot establish Windows process-launch and shutdown
behavior; a fresh Windows CI run remains required. This self-review is
not an independent approval or a disposition of the other PR findings.

## Local verification

Command: `pwsh -NoLogo -NoProfile -File tests/cross-model.tests.ps1`.
macOS result: **64 passed, 0 failed**, exit 0. All ten boundary cases
passed; measured wait_end-to-output_end intervals were 8–16 ms.
Timeout cases still exited 1 without a verdict and without living stub
or child processes. `git diff --check` also exited 0.

Local log: `/tmp/pr381-boundary-prepared-response-20260912.log`.
SHA-256: `6c6d0b20bde1406c5ac6c71c5e68b56016c6f31f4b267fff5b231bcf50c0008d`.

Windows revalidation, independent review, full latest-head CI and merge
remain pending. The separately reproduced cross-task scratch-root defect
is not fixed by this change and remains a merge blocker.
