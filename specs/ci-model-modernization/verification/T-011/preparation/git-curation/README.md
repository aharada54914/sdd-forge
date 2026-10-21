# Final Git curation proposal — T001–T009

This is read-only preparation, not a staged commit or formal quality verdict.
The observed HEAD is `2c78757a8f97d052efa59f50d24b8cbc541b3a89`.
The index was empty. No Git mutation, network operation, credential lookup,
redaction, deletion or source edit was performed. Only this preparation directory
was written. The working tree is shared and still changing. T008 is now Done
with QA2 PASS; this bounded refresh includes its final proof. Refresh provisional
task/traceability metadata and T010/T011 additions again before final F.

## Explicit proposed delta

- `source-stage-list.txt`: 71 exact repository paths, about 1.76 MB. Current
  product/test/contract changes, task/traceability metadata, and nine required
  schema/acquisition fixtures are included. Already-committed test additions and
  ordinary tracked fixture dependencies need no additional stage operation.
- `evidence-stage-list.txt`: 792 exact paths, about 16.35 MB. Implementation
  records, current quality reports/contracts/bundles, their execution receipts,
  Red/Green logs and bounded explicitly referenced provenance are separated from
  product sources. The large T005 original Red log is actual test evidence,
  not a new API payload dump.
- `already-tracked-closure.txt`: 2004 supporting files already tracked and
  unchanged at inspection. Do not restage or rewrite them just to make a release.
- `proposal-manifest.json`: existence, tracked/change status, exact SHA-256, mode,
  reference reasons and nested-Git check for every proposed delta path.
- `excluded-paths.tsv`: explicit path-level exclusions. About 9,700 local
  paths remain outside the proposal, principally disposable workspaces,
  snapshot/staging copies, historical Outputs not required by current gate
  closure, future-task preparation and mutable allocation/identity records.
  Exclusion means retain locally, not delete.

These counts describe the recorded pass; `summary.json` is authoritative after
each refresh. Never turn this into `git add specs/` or `git add reports/`.
The listed files are a concrete proposal, not permission to stage unreviewed
later bytes. Compare each current digest to `proposal-manifest.json` first.

## Non-obvious runtime/test closure

The installers' tracked-source payload references four currently untracked
runtime/control files: `managed-model-entry.py`, `model-policy.py`,
`contracts/model-policy.v1.json`, and
`contracts/model-launch-controls.schema.json`. All are in the source proposal.
The other new model/CI schemas and CI helpers are included as well.
`installer-payload-checks.json` records both Bash/PowerShell literal dependencies.
Do not interpret source-directory installation from a dirty, untracked tree as
proof that the final committed payload is complete.

Nine files currently located under T004 verification are genuine test fixtures:
the two `native-schema/*acquisition.json` records, their six pinned schema files,
and
`T-004/quality-cycle1-fix/final/native-readonly/generated-schema/v2/ThreadStartParams.json`.
`tests/model-observation.tests.py:1220` loads/pins the acquisition records and
their files. `tests/model-policy-installed.tests.py:2550` and `:2935` load the
ThreadStartParams fixture. Those nine files are therefore in the source list
even though other duplicate schema/source snapshots remain excluded by default.
Their acquisition hashes were checked; `test-fixture-dependencies.json` records
the precise consumers. Keep existing source/provenance notices intact.

## Bounded T008 refresh and later work

T008 final QA2 is PASS0C/0M/0m, and its bundle's 12 artifacts match current
bytes. Its frozen implementation report remains
`eef500e6dcdbed4236bdc356645c2e7abe41e39729b7ca8ff4f169cfca4fc280`.
`missing-closure.json` is empty. This preparation validates curation, not the
test verdict again.

All224 Outputs have explicit dispositions in `t008-outputs-disposition.json`:
29 source deltas, 181 evidence deltas, 13 already tracked, and one excluded
superseded report-history narrative. All included hashes match.
The381 supplemental factual additions have their own disposition table:
190 evidence deltas and191 exclusions. The old cycle1 declaration is a
separate additional reference, not a382nd factual input.

`t008-curation-policy.json` is the explicit bounded T008 admission list.
The supplement declaration's full artifact array is never used as a stage
allowlist. The current installed78/shared54/legacy10, default Red, combined
lint/typecheck, batch/caller Red and whole rollback receipts retain raw logs,
controllers and source-pin metadata within this boundary. QA1's actual FAIL
report, actual evaluator answer and post-review provenance remain unchanged;
QA2's report, answer and provenance are also included.

Invocation, allocation/ledger, private provider/account/native material,
snapshots and binary archive stdout are excluded. The28,088,320-byte legacy
archive stdout remains local: `t008-archive-omission.json` records its existing
command/hash evidence and explicit non-distribution/non-expansion limit.
`t008-reference-omissions.json` distinguishes metadata/provenance references
from distributed bytes; omitted admission inventories and raw private evidence
are not silently claimed as public replay inputs.

Root explicitly approved three exact T005 archive exceptions to close required
rollback proof links. The evidence list includes
`quality-cycle1-fix/rollback/before/plugins/sdd-implementation/scripts/model-policy.py`,
`quality-cycle1-fix/rollback/before/tests/verification-catalog.json`, and
`quality-cycle1-fix/rollback/before/tests/verification-catalog.tests.py`, all under
`specs/ci-model-modernization/verification/T-005/`. Their original bytes and modes
are recorded in `proposal-manifest.json` with `archived_proof_only: true`.
These are historical evidence, never current runtime payload. No surrounding
archive tree was admitted by this exception.

The passed bundle artifact digests for T001–T009 all match their
current files. This does not assert that every historical Outputs row, reviewer
input snapshot or old rollback workspace is shipped. Preserve the exact frozen
reports and bundles; `frozen-record-pins.json` records their inspected hashes.
Source hashes in old reports
can legitimately name predecessor bytes superseded by later tasks; do not
rewrite those historical hashes to match today's product.

The inspected current ci-model-modernization contracts/bundles use `risk: high`;
T001's current bundle has no signature field. Root confirmed using that actual
state. No risk was downgraded and no signature was invented or rewritten.
Any separate historical critical task/signature remains outside this curation.

T010 actual trials and T011 doc/version/activation/release outputs are not
invented or included early. Add their final authorized bytes after completion.
The prepared T011 document outlines remain preparation only.

## Privacy review

`sensitive-findings.tsv` reports path, line and type only; matched values are
never printed. The final candidate scan has four field-name findings:

- `model-policy.py:400`: source-code `apiKey` handling, not a printed credential.
- `native-schema/v2/GetAccountParams.json:4`: schema property `refreshToken`.
- `native-schema/v2/GetAccountResponse.json:24`: schema property `email`.
- T005 archived `model-policy.py:384`: source-code `apiKey` handling.

These are code/schema definitions rather than observed account values. The
recorded candidate scan found no credential-shaped token, private-key marker or
non-reserved email address; `privacy-hold-paths.txt` is empty. This is a bounded
heuristic scan, not a guarantee covering unselected/raw private artifacts.
Native acquisition summaries inspected during preparation retain booleans,
method names, counts/types and source hashes rather than account email/token
values. Literal schema properties are not actual account probes.

Raw native events/stderr, account responses, credentials, private provider
responses and personal-account probe material must remain private by default.
If T008/T010 final references introduce such files, record only necessary
public proof in a new bounded addendum: CLI/version, documented methods,
observation status, source hashes, configured-versus-actual identity level and
verdict. Do not publish personal email, account IDs, scopes or token/auth-code
values merely to prove authentication worked. Do not redact a hash-frozen
artifact in place: retain the exact private original and create separate
explicitly scoped public evidence if needed.

## Root handoff

1. Refresh the bounded candidate with
   `python3 -B .../git-curation/inspect-curation.py`, then
   `python3 -B .../git-curation/reconcile-t008.py`. Both write only this directory.
   Do not widen `t008-curation-policy.json` to the full supplement inventory.
2. Resolve exact missing closure entries and new privacy findings; inspect
   owner attribution for all changed sources and preserve unrelated changes.
3. Add completed T010/T011 artifacts and version/doc updates deliberately.
   Check every proposed path still exists, is not a symlink/nested checkout,
   and matches its recorded digest. Check the index's explicit path list.
4. Create the curated final product commit only under root's existing release
   authorization. Run clean isolated full-local and full-hosted validation at
   that exact commit as described in `../execution-checklist.md`; this proposal
   does not supply those results.

Live cloud #911 remains unresolved. This development environment is not the
owner-authorized cloud acceptance sandbox, and this curation performs no cloud
writes. Publication does not change that acceptance boundary.
