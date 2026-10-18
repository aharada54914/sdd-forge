# Current consumer inventory and parity audit

Pre-edit bytes: task-input-manifest.json + input-aliases.json. These bind the
entire inherited consumer/test input closure and current dirty candidate,
not an inferred Git baseline. consumer-inventory.json refreshes references to
the dispatch entry points across contracts, plugin, scripts and tests (73
matching files); the first attempt's broader 270-file inventory remains the
semantic inventory. This narrower refreshed search is not a claim that 73 is
an exhaustive count of all transitive dependencies.

Actual dispatch callers are check-contract.py/.sh/.ps1, evaluate-selected-plan.py,
cloud_verification.reduce/publish_collection and both public observe adapters.
Source-of-truth registry, root/packaged schemas, vendor generator, guard source,
guard generator and all four generated languages are the same inventory as
../evidence/consumer-inventory.md. No Foundation capability/stage enum changes.
The indirect bundle/traceability/criterion/panelist/quality-gate consumers still
invoke legacy gates; no saved cloud success can bypass them. Unchanged old
required check constants are asserted byte-for-value against initial probes
by version-inventory.py. Installer/test driver references do not opt into cloud
from file presence. No new dispatch caller was introduced during attempt 2.

Current root-mirror classification was refreshed before changes. Exactly three
already-applied stale mirrors and three entries across two existing manifests were
updated using sync-human-copy-mirrors.py; two sibling notes explain the refresh.
Pending files were not edited. This supersedes the first handoff's blanket
frozen-mirror interpretation, not any frozen review/spec byte.

## Separate WFI-012 sweeps

Operator sweep: powershell-operators-sweep.json lists every matched site.
The only T009 operator additions are exact schema `-ceq` and property-name
`-ccontains`, matching Python equality/key lookup. Existing legacy comparisons
remain byte-identical; this is additive dispatch, not a full rewrite/port.
Executed mis-cased value negatives are `Verification-contract/v3` and `Cloud`
in ProfileSavedConsumers.test_all_direct_consumers_explicit_selection_not_saved_authority.

Cmdlet/language sweep: powershell-cmdlets_language-sweep.json separately lists
Select-String/Get-ChildItem/split/regex/switch/Sort-Object/string-method sites.
No new site was added. ConvertFrom-Json and PowerShell property lookup can be
case-insensitive: cloud dispatch passes ORIGINAL raw bytes to Python's closed
case-sensitive parser, so lookup does not grant acceptance. The distinct
`Profile` property-negative fixture executes through Python, POSIX and actual
Linux PowerShell subprocesses. Old standalone legacy handling is unchanged.
No native Windows claim; tests retain their documented platform skips.

The newly executable portable pwsh test branch ran on this Linux host using
/workspace/.tools/sdd-forge-dev/bin/pwsh. It had previously been unavailable to
portable PATH discovery. It is exercised here, not left as a future CI claim.

## Chronology and sensitivity limits

Attempt 2 added tests against already implemented code, not historical Red.
The first expanded AWS sensitivity run rejected all mismatch assertions but
failed its bypass controls because the provider CLI loads its own contract
module instance. The test now patches observation.c (the actual callable's
module), not an unrelated imported module. No production guard was weakened.
The configured mypy check then found a heterogeneous fixture type (None control
reason); its explicit tuple union is corrected without suppression.

All AWS binding, execution option, exact-template, semantics, resource policy
and Modify-detail predicates have matched controls and selective guard bypass
checks. Plan leaf substitutions compare recomputed counterparts separately
from schema-invalid/unknown values. These demonstrate actual current guards,
not genuine IAM, native deployment or original exhaustive pre-implementation Red.

## Additional diagnostics, retained rather than hidden

- The added asset-readback test initially assigned to the ObservationWire
  wrapper rather than its delegated native fixture. The object actually read
  was unchanged, so the assertion failed. Corrected the fixture target and
  executed actual S3 body substitution, exact-template matched control, and a
  narrow read_object bypass. This is not a production Red or historical claim.
- The first broad guard-parity run passed all 262 core scenarios but its nested
  reader-input suite failed the `python` alias case: the deliberately restricted
  runner PATH supplied python3 but not python. Rerun explicitly adds the known
  installed Python directory; all 262 scenarios and all seven nested tests pass.
  No gate was weakened or SKIP substituted.
- The first disposable rollback lacked the AWS bundle used by execution fixture
  setup. This exposed an incomplete inherited dependency manifest. Added a
  separate validated dependency-input-manifest.json for actual T012/T013 input
  bundles, preserved the failing setup log, and reran: original 56 T006 tests,
  32 contract tests, 32 selected-plan cases (one native-Windows skip), and 163
  legacy gate assertions pass. Reapplication restores all 21 then-current
  profile tests; the later asset test is an additional final-byte check.
