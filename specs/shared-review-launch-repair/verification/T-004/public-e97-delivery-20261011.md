# T-004 current public delivery evidence, 2026-10-11

This addendum supplements, never replaces, the frozen implementation report and
previous evaluation. It is not a verdict or a task-state transition.

## Exact candidate and executed verification

- PR: https://github.com/aharada54914/sdd-forge/pull/558
- Public head: `e97de1c849e05313fdebbd4c4901ff69a7f6b5c2`.
- Public base: `0b2951b6855bbd136938fafa901ee8af8bbe4855`.
- Exact-head CI: https://github.com/aharada54914/sdd-forge/actions/runs/38116113250
  completed successfully, all 37 Actions jobs successful. The fresh delivery
  bundle includes the API result and a compact job-by-job `ci-summary.json` with
  completion times and URLs, including native Windows, macOS, Ubuntu, POSIX
  inventory/shards, installers, MCP, CLI hooks and required-checks.
- Supplemental-delivery regression: 25 tests passed, including both validator
  runtimes and rejection of invalid legacy report/manifest bindings.
- Public original-path review-context-boundary regression passed: 32 citation
  checks; TEST-RCB-001 through TEST-RCB-010 Bash/PowerShell checks; embedded
  runtime regressions reported PASS 84, FAIL 0. Final exit code 0.
- Independent diff review found no blocking finding in the bounded legacy
  binding repair; independent citation review checked all 30 changed anchors.
  These are diff reviews, not a substitute for formal quality evaluation.

The owner checkout and public tree are deliberately not claimed byte-identical.
`projection.json` binds every public changed file to its admitted snapshot path
and hash, lists deletions, and marks raw peer reviewer outputs as excluded for
independence. The declaration separately binds current owner dependencies.

## Historical evidence remains historical

The frozen report SHA-256 remains
`266f4c37db646ba7eee2e5719a68e9b26df89a4b6c108f3175ee8f87825f0e5c`;
its implementation manifest remains
`565e5fcccf4b60629d24aad73a3d246c9e69b036a634829c211be63c68688a90`.
Their In Progress/NOT RUN fields describe that earlier execution, not this
addendum. No historical field has been rewritten or deemed successful.

Evidence in this task's verification directory distinguishes actual RED from
tests that already passed:

- `original-wiring-red.json`: exit 1, missing consuming dependency installation;
  `wiring-green.json`: exit 0, all 25 wiring checks passed after repair.
- `original-missing-ajv-red.json`: missing Ajv caused the structured-output
  regression to fail; `installed-ajv-green.json`: the same regression passed.
- `candidate-test013.json` passed registration-removal rejection. The corresponding
  `baseline-test013.json` also passed and is explicitly NOT RED evidence.
- `combined-rollback-20261011/combined-summary.json`: 78 targets restored with
  hash/mode parity, eight candidate suites and four restored-baseline suites
  exited 0. This is disposable rollback, not installed-host restoration or CI.

The old successful head `228cc336...` is not the current CI proof. The failed
intermediate `0a927c23...` citation check was repaired in `e97de1c8...`; only the
latter's successful run is used above.

## Additional original-path evidence

On the exact public head above, the complete Bash entrypoint finished with
`All POSIX regression tests passed.` and exit 0 (execution session 41853,
final command receipt bc5abf). This is an executed full entrypoint, not an
inference from a focused suite or CI job name.

The first complete PowerShell entrypoint exited 1 with exactly one failing
suite, `tests/install-uninstall-matrix.tests.ps1` (session 98200, receipt
251cbc). Its truncated output did not establish the failing assertion or
cause. The subsequent isolated complete matrix passed 21 checks, zero failed
(session 42785, receipt dd1434); the isolated Claude cell also passed six
checks (session 94274). Neither result erases the initial failure. The second
full PowerShell entrypoint completed with `All PowerShell regression tests
passed.` and exit 0 (session 91617, final command receipt acae15), with
untruncated output retained at
`/tmp/sdd-shared-launch-e97-pwsh-full-rerun.log`. The initial matrix failure's
cause remains unidentified; the successful rerun is recorded separately.

Fresh consuming-dependency preparation was executed in the public checkout:
`npm ci --prefix mcp/ci-mcp --ignore-scripts` exited 0, followed by
`python3 -B tests/task-structured-output.tests.py TaskStructuredOutputTests.test_output_schema_rejects_stringified_fields_without_fabricating_probe_verdict`,
which ran one test successfully and exited 0. The current lock SHA-256 is
`321d974a333c94eaa0335a3b2cdd7511817c59fab762cd4446d4e47cd6f1d02b`;
the capability contract SHA-256 is
`847fe86588ea22dcb0a13b7b61548aa254f22a8244aa5153e63efefe8a4d200e`.
The dependency audit reported four high-severity issues; this execution does
not claim a clean dependency audit or authorize unrelated dependency changes.

The native Windows heavy job's actual log, retrieved with
`gh run view 38116113250 --repo aharada54914/sdd-forge --job 114401280403 --log`,
contains these executed checks, not merely a successful job label:

```text
2026-10-11T05:58:35.8410109Z ./tests/downstream-review-precheck.tests.ps1
2026-10-11T05:58:36.6747784Z ok: shared impl/task reviewed-hash recipe matches baseline for CRLF, case, and invalid inputs
2026-10-11T05:59:16.2784075Z ok: PowerShell downstream prechecks fail closed and preserve graph semantics
```

## Remaining acceptance

Formal quality evaluation of this fresh bound set remains required. PR #558 is
still draft. Merge commit and post-merge CI do not exist yet and cannot be
asserted successful. T-004 must not be marked Done until its merge/post-merge
conditions and all other required conditions are actually met. This addendum
does not waive or reinterpret those conditions, approve a finding, or permit a
failed check to be bypassed.
