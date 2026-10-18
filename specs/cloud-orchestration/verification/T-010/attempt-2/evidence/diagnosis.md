# Combined-suite fixture interaction and correction

`continuation-interaction.log` reproduced the A/B/C failure after preceding provider
classes. A scoped exception trace at AzureExecutor.prepare recorded
`ContractError OWNER_UNSUPPORTED`: Azure exact_artifacts called **AWS**
`plugins/sdd-aws-cloud/scripts/cloud.py:detect_owner`. The providers' CLIs deliberately
share the `cloud` module basename; B/C construction reused the previously imported
AWS module in this in-process multi-provider fixture. The isolated test lacked that
prior import and passed. This was not predecessor-admission denial.

Correction: A/B/C uses the already-established AzureTestBase scoped sys.modules/sys.path
isolation before constructing the actual Azure adapters. Each adapter explicitly
asserts its detect_owner implementation comes from the Azure CLI. All original
A/B/C success/failure/zero-submission/immutable-byte assertions remain intact.
No production admission guard was changed. Subsequent combined-scope results are
recorded separately; the original failure logs are preserved.

Diagnostic command: python3 -B <scratch>/trace-failure.py tests/cloud-orchestration-verification.tests.py AlarmNumericCases AwsObservationOrchestration AzureClosureAndDcrCases AzureCompletionCases AzureMetricContextCases AzureObservationOrchestration AzureResourceBindingCases DependencyBoundaryCases.test_three_actual_adapter_units_partial_failure_preserves_a
The trace only inspected caught exceptions in AzureExecutor.prepare for unit-b;
execution used evidence/run-scoped.py's exercised parent/CLI urllib guards.

## Follow-on scoped regression findings

The first continuation execution run exposed a redundant fourth verify_binding call
in WriteBoundary. The unchanged T003 expiry tests require the three original binding
checkpoints and assert expiry is checked after the final one. Removed only the new
redundant pre-acquisition check: final consumer metadata still follows dependency
acquisition, and final binding/freshness/expiry checks still immediately precede
submit. Admission's 26 tests then passed unchanged (continuation-admission-green.log).

The first routing run exposed a harness issue: runpy does not insert a script's
parent into sys.path, unlike normal non-isolated `python script.py`. The offline runner
now preserves that native search-path behavior for non-`-I` CLI children, while
retaining isolated mode behavior. No provider product changes were made for this.
Also added exercised PATH shims to guard Python grandchildren launched by shell or
PowerShell, not only direct Popen Python children. Historical logs are retained;
final scoped logs use the corrected runner and explicit local native tool paths.

## Rollback reconstruction dependency

The first disposable baseline run failed only T009's pre-existing registry-protection
assertion: the entry Git commit predates the dirty T009 guard-invariants membership,
and that shared dependency was omitted from the initial input map. The initial
five T010 product/test snapshots were correct and were not replaced. Declared and
snapshotted the unchanged current guard-invariants.json as a supplemental regression
input, overlaid it only in the disposable checkout, and restarted the experiment as
rollback-run2. rollback-run1 and its failure remain intact. This is a reconstruction
fix, not a code rollback success or historical test claim.
