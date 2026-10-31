# Native finite-batch comparison

Actual GitHub Actions run [41158269796](https://github.com/aharada54914/sdd-forge/actions/runs/41158269796)
succeeded at workflow source 27b72a868f1e87e4a83b47866025184f1b361d8d, using fixed
product source 006e5a553f0667bfc6070dce25e6e9cffe9ea730. Three separate native jobs
each ran three trials of eight isolated SQLite/hash fixtures with wrapper limits
2, 4 and 8. The existing project runner, Linux subreaper and passive measurement
owner performed execution/cleanup/measurement. The pure admission proposals did
not grant execution authority: this explicitly invoked benchmark owns its finite
fixture items, not external Work Orders or product tasks.

| Wrapper limit | Median seconds (3 trials) | Observed maximum |
|---|---:|---:|
| 2 | 0.844217 | 2 |
| 4 | 0.633634 | 4 |
| 8 | 0.613526 | 8 |

Independent inspection matched native run/attempt/job/source and API artifact
hashes, all 72 item log/observation hashes, exit results, cleanup, seeds and
independently calculated hashes. SQLite bytes for each seed agreed across all
nine corresponding executions. Re-reducing all nine measurements with the
original source returned complete. Wrapper concurrency includes setup/log copy;
it is not a measurement of simultaneous CPU execution. Separate hosted jobs,
fixed order and few repetitions do not establish a causal speedup or tail metric.

The ZIP archives are the original provider artifacts. Runner receipt files were
not included, so these observations must not be imported as gate/bundle evidence.
External Work Order ownership/lease, shared resource reservations, actual human
review load and billing remain unverified. Native cancellation/retry observations
are separate historical experiments, not reruns of this batch. No approvals,
task state, model verdicts or product outputs were created by this benchmark.

The independent audit script preserves its original workspace paths. For replay,
extract each parallel-N.zip under parallel-N/ beneath the scratch evidence root
named in that script and provide the recorded product Git revision. Historical
API snapshots are retained; re-reading them is not a fresh host query.
