# WFI-001 pre-implementation checklist

Recorded before any product edit. New contract is verification-contract/v3,
explicit profile=cloud. Runtime selection reserves cloud-compute version 2;
old profile and legacy contract versions remain unchanged. Root provenance
clarification is admitted in supplemental-task-input-manifest.json.

| Persisted field/group | Counterpart | Executed failing-mismatch test / planned Green guard |
|---|---|---|
| profile id/version, schema | protected registry allowlist, profile reference | ProtectedProfileCases.test_unsupported_profile_version_at_reducer (matched request/profile with unsupported version); existing reducer currently accepts, assertion must fail |
| old schema + cloud discriminator | explicit v3-only selection | ProtectedProfileCases.test_legacy_cannot_accept_cloud_discriminator: real check-contract subprocess currently ignores reserved field |
| feature/task identity | request.local_context | saved v3 mutation matrix; compare before selection publication |
| request/preview/verification path+sha256 | exact bytes and strict cloud schemas | saved v3 mutation matrix; safe read_verified paths, byte-digest mutation |
| profile reference and required IDs | request/profile/registry/policy backup requirement | saved v3 and reducer mismatch matrix with matched controls |
| bindings request/verification/registry hashes | independently computed input bytes | selected plan mismatch and projection drift tests |
| checks[].id/required/result/evidence | fixed preflight + reducer checks; all mandatory | saved plan and fresh publication assertions, each missing IaC/provider check denied |
| verdict/selection_result | fresh native evidence_complete, not saved labels | saved consumers always BLOCKED; synthetic public result BLOCKED; fresh native protocol double explicitly not live proof |
| original preview fields/semantic digest | original request, scope, policy/lock/profile, semantic bytes | preview mismatch matrix at publish_collection; executor.check actual schema/policy negative cases |

Only the first two Red tests can execute against existing callable validation;
new-schema tests initially fail at version/module availability and will NOT be
claimed as executed mismatch coverage until each body runs in Green. Every new
field must receive a matched control and sensitivity check before completion.
No report, task or traceability status is advanced by these tests.
