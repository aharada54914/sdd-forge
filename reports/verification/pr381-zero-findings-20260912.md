# PR #381: completed cross-critique with zero findings

Base commit: 3e768d1e92a72c2413184ed599e7b17a248430da
Review thread: https://github.com/aharada54914/sdd-forge/pull/381#discussion_r3993000958

The completed annex incorrectly required at least one verdict even when the
review produced no findings. Remove only that lower bound. A verdict array is
still required; each nonempty entry retains its existing validation. Unavailable
reviews still require a reason and an empty array. No review status is changed.

## Verification

- RED: compiled the MCP tests and ran the new `completed zero-finding` test
  against the original schema. Exit 1: the legacy completed empty annex was
  rejected with `schema-invalid` (expected CLI exit 0, actual 1).
- GREEN: `npm test` in `mcp/sdd-forge-mcp`: 270 passed, 0 failed, 0 skipped,
  exit 0. The new test exercises 18 canonical CLI cases across legacy,
  sdd-gate and standalone-adversarial lanes, including invalid and unavailable
  cases and checks that validation does not modify the input bytes.
- `npm run typecheck`: exit 0.
- `git diff --check`: exit 0.
- Local full-suite log: `/tmp/pr381-zero-findings-mcp-20260912.log`.
  SHA-256: `16667ce13782461b8ba3c789f40623bd7e4124a23ac3b79499070b66aefcaf3d`.

Scope review: inspected the complete schema and canonical CLI; citation bounds,
severity vocabularies, evidence requirements and unavailable-state constraints
are unchanged. This is a local repair verification, not an independent gate
verdict or proof of latest-head CI success. CI wiring and scratch-root review
findings remain separate outstanding work; this report does not authorize merge.

## Repository-wide regression follow-up

The full CI fallback runner subsequently exposed an old root contract test that
still required completed annexes to contain findings. Its assertion failed with
`complete annex needs verdicts: unexpectedly valid` (expected false, actual true).
This was not covered by the MCP-only test run above.

Updated that expectation to accept completed zero-findings reviews and added
explicit rejection assertions for a missing verdict array, a malformed verdict,
an unavailable review missing its reason, and an unavailable review containing
verdicts. Existing citation, severity, scope and concern checks remain intact.
`bash tests/adversarial-review-contracts.tests.sh` now exits 0. The original full
fallback run is retained in `/tmp/pr381-ci-fallback-full-20260912.log`; its failure
must not be reported as a successful full-suite run. Latest-head CI and remaining
scratch isolation findings still require resolution before merge.
