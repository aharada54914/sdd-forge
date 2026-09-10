# RT004 summary binding: RED evidence and unapplied candidate

Scope: the existing approved RT-20260908-004 contract correction.
Original validators and historical review files were not modified.

## Actual regression execution

`rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only` ran
with pipefail and tee, log `/tmp/rt004-summary-binding.BE9Na5`.
Session 32379 terminated with exit 1: **6 passed, 20 failed**.
The new `wrong-summary-count` and `wrong-summary-id` cases each returned 0
with `workflow-state: ok` in Bash and macOS PowerShell, instead of rejection.
These are four new RED observations; the previous 16 failures remain failures.
Native Windows was not run.

Both cases start from the extended equal-layer positive fixture. Count mutation
keeps the same total of eight but changes FAIL/PASS from 1/7 to 2/6. ID mutation
replaces one summary ID without changing cardinality. Both rehash the changed
summary in reviewer B's output manifest and copy that manifest into B's contract
entry. A separate jq assertion proves disagreement with actual A checks.
The test therefore targets saved summary/content correspondence rather than
merely stale summary hash rejection. Candidate validators are never executed.

## Candidate and review

`adr-workflow-powershell-summary-binding-candidate-20260909.patch` adds the
unapplied `Test-AdrHistorySummary` helper. It validates the eight exact keys,
schema/attempt/round, generated_at presence, nonempty unique IDs, numeric
nonnegative integer counters and total; for current summary it compares A's
actual ID set and counters returned by `Test-AdrHistoryOutputs`. Prior summary
retains the agreed shape-only rule, without recursively reading old reviewer
narratives. Hash binding is the caller's responsibility, not this helper's.

Root static review: Ordinal keys and IDs; numeric type checked before conversion;
NaN/infinity/fraction rejection through bounds and remainder; sum bounded by
three array counts in long arithmetic. No Critical defect found in this slice.
Caller MUST pass actual validated A result for current summary; null is only
permitted for the prior-summary shape check. JSON duplicate-key detection must
occur before conversion, since a parsed object alone cannot prove uniqueness
of original JSON keys. No independent candidate approval is claimed.

`git apply --numstat` exited 0: 55 added lines, no deletions. This is only patch
format evidence; PowerShell syntax/runtime and corrected behavior remain
unverified because the protected candidate remains unapplied. Bash test syntax
validation exited 0. The full TDD cycle has not reached GREEN.

Next: compose the history caller with strict safe JSON reading, core binding,
output checks, current/previous summary checks and all four manifest checks;
connect before the workflow opening fast path. Complete current-stage handling
and coherent full patch assembly before independent review and human apply.
Do not merge or close any issue on the strength of this partial candidate.
