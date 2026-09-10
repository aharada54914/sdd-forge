# CI continuation

PR395 merged as 91cf642ccbacbae3dafdf4ee89386eb3275e612f after all 25 checks
and exact-head independent review. Its main run 34016247257 is still active;
previous main run 34014820338 completed successfully.

PR397 candidate 980ee1e8b19065b9b6707e87497356ee2343aca4 is pushed and its
run 34016349265 is live: last query 12 successes, 12 active, no failures.

T-002 cycle-4 candidate and approval/review evidence were committed together
as 913dec2b1bf15dbd5a09650c663771975679f461 and normally pushed to PR400
(exit 0). Run 34016430635 is live: last query 1 success, 23 active, no failures.
Keep Draft; Windows verification, current-base reconciliation and formal
quality gate remain pending. No fifth repair cycle is authorized.

PR381 archive repair is pushed at 4ee8c34fd58ebf0789bd7bab16d77775bd98ab7a;
no Actions run exists because of its tests/run-all.sh merge conflict. See
issue311-branch-reconciliation-20260906.md. PR394 dependency refresh is assigned
to the lightweight worker; no push or merge is claimed for that candidate.

## Subsequent live observation — 2026-09-06

Main run 34016247257 is not green: Windows job 101440412301 failed at
`Test cross-model gate (pwsh)`. Primary retrieved the job log with terminal
escape sequences stripped before display (chunk 1c9d47, exit 0). The suite
reports 63 pass / 1 fail: TEST-004(c), Gemini iteration 5, elapsed_ms=3240,
deadline_ms=2000, stub_launch_ms=745, exit=1, verdict=0. This is the same
test identifier under investigation in T-002, not proof of the same cause.
Later Windows steps were skipped and must not be counted as successful.
The pre-merge PR395 checks were successful; the subsequent main failure is
separate evidence requiring diagnosis. Main has no new T-002 stage diagnostics.

Fresh compact snapshots: main has 18 successful, 5 active and 1 failed job;
PR397 has 14 successful and 10 active jobs; PR400 has 11 successful and
13 active jobs. PR400 Windows job 101440895481 is still running. No rerun,
additional merge, or inference of suite completion was made from these snapshots.
