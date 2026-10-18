## WFI-001 Pre-Implementation Mismatch Preflight

Recorded before production edits. `red.log`: 3 tests, 24 behavioral subtest failures,
zero errors. Ten fresh controls successfully submit; twenty stale/exact-deadline
cases wrongly submit once; four receipt-minimum cases retain consumer TTL rather
than predecessor expiry. These are executed real final guards and native fixture
submission counters, not inferred coverage. Earlier red-setup/red-second/red-third
logs contain fixture mistakes and are NOT the qualifying Red.

| Persisted field / acceptance claim | Counterpart | Executed mismatched-input Red |
|---|---|---|
| authorization.expires_at | minimum admitted predecessor deadline, OIDC exp, provider lease, iat + policy TTL, apply preview.expires_at | DependencyCallbackExpiryCases.test_receipt_expiry_minimum_and_empty_predecessors: both providers/stages emit 06:01:50Z instead of synthetic predecessor 06:00:10Z. Policy/OIDC/provider/preview and real empty-set controls pass. |
| provider result/state; native submissions zero when stale (AC-006) | Azure prepare what-if / apply PUT final receipt expiry guard after validation and journal work | test_azure_callback_freshness_validation_and_journal: fresh through last shared dependency admission, elapsed 10/11 only inside callback; one write observed instead of zero, real expiry guard executes. |
| provider result/state; native submissions zero when stale (AC-006) | AWS publish / CreateChangeSet / ExecuteChangeSet receipt lease guard after authentication, readback and execute history | test_aws_callback_freshness_readback_history_and_authentication: same injected deadline, elapsed 10/11 in callback while consumer/preview valid; target write observed once instead of zero. Prior legitimate prepare writes are not miscounted as target execute writes. |
| authorization receipt and submission journal retention (existing invariant) | exclusive publication/replay markers retained on failed final send | All callback cases assert actual journal existence. Existing admission/execution replay/revocation suites retained; no journal schema or identity field changes. |

The deadline stub is explicitly synthetic admitted-predecessor data, not provenance.
Real acquisition/cross-provider tests remain separate and unchanged. No final
provider guard is replaced: the assertion observer records then invokes the actual
assertion. No cloud/network calls are authorized.

Diagnosis: WriteBoundary discards first admit_predecessors return; expires_at lacks
its freshness bound. The later check is before provider callback work. Both provider
callbacks already consume the published expires_at in their final guards. The minimal
fix is to cap the existing receipt expiry before immutable publication, retaining
both authenticated acquisitions and all last consumer checks. No new wire schema.
