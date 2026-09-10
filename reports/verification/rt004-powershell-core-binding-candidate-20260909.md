# RT004 PowerShell historical core binding candidate

Status: partial unapplied patch data; not executable evidence, not a completed
repair, and not approved for human application. Ticket remains open.

Candidate: `adr-workflow-powershell-core-binding-candidate-20260909.patch`
SHA-256: `638fdf8cb6af214482d3f7c4041a7026d33427bca6a8243f314de073f936fc0e`.

Adds 95 lines before the actual `Test-PassedStage` definition at line 985.
`git apply --numstat` exits 0 without recount; it checks patch format only.
No patch application, extraction, candidate execution or product edit occurred.

## Scope

The helper checks paired exact-case ADR extension presence, sorted unique
canonical path/hash entries, identical contract/precheck ADR sets, all three
core pins, explicit empty-or-four-key layer maps and the precheck input digest.
The ASCII serialization matches the Bash candidate ordering: core pins joined
with colons, optional nonempty sorted layer object, then `:adr_inputs/v1:` and
the compact sorted ADR array. The corrected fixture's `acceptance_sha256` field
is used, never the nonexistent `acceptance_tests_sha256` field.

Legacy absent-extension records return a classification only: the full caller
must still reject ADR-like legacy manifest paths. The helper does not authorize
reads, certify identities or verdicts, or read current ADR bytes for history.

## Primary static review

No Critical finding in the bounded core helper. Exact field retrieval uses
Ordinal comparison, regexes use case-sensitive operators and strict end anchors,
and array return wrapping preserves empty/singleton fields. Restricted ASCII
paths and hexadecimal values contain no JSON escaping characters; explicit
serialization avoids locale ordering and serializer differences. SHA256.Create,
ComputeHash and BitConverter are used instead of newer .NET APIs; disposal is
in finally. These are static observations, not a Windows PowerShell test result.

An initial missing-layer-map fallback was removed during primary review because
the Bash extended-record candidate requires an explicit object. Both sides now
distinguish the valid empty object from absence or null. Old legacy records do
not enter this validation branch.

Remaining blockers before integration/application: safe file snapshots and
strict JSON object loading; reviewer identities/check outcomes and summary
counts; role-scoped manifests and previous/current summary bindings; invocation
of the existing shared-layer candidate; call before opening early return; current
declaration checks and ADR manifest allowlists. JSON duplicate-property handling
must be resolved at the reader boundary, not inferred from PSCustomObject fields.
The helper-only candidates are not a substitute for those checks.

Next: compose full history caller and reader boundary, then independently review
the complete consumer patch. Actual runtime regression and native Windows tests
remain unexecuted until the protected patch has been reviewed and human-applied.
