# Local workflow-state batch comparison

`result.json` records a real local Linux run on 2026-10-28 JST. `measure.py`
creates one synthetic full-profile feature with pending statuses and no review
history, then compares 2 and 5 ordinary full checks with an optional sealed
batch for the same number of requests. Each condition was repeated three times,
with ordinary checks first. Batch elapsed time includes capture, runtime probes,
sealing, rechecks and JSON output; each run asserts one actual full execution.
The exact candidate checker and session helper hashes are in the result.

On this small fixture ordinary checks took 0.097–0.110 seconds for two requests
and 0.210–0.234 seconds for five. Batching took 1.053–1.308 seconds and
1.738–1.873 seconds respectively. Fewer executions did not offset isolation
and capture overhead. The ordering and small synthetic workload limit the
comparison; this does not establish a speedup or regression for the real #614
workload, a full lifecycle, or any other host. Hosted CI and independent review
remain pending. Do not recommend the optional batch as a performance win on
this evidence.

Reproduce on a compatible Linux host with bubblewrap and the fixed system tools:
`python3 -B reports/verification/workflow-session-main-20261028/measure.py`.
It creates a temporary fixture outside the repository and prints results; it
does not rewrite the retained `result.json`.

`real-result.json` records one ordered run against the clean actual candidate
checkout at commit `f325bf461082631a0e5a0e92aa2ec8cfe34de041`. The ordinary
full check passed in 42.089 seconds. The batch returned `cold-required` in
0.404 seconds because the captured tree exceeded its file limit; the subsequent
ordinary fallback passed in 41.077 seconds with identical output hashes. This is
one local comparison, not a claim of improvement, a controlled repeated timing,
or the full #614 workload. No task or approval state was changed.

`measure-real.py` runs against the current directory and requires a clean
checkout; it prints results without replacing the retained record. To reproduce
this particular source, run the script from an isolated checkout of the recorded
commit. Host conditions, filesystem contents and timing may differ.

## Process profile for the full repository

On clean candidate commit `3cbfcca3d847292415eb27e51eb6ab596d726ee5`,
we ran the ordinary Bash checker once under `strace -f -c -e trace=process,file`
and once with Bash xtrace redirected to a private temporary file. Both exited 0
and produced the same stdout hash as the prior uninstrumented baseline. The
aggregate `process-profile.json` retains counts only; the raw xtrace, which can
contain repository input, is not retained. Instrumentation perturbs timing.

The syscall summary observed 12,832 `execve` and 18,376 `clone` calls. The
xtrace showed 3,493 `jq`, 2,393 `sha256_file`, and 1,599 `git` command entries;
854 distinct hash argument strings account for those 2,393 entries. These
measurements identify investigation targets, not safe cache keys: the same path
may change between reads, and hash/history provenance, error behavior and
independent review must still be enforced. A real change requires separate
negative controls and a cold/warm comparison on the actual workload.

## Narrow legacy membership experiment

A disposable candidate against integration commit `9296b0ab` preloaded the
legacy task approval and status arrays rather than starting `jq` for every
field. Two real legacy-profile fixtures and 20 positive/negative differential
cases had identical exit codes and output; malformed and unauthorized values
were rejected. The protected checker was not changed.

One normal full-repository baseline took 47.766 seconds; one candidate run
took 47.467 seconds and had the same stdout/stderr hashes. The candidate run
overlapped a separate fixture test, so this is not a controlled comparison and
does not establish a speedup. An early `jq` failure with an empty task file may
also alter error behavior. The candidate was discarded rather than promoted;
`legacy-experiment.json` retains the observed results and limits.
