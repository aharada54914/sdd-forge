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
