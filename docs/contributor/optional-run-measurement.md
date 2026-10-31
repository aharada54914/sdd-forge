# Optional run measurements

The verification runner can record elapsed time and outcomes without changing a
suite's verdict or receipt. Use a new output directory for each run:
The output directory must be outside the checkout so the sidecar cannot change
the source cleanliness reported in the receipt.

```sh
python3 tests/verification.py --suite tests/run-measurement.tests.py --run \
  --measure-dir /tmp/sdd-measurement-example --receipt /tmp/sdd-receipt.json
python3 plugins/sdd-quality-loop/scripts/run_measurement.py summarize \
  --dir /tmp/sdd-measurement-example
```

The Lite gate runner accepts the same `--measure-dir` option when the
`sdd-quality-loop` plugin is installed alongside it; an optional
`--measure-parent` links a run to an existing observation. The sidecar is an
observation, not an approval, gate result, or replacement for the normal receipt.
It includes input paths and hashes, so choose an appropriate storage location.
Missing token usage, cost, human active time, and incomplete spans are reported
as unknown rather than inferred. An invalid or already-used measurement
directory is rejected before the run starts.

Full Bash/PowerShell gate calls can use the passive `open` / `start` / `finish`
API described in the quality-gate skill's Optional passive timing section. Use
an enclosing session span, capture the original gate's exit code before recording,
and return that saved code even when recording fails. An exit code alone does not
establish timeout or human activity. This is caller-side instrumentation, not an
automatic replacement for the Full execution owner.

The [fixed-input baseline and overhead comparison](../../reports/verification/measurement-20261025/README.md)
is preserved with its original baseline c5a02f06 and candidate dc0c17c2. It is
historical performance evidence, not a benchmark of the current integration.
The [bounded batch comparison](../../reports/verification/workflow-session-comparison-20261025/README.md)
records zero reuse on the original large workload and benefits only for some
eligible multi-request fixtures; the half-time goal was not achieved. Do not
recommend batching without a measured total-time benefit for the actual input.

Golden grader success counts are not valid-hypothesis counts. The run/experiment/
variant references support attribution, but no human hypothesis-adjudication
measurement is supplied by those historical grader results; that quantity remains
unknown until an explicit evaluation supplies it.
