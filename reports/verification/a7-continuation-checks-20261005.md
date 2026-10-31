# A7 continuation checks

This record is not a formal review or admission verdict.

- Re-ran `python3 -B reports/verification/a7-attempt17-recovery-candidate-20261005/attempt17.fixture.py` through `rtk proxy`: exit 0, 18 PASS. Includes Bash and PowerShell caller integration, replay rejection, historical manifest/receipt/ledger mutations, and v2 compatibility.
- Re-ran candidate `human-apply.py --check`: exit 0, three old hashes and patch hash match; apply check succeeded without writes. Attempt-17 protected application remains pending.
- `git diff --check`: exit 0.
- GitHub PR #512 head `d64cffcb22b114779202847be33e41700c4ba11f`: 37 completed successful Actions checks, including required-checks. Draft and BEHIND. CodeRabbit commit status is not independent review proof.
- These PR checks do not cover the uncommitted local recovery changes. No commit, push, merge, reservation, or review-status update was performed for these checks.

Next: complete the separate independent technical audit of the candidate, then the pinned human application and real attempt-17 precheck/reviewer launch. Preserve all prior failed/interrupted records.
