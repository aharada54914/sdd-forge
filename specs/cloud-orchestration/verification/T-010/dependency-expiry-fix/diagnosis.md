# T-010 dependency-expiry diagnosis and evidence interpretation

Scope: RT-20261018-CLOUD-DEPENDENCY-EXPIRY only. No task/status/ticket or frozen
specification edits, and no T009 waiver. Actual native run/session/agent is
01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c, attempt 3.

## Cause and smallest shared fix

`cloud_authorization.py` discarded the first `admit_predecessors` result. Its
receipt `expires_at` bounded only OIDC/provider/policy/preview time. Reacquisition
and the last dependency check happened before `submit(credentials)`; provider
callbacks still did work before sending. Azure `mutate` reads the receipt then
validates and journals before its final expiry guard. AWS `mutate` reads the same
receipt into its existing lease, then publish/create/execute callbacks do native
readback/history/authentication before their final guards.

The change retains that first authenticated minimum deadline and caps the existing
expiry before immutable receipt publication. Both provider final guards already
consume it. The second authenticated acquisition, final consumer metadata/binding,
expiry, replay markers, journals and read-only recovery paths are unchanged. The
admitted predecessor bytes/profile are pinned, not refreshed into a different
unbound receipt on the second acquisition. No provider file, wire schema, signing
system, authority source or dependency acquisition logic changed.

## Precision and collateral bounds

The receipt has strict whole-second UTC expiry, and final guards use exclusive
`now < expiry`. Predecessor freshness previously used inclusive `now <= deadline`.
The cap deliberately rejects the endpoint second rather than granting any extra
freshness window. No rounding up or +1-second allowance is introduced. Empty
predecessors return None and leave the old expiry calculation unchanged. Earlier
consumer OIDC/provider/policy/preview deadlines still win. AWS already uses this
same lease for callback reads; expiry during history or early readback can therefore
block at READ_CREDENTIAL_EXPIRED before reaching the last-send check. The separate
final-authentication cases reach the actual final CREDENTIAL_EXPIRED guard for all
three AWS mutation types; Azure validation/journal cases reach its final guard.

## Test provenance and chronology

- `before-*`: actual entry candidate, 106 verification + 86 execution + 86 routing
  + 33 contracts = 311 passing tests, not a rewrite of historical 311 evidence.
- `red-setup.log`, `red-second.log`, `red-third.log`: retained fixture construction
  mistakes (assertion observer signature/default, UTC aware versus existing naive
  contract datetime, wrong separately loaded contract module observer, and Azure
  apply-refresh timing rather than PUT timing). These are not qualifying Red.
- `red.log`: corrected original regression executes 3 tests / 52 matrix scenarios,
  with 24 behavioral failures, zero errors. Ten callback fresh controls write once;
  twenty exact/expired callback cases wrongly write once; four predecessor-minimum
  receipt cases retain the consumer TTL. Real provider final guards and wire
  counters execute, while consumer credential/preview remains fresh.
- Commit `2c2caf3f` records that Red and the preflight before production edits.
  Its explicitly staged verification file includes prior dirty candidate edits;
  only the added DependencyCallbackExpiryCases is this repair's new Red.
  `entry.json`, `red-ordering.json`, `before/`, and `task-delta.patch` disambiguate
  the exact repair delta from the Git commit's larger candidate snapshot.
- `green-first.log`: the fix already prevented every target write, but six
  instrumentation assertions overlooked the earlier AWS read-lease guard. The
  observer was expanded to record the actual read-expiry failure without bypassing
  it; authentication latency was focused on final_admission rather than history
  metadata. The production fix was not altered. Final tests additionally require
  an actually failed expiry guard for each expired scenario. `green.log` passes.
- `mypy-first.log`: missing list annotation in test instrumentation, corrected
  without suppression. Configured final Ruff/mypy both pass.
- The rollback experiment reruns the refined tests with the entry production
  bytes to show defect sensitivity, then reapplies the exact fix. Its result is
  code rollback only, never a resource rollback or live authorization.

The focused deadline is a clearly labeled synthetic *admitted* predecessor minimum.
It isolates boundary handoff, not provenance. It does not assert that an empty
consumer fixture acquired a real predecessor. Existing actual collector/acquisition,
protected pin matrix and cross-provider tests remain separate and run unchanged.
All cloud responses are protocol fixtures. Genuine installed local Bicep/CDK
compilation/synthesis in routing is not evidence of live IAM/deployment/health.

## Disposable rollback dependency correction

The first checkout reconstructed the initial manifest plus declared shared guard
modules. All 106 entry verification tests passed, but one of 86 execution tests
could not find the official CloudFormation API model (StopIteration). The other
85 execution cases passed. This was a missing unchanged test input, not a product
failure; all original run logs, command/result JSON and driver source are preserved
under `rollback-first/`. `regression-dependencies.json` and the separately validated
`regression-dependency-manifest.json` bind the exact existing official API-model
bytes consumed by the execution suite. The corrected experiment reconstructs that
input too and reruns baseline/restore checks; it never weakens or skips the case.
