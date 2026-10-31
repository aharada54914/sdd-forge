# PR403 T-007 candidate evidence plan

This is a human-application note only. Protected specification, task, and
stored panel evidence files are intentionally unchanged.

## Required candidate patch application

1. Apply `pr403-runtime-parity-candidate-20260921.patch` to the PR branch.
2. Apply `pr403-t007-minimal-tests.patch` to add the missing unknown/empty
   signature-algorithm negatives to both runtime suites.
3. Re-run both complete suites and retain the T-007a/T-007b output in fresh
   red/green evidence. The isolated candidate run here produced Bash 165/0
   and PowerShell `Script gate tests passed`.

## Remaining parity evidence

The candidate patch makes `git_generated_dirty` explicitly boolean in the
PowerShell generator/checker, removing the Python strict-True versus
PowerShell truthy divergence. A fresh review still needs one cross-runtime
canonical fixture: the same critical bundle must be signed by the Bash/Python
path and verified by PowerShell, then signed by PowerShell and verified by the
Bash/Python path. Include artifact paths containing a supplementary Unicode
code point and both `git_generated_dirty: false` and `true` negative cases.

## Risk and approval evidence

The current code already rejects a present contract/tasks risk mismatch in
both check-task-state implementations; PowerShell has T-007b.7, while the
Bash twin is absent. Add the same mismatch fixture to `gates.tests.sh`, then
capture the full T-007b matrix in both runtime logs. Include the existing
guards/hooks suites in T-007 red/green evidence because the stored T-007
panel input omitted those compensating controls.

## Human gate

Do not mark T-007 PASS from these candidate runs alone. A human must apply the
patches, run the cross-runtime canonical fixture and both approval/guard
matrices on the PR HEAD, then decide whether the historical FAIL evidence is
superseded without rewriting it.
