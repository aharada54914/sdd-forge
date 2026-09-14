# Issue 288: fresh input completeness repair

Status: local regression verified; formal review, PR CI and merge pending.
This report does not change any task status or historical review verdict.

## Scope and cause

The main-based validators admitted fresh spec/impl manifests omitting an existing
investigation file. Historical review verification must instead retain the inputs
recorded at reservation time. See the reproduced failures in
https://github.com/aharada54914/sdd-forge/issues/288#issuecomment-5668087515
and the read-only preflight reproduction in
https://github.com/aharada54914/sdd-forge/issues/288#issuecomment-5668248931.

The human-applied repair checks completeness only for fresh identities, for both
reservation and preflight. Task-stage authorization is unchanged. PowerShell uses
ReparsePoint to reject redirected paths without incorrectly rejecting hardlinks.
The existing isolation suite now removes its rejected symlink fixture before
testing a later valid reservation. No rejection assertion was removed.

## Executed verification

Host: macOS with Bash and PowerShell; no native Windows result claimed.
Base: cfe65c02b604cb6426e7405b9244d00bb0ace67d plus this working-tree diff.

- Integrated review-context-boundary suite: exit 0; 31 citation anchors and
  existing reservation/verification cases passed, followed by 252 additional
  cases (84 each for regular files, hardlinks and symlinks).
- Reviewer isolation: exit 0, including 26/26 scratch-history regression cases.
- Spec precheck, downstream precheck, downstream parity, task precheck,
  review-contract foundation, loop consistency, implementation layer inputs and
  task layer inputs passed. Platform/activation skips are not treated as coverage.
- Whitespace check passed.

The new Python driver exercises actual validators against temporary fixture
ledgers; it does not reserve live identities. Both roles, both runtimes, spec/impl
and task stages cover omissions, declared inputs, hash disagreement and historical
creation. Failed admission must leave the ledger unchanged. Successful fresh
reservation must append the expected role; preflight and historical verification
must not write the ledger.

The boundary driver is listed in tests/suite-inventory.posix and runs under the
complete POSIX CI fallback. Runtime failures are not converted into skips.

## Local log hashes

| Log | SHA256 |
|---|---|
| /tmp/sdd-issue288-integrated-boundary-20260915.log | c2c2b8a9f0df84537e8fbd42181c882f133dbb49a175be7456193d667eb20432 |
| /tmp/sdd-issue288-isolation-fixed-20260915.log | f5024597c726672e2b966ddcdde160e9e76aed56707fc67fee75c16c421280d8 |
| /tmp/sdd-issue288-layer-related-20260915.log | 009566866bd8d93835e922caa42e132813089d79175c35b53fbdad3545d5f54a |

## Code review

Self-review found no Critical defect in the scoped diff. Numeric documentation
anchors were updated to the actual validator lines. Existing history, scratch
binding, authorization and hash checks remain intact. This is not an independent
quality-gate PASS. Native CI, required review and safe merge remain outstanding;
Issue 288 must stay open until those conditions are met.
