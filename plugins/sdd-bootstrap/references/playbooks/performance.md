# Performance investigation

Delegate to `investigate-codebase` read-only. Fix the workload, revision, runtime,
input hashes, cold/warm conditions, trial count and success/error criteria before
running the existing benchmark in an isolated scratch location. Retain all failed,
timeout and interrupted samples. Use `run_measurement.py` when available to keep
machine effort, elapsed time and human wait separate; unavailable cost is unknown,
not zero. Compare medians and ranges; do not infer stable p95 from three trials.
Measure before proposing optimization. Preserve all required checks and outcomes.
Stop when the budget expires or the measured benefit no longer distinguishes the
alternatives. Return evidence to ordinary bootstrap/ship; no direct product writes.
