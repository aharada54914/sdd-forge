# PR #517 latest-head macOS failure

Head: `07cca384866d409b2dd0d491ca96757270d80163`
CI: https://github.com/aharada54914/sdd-forge/actions/runs/36290071260/job/108538330804

The independent final diff review found no regression in the approved evidence correction. This is not a CI PASS. macOS PowerShell completed with 83 passed and 2 failed: TEST-004(c) GPT iteration 2 and its awaited-process assertion.

The absolute deadline was 1790478685195 ms. The 200-ms-margin target was 1790478684995 ms; the worker recorded wait_end=1790478685161 and output_end=1790478685179. Output was 16 ms before the deadline, but the runner recorded wait_completed=0, observed_exited=0, cleanup_kill=1 at 1790478685212 and exited 1 without a verdict. This is an actual unsuccessful wait/termination, not merely late parent logging. Exact child exit time is not established.

Do not retry without a cause-based repair or treat this head as mergeable. The specifically approved extra repair/verification has been consumed. A further one-file repair and verification was requested: reuse the existing Python synthetic CLI on macOS/Linux, retaining the two-second budget, five iterations, near-deadline receipts, successful wait, exit zero and no kill. No such repair has been applied yet.
