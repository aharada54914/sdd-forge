# T-004 exact-head delivery supplement, 2026-10-11

This non-frozen supplement preserves all earlier reports and verdicts. It is
neither a quality verdict nor a task-state transition.

## Candidate and CI

- PR: https://github.com/aharada54914/sdd-forge/pull/558
- Head: `2f1ea5bab59609af66323f053a356a45f0666e49`.
- Base: `0b2951b6855bbd136938fafa901ee8af8bbe4855`.
- Exact-head CI: https://github.com/aharada54914/sdd-forge/actions/runs/38128074675
  completed successfully: 37 jobs successful, none unfinished. Required-checks
  job 114439823184 completed at 2026-10-11T09:40:28Z. The new delivery bundle
  retains the API job list rather than relying on the previous head's CI.

## Authorized bounded diagnostic repair

The only change since `e97de1c849e05313fdebbd4c4901ff69a7f6b5c2` is
`tests/install-uninstall-matrix.tests.ps1`: on the existing idempotency failure
branch, print case-sensitive differences in relative paths and SHA-256 values.
The assertion, success branch, failure count, and test count are unchanged.
The file SHA-256 is
`dd7ce269ddde8c9aebc555e3fe312c8c8d8164a72116af5bd0db42581fd6d2c2`.

The AST-extracted real branch was exercised with changed, added and deleted
entries and unchanged input. Failure diagnostics contained four difference
rows with relative paths, hashes and direction; unchanged input remained PASS.
The complete isolated matrix passed 21 checks, zero failed. Evidence is in
`/tmp/sdd-matrix-diagnostics.llWyuV/evidence.md`; its fixture script SHA-256 is
`d6c5afd3200edf7e70c4209fb76408c78c8dd0aa7bf784b30ec166eea2a36ac0`.
Independent diff review reran the focused fixture and checked empty-array,
addition/removal cases and whitespace; it found no blocking diagnostic defect.

The original full PowerShell matrix failure remains unexplained. Successful
isolated/full reruns and current CI do not establish its root cause or prove
that this diagnostic-only change fixes it. The earlier failure is retained in
`public-e97-delivery-20261011.md` and must be evaluated as a residual risk.

## Independently verifiable public projection

The fresh bundle includes raw Git commit/tree objects and non-peer before
blobs. `public-git-evidence.py` verifies their object identities and derives
the changed paths, modes and after bytes independently of the projection's
claims. Current coverage is 144 changed paths, 144 trees and 87 before blobs.
Six raw peer-review bodies remain excluded for reviewer independence; their
Git blob OIDs, not an unverified content SHA-256, bind their excluded identity.

Self-tests against both public heads rejected nine corruptions each: commit,
tree, before blob, head binding, missing tree, missing path, peer inclusion,
peer blob identity and changed after bytes. This verifies the evidence helper,
not the product or formal review. No frozen implementation report, manifest,
historical output or verdict was rewritten.

## Remaining acceptance

Fresh formal evaluation is required. Merge and post-merge CI have not occurred.
Pre-merge technical readiness is distinct from the final Done decision; no
pending delivery condition is asserted satisfied here. The four-point input
architecture work remains sequenced after this delivery.
