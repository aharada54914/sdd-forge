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

This slice instruments the verification runner and Lite gate only. Full-gate
instrumentation, representative baseline comparisons, and the other acceptance
conditions for issue #614 require separate validation.
