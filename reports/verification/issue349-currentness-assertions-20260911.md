# Issue 349: currentness acceptance coverage

Base checkpoint: 2811770df1dc072ebf0e43dbd834bf6c08777284 (PR #371).

The existing successful-currentness fixture asserted only `status: current`.
It did not assert the returned head, merge base, or report digest, despite
Issue #349 requiring exact target identity. The test now compares the entire
success object against the fixture's actual Git commits and independently
computed report digest. No production implementation or validation contract
was changed, and no pre-fix production failure is claimed.

Three additional cases exercise the real CLI with correctly hashed reports:
an extra token field (synthetic value only), a missing reviewer identity, and
an unknown schema version. All must return exit 1 with `invalid-metadata`;
the matching external digest ensures rejection is not merely a digest failure.
Existing actual head/base changes and report/diff mismatch checks remain.

Verification on macOS:

- `npm run pretest`: exit 0.
- `node --test dist-test/tests/adversarial-report-current.test.js`: 1 passed,
  0 failed, 0 skipped; this single test contains multiple assertions/cases.
- `npm test`: 263 passed, 0 failed, 0 skipped, duration 11512.397167 ms.
  Full local output: `/tmp/sdd-pr371-mcp-currentness-20260911.log`.
- `npm run typecheck`: exit 0.
- `git diff --check`: exit 0.

Scope review found no production changes, real credentials, removed checks,
or new agent launches. These fixtures validate the standalone CLI, not every
host review gate, a GitHub approval, or a fresh adversarial review of this
commit. Latest-head CI, required approval, merge, and post-merge verification
are still required. Issue #349 remains open.
