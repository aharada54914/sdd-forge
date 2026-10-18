### Executed field/counterpart/mismatch preflight (before production edits)

| Persisted packaging claim / field | Counterpart | Executed mismatch test |
|---|---|---|
| Retained provider runtime scripts: cloud_contracts.py, cloud_authorization.py, cloud_verification.py, cloud_dependencies.py | Current trusted staged quality-loop scripts, byte for byte | test_sequential_selections_rebuild_prior_runtime: canonical bytes subtest lists every absent/mismatched module after both orderings and default/non-cloud updates, both shells |
| Retained protected registry and each cloud/v3/v2 schema | Current trusted staged registry, root cloud schemas and quality-loop schema mirrors | Same test compares every runtime_sources entry; prior files are deliberately tampered before update |
| Installed direct route PASS and predecessor enforcement | REQ-011 / AC-011 / TEST-011 distribution; actual installed cloud.py and canonical predecessor contract | Same test: direct route fails with SHARED_RUNTIME_UNAVAILABLE after update; preserved helper requires matched/restored PASS, exact missing UNSAFE_OR_UNAVAILABLE_FILE and invalid CHECK_SET_MISMATCH |
| Unauthorized prepare/apply stays BLOCKED | Existing OPERATION_UNIMPLEMENTED no-executor boundary, not CI admission or live IAM | Same helper executes both operations after every update; missing runtime prevents this check on Red, original fresh-install control passes |
| Required prior payload rebuild failure leaves destination unchanged | Existing staging-before-replacement boundary, complete pre/post installed-file hashes | test_prior_runtime_rebuild_failure_preserves_installation: removing canonical dependencies from the export index wrongly succeeds and loses runtime; four dependency groups, both shells |
| Unselected provider is not materialized/registered | Unchanged explicit selection/dependency and default registration lists | First-selection negative checks in sequential test pass on entry; existing installation/matrix regression checks retained |

No new persisted cloud contract, verdict, authority, or installer state fields.
Identity/evidence hashes use the existing manifest/report validators, not invented schema.
All genuine Red output is retained in red-sequential.log and red-direct.log;
these tests were added against the existing candidate, not represented as its historical Red.
The test/preflight commit precedes install.sh/install.ps1 edits. CLI and byte
failures are separated so missing modules cannot hide actual route invocation.
