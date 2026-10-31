# Manual gate benchmark fixtures

These manifests freeze repository data at `c5a02f06c2aa6d6b287c0b81e203ce0d65f96620`.
`--code-revision` selects executable code independently. Input pins must still
match that revision; the recorded skill source defines the baseline recipe and
may differ in a candidate. The complete baseline Git tree supplies transitive
reports, specifications and fixtures. Code overlays are restricted to the
manifest's `code_paths`.

Run from the repository root with a new output directory:

```bash
python3 tests/benchmark-gates.py --manifest tests/fixtures/run-measurement/benchmark.json \
  --code-revision <full-commit> --output <new-directory> --run
python3 tests/benchmark-gates.py --manifest tests/fixtures/run-measurement/benchmark.json \
  --code-revision <full-commit> --output <new-directory> --compare
python3 tests/benchmark-gates.py --manifest tests/fixtures/run-measurement/benchmark-feature.json \
  --code-revision <full-commit> --output <new-directory> --run
python3 tests/benchmark-gates.py --manifest tests/fixtures/run-measurement/benchmark-feature.json \
  --code-revision <full-commit> --output <new-directory> --overhead
```

`benchmark.json` compares a full intermediate workflow scan with a feature-scoped
intermediate scan. Both retain the same mechanical gates and final full workflow
scan. Five trials of each recipe measure a representative correction gate cycle;
they do not measure model review or human waiting. The primary statistic is the
full recipe's median session time. Compare the same manifest and environment
fingerprint across source revisions. A scoped recipe improving one component is
not proof that the whole session or development lifecycle is twice as fast.

`benchmark-feature.json` covers initial, resumed and repaired feature feedback,
each with five fresh-export and five warm-export trials. Resume splits at the
workflow check and records linked attempts. Repair first applies the exact hashed
invalid-registry patch, retains its expected failed control logs, reverses it,
then measures the restored inputs. Warm trials use the same exported worktree
after one discarded warmup; fresh-export trials use separate worktrees. Neither
label claims that OS page caches are flushed or that system load is controlled.
The overhead mode alternates bare/measured execution order for five pairs and
retains signed absolute and relative differences, including negative noise.

The fixture builder is extracted from `tests/workflow-state.tests.sh`, not a new
mock gate. Its hash and the repair patch hash bind instrumentation outside the
baseline tree; changing either requires a new manifest/fingerprint. Comparison
cases exercise valid, malformed, stale, forged and empty-registry inputs. The
driver compares exit status and normalized diagnostics with timing disabled and
enabled. These checks do not substitute for Bash/PowerShell platform suites or
claim that every verification family has received equivalence coverage.

Raw stdout/stderr and hashes, measurement records, per-gate timings, complete
trial denominators and aggregate statistics are written under the output path.
Expected failed repair controls remain separately labelled setup runs, not
successful timing samples. Unexpected failures and censored measured attempts
remain in the trial denominator and make a five-success primary comparison
inadmissible. No CI test asserts a wall-clock threshold and no paid model is
called. Model tokens, costs, human active time and missing lifecycle observations
remain unavailable rather than being estimated from these gate executions.
