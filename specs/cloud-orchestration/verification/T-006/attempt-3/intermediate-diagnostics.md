# Actual intermediate diagnostics

- Baseline verification: 36 tests PASS.
- Initial Azure DCR source URL missed the `Insights/` directory: HTTP 404.
  Role definitions fetched successfully; DCR reused the previously acquired
  official model, with exact source URL/hash in the supplemental manifest.
- `red-closure-dcr.log`: 3 tests, 29 failed subtests, 1 error (native quarantine).
  Existing collectors ignored proposed closure/DCR responses; not executed new
  guard validation. `red-explicit-dcr-config.log`: 44 errors at closed config
  admission, not native DCR mismatch execution.
- `green-first.log`: 39 tests, one error (Azure unhealthy caller rights now rejected
  as incomplete rather than unhealthy), one failed optional-backup fixture (it
  still returned backup assignments after removing configured backup). Adjusted
  observed excess-right classification and corrected fixture assignments.
- `red-current-operation-metric.log`: 3 tests, 16 actual mismatch failures.
- `public-matrix-first.log`: 5 tests, one fixture-target failure. Unhealthy Azure
  resource fixture changed VM provisioning state, but injection targeted only
  instanceView. The fixture now returns an actual stopped state for that read.
- First direct configured mypy call (before log wrapper) reported six test-only
  typing errors: aliased setup/helper self types, mixed dict inference, union
  harness assignment and scoped patch keyword inference. Fixed with a shared
  unittest base, static helper, explicit dict/union types and separate scoped
  mock construction. No blanket suppressions or missing-import suppression.
  This paragraph records the actual terminal diagnostics, not a manufactured log.
- `red-unknown-expiry.log`: four unknown-native-state rejection failures and
  Azure final lease publication failure. AWS final lease already blocked.
- `red-workload-range.log`: 5 failures/3 errors across eight subtests. Both
  collectors accepted below-minimum within-bucket data; healthy/high controls
  additionally detected missing requested Minimum (AWS KeyError/ Azure assertion).
- Early discovery commands attempted nonexistent plugin reference paths and an
  example `main.bicep`; correct paths were discovered and read. These were file
  discovery errors, not product/test results.

All before/after logs and prior handoffs remain unchanged. Missing components or
masked native quarantine negatives are not relabeled as historical guard execution.

## Sensitivity found a test-oracle defect (corrected, not counted as PASS)

The first disposable rollback reached azure-metric-context with exit 0 after
removing its namespace guard. This was **insensitive**, not a valid mutant kill.
Changing the shared helper to staticmethod had left an alias as an ordinary bound
method; it passed `self` as the `native` flag, selected HttpsTransport, and mocked
only the unused fixture. Those negative cases could attempt read-only HTTPS with
the literal synthetic token/fictional target and accept the resulting denial as
the expected ValueError. They are invalid guard evidence; no authenticated native
success or live acceptance is claimed. No write path or real credential was used.
Fixed the alias as staticmethod and added a module-scoped unittest mock that raises
AssertionError on any actual urllib open. Both direct suite and matrix runner use
setUpModule. Preserved all first rollback logs in rollback-first/ and pre-fix
checks in checks-before-network-guard/. Rerun sensitivity must fail at assertions
with the actual fixture body, and the final suite must pass with live I/O forbidden.

Final configured mypy caught two typing errors in the new network sentinel's
unbound `OpenerDirector.open(None)` call. The mocked call was safely intercepted
and all 52 guarded tests/720 subtests passed, but that is not static PASS. Replaced
it with a correctly typed instance call, still after asserting the method is a
Mock. Preserved failing static log and prior successful test/matrix results under
before-sentinel-type-fix/. Repeated affected checks and final rollback/sensitivity.
