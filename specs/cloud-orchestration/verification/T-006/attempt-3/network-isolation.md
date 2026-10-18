# Network-isolation correction and limits

The affected case is AzureMetricContextCases.test_metric_context_counterparts,
with fields namespace, resourceregion, interval, timespan, id and metadata-duplicate.
The staticmethod-alias defect selected real HttpsTransport while patching only
NativeFixture.request. It was introduced during test typing cleanup, after the
original metric-context Red. It was exposed by the first disposable
sensitivity-azure-metric-context mutant surviving (exit 0), not by a cloud result.

Affected preserved invocations:
- checks-before-network-guard/final-verification.log
- checks-before-network-guard/matrix-runner.log and matrix-execution.json
- rollback-first/rollback-candidate-verification.log
- rollback-first/sensitivity-azure-metric-context.log

These six negative subcases per invocation could enter actual read-only urllib
HTTPS with the literal synthetic token and fictional subscription. Transport
attempts/responses were not instrumented; their actual network delivery and
count are unknown. No authenticated success or write path is claimed. These
cases are invalid guard evidence, regardless of the aggregate PASS. Official
GitHub/documentation GET acquisition is a separate, intentional activity.

Correction: staticmethod alias, correct independent wire fixture, and module-wide
OpenerDirector.open mock raising AssertionError (not a swallowed ValueError or
OSError). A sentinel test proves the guard is installed before invoking it.
Direct test execution and all rollback/sensitivity commands use unittest's module
fixtures. The matrix runner registers the loaded module in sys.modules so those
fixtures run. The child-process public CLI entry also installs the AssertionError
network guard before running the actual cloud.py __main__ entry.

rollback-second/ records the first successful corrected 20-mutant experiment.
Final root-level rollback logs repeat it on final test bytes including the guard
sentinel and exact native byte-digest assertions. Only final guarded results and
corrected sensitivity are cited as acceptance evidence; prior files are retained
for chronology. This is local synthetic verification, not a sandbox trial.

The final rollback driver additionally installs an outer AssertionError network
mock before runpy executes **every** test command, including the restored entry
candidate that predates setUpModule. Each final rollback/sensitivity log records
OFFLINE_GUARD_INSTALLED. Final normal and matrix sentinel controls prove their
module guard is installed. No provider request is needed to test the prohibition.
